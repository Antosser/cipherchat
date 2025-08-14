mod auth_packet;

use std::{
    collections::HashMap,
    env,
    io::Error as IoError,
    net::SocketAddr,
    sync::{Arc, Mutex},
};

use anyhow::{bail, Context};
use futures_channel::mpsc::{unbounded, UnboundedSender};
use futures_util::{
    future, pin_mut,
    stream::{SplitSink, SplitStream, TryStreamExt},
    SinkExt, StreamExt,
};

use tokio::net::{TcpListener, TcpStream};
use tokio_tungstenite::{
    tungstenite::{self, protocol::Message, Utf8Bytes},
    WebSocketStream,
};

type Tx = UnboundedSender<Message>;
type PeerMap = Arc<Mutex<HashMap<ed25519_dalek::VerifyingKey, Tx>>>;

fn get_receiver_ver_key(
    msg: &protocol::E2EPacket,
    sender_ver_key: &ed25519_dalek::VerifyingKey,
) -> anyhow::Result<ed25519_dalek::VerifyingKey> {
    macro_rules! wrong_sig {
        () => {
            bail!("Failed to verify signature");
        };
    }

    macro_rules! wrong_ver_key {
        () => {
            bail!("Sender ver key does not match initial login ver key");
        };
    }

    match msg {
        protocol::E2EPacket::SYN(syn) => {
            if syn.verify_signature().is_err() {
                wrong_sig!();
            }

            if syn.client_ver_key != *sender_ver_key {
                wrong_ver_key!();
            }

            Ok(syn.server_ver_key)
        }
        protocol::E2EPacket::ACK(ack) => {
            if ack.verify_signature().is_err() {
                wrong_sig!();
            }

            if ack.server_ver_key != *sender_ver_key {
                wrong_ver_key!();
            }

            Ok(ack.client_ver_key)
        }
        protocol::E2EPacket::EncryptedMessage(em) => {
            if em.verify().is_err() {
                wrong_sig!();
            }

            if em.sender_ver_key != *sender_ver_key {
                wrong_ver_key!();
            }

            Ok(em.receiver_ver_key)
        }
    }
}

async fn authenticate(
    outgoing: &mut SplitSink<WebSocketStream<TcpStream>, tungstenite::Message>,
    incoming: &mut SplitStream<WebSocketStream<TcpStream>>,
) -> anyhow::Result<ed25519_dalek::VerifyingKey> {
    let proxy_random: [u8; 32] = rand::random();

    let msg = Message::Text(Utf8Bytes::from(
        serde_json::to_string(&proxy_random).context("Failed to serialize random")?,
    ));

    outgoing.send(msg).await.unwrap();

    let packet_raw = incoming
        .next()
        .await
        .context("Failed to receive packet")?
        .context("Failed to receive packet")?;

    let packet: auth_packet::AuthPacket =
        serde_json::from_str(if let tungstenite::Message::Text(ref msg) = packet_raw {
            msg.as_str()
        } else {
            bail!("Invalid message type, expected text");
        })
        .context("Failed to deserialize packet")?;

    packet
        .verify(&proxy_random)
        .context("Failed to verify packet")?;

    Ok(packet.ver_key)
}

async fn handle_connection(peer_map: PeerMap, raw_stream: TcpStream, addr: SocketAddr) {
    println!("Incoming TCP connection from: {addr}");

    let ws_stream = tokio_tungstenite::accept_async(raw_stream)
        .await
        .expect("Error during the websocket handshake occurred");
    println!("WebSocket connection established: {addr}");

    // Insert the write part of this peer to the peer map.
    let (tx, rx) = unbounded();

    let (mut outgoing, mut incoming) = ws_stream.split();

    let ver_key = match authenticate(&mut outgoing, &mut incoming).await {
        Ok(ver_key) => ver_key,
        Err(e) => {
            println!("Failed to authenticate: {e:#}",);
            outgoing
                .send(Message::Text(Utf8Bytes::from(e.to_string())))
                .await
                .unwrap();
            outgoing.send(Message::Close(None)).await.unwrap();
            return;
        }
    };

    println!("{} authenticated successfully", &addr);

    if peer_map.lock().unwrap().contains_key(&ver_key) {
        println!("{} is already connected", &addr);
        return;
    }

    peer_map.lock().unwrap().insert(ver_key, tx);

    let broadcast_incoming = incoming.try_for_each(|msg| {
        let peers = peer_map.lock().unwrap();

        let msg_string = match msg {
            tungstenite::Message::Text(ref msg) => msg,
            tungstenite::Message::Close(_) => {
                return future::ok(());
            }
            _ => {
                println!("Invalid message type, expected text");
                return future::ok(());
            }
        };

        let msg_deserialized = match serde_json::from_str::<protocol::E2EPacket>(msg_string)
            .context("Failed to parse message as JSON")
        {
            Ok(msg) => msg,
            Err(e) => {
                println!("Failed to handle message: {e:#}",);
                return future::ok(());
            }
        };

        let receiver_ver_key = match get_receiver_ver_key(&msg_deserialized, &ver_key) {
            Ok(receiver_ver_key) => receiver_ver_key,
            Err(e) => {
                println!("Failed to handle message: {e:#}",);
                return future::ok(());
            }
        };

        // We want to broadcast the message to everyone except ourselves.
        // let broadcast_recipients = peers
        //     .iter()
        //     .filter(|(peer_addr, _)| peer_addr != &&addr)
        //     .map(|(_, ws_sink)| ws_sink);

        // for recp in broadcast_recipients {
        //     recp.unbounded_send(msg.clone()).unwrap();
        // }
        let kv = match peers
            .iter()
            .find(|(other_ver_key, _)| *other_ver_key == &receiver_ver_key)
        {
            Some(kv) => kv,
            None => {
                println!("{:?} is not connected", &receiver_ver_key);
                return future::ok(());
            }
        };
        if let Err(e) = kv.1.unbounded_send(msg.clone()) {
            println!("Failed to broadcast message to {receiver_ver_key:?}: {e:#}",);
        }

        future::ok(())
    });

    let receive_from_others = rx.map(Ok).forward(outgoing);

    pin_mut!(broadcast_incoming, receive_from_others);
    future::select(broadcast_incoming, receive_from_others).await;

    println!("{} disconnected", &addr);
    peer_map.lock().unwrap().remove(&ver_key);
}

#[tokio::main]
async fn main() -> Result<(), IoError> {
    let addr = env::args()
        .nth(1)
        .unwrap_or_else(|| "127.0.0.1:8080".to_string());

    let state = PeerMap::new(Mutex::new(HashMap::new()));

    // Create the event loop and TCP listener we'll accept connections on.
    let try_socket = TcpListener::bind(&addr).await;
    let listener = try_socket.expect("Failed to bind");
    println!("Listening on: ws://{addr}");

    // Let's spawn the handling of each connection in a separate task.
    while let Ok((stream, addr)) = listener.accept().await {
        tokio::spawn(handle_connection(state.clone(), stream, addr));
    }

    Ok(())
}

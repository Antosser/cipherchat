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

pub async fn authenticate(
    outgoing: &mut SplitSink<WebSocketStream<TcpStream>, Message>,
    incoming: &mut SplitStream<WebSocketStream<TcpStream>>,
) -> anyhow::Result<ed25519_dalek::VerifyingKey> {
    // Generate a 32-byte random challenge
    let proxy_random: [u8; 32] = rand::random();

    // Serialize and send it
    let msg_text = serde_json::to_string(&proxy_random).context("Failed to serialize random")?;
    outgoing
        .send(Message::Text(Utf8Bytes::from(msg_text)))
        .await
        .context("Failed to send authentication challenge")?;

    // Wait for response
    let packet_msg = incoming
        .next()
        .await
        .context("Failed to receive packet")?
        .context("Failed to receive packet")?;

    // Expect a text message
    let packet_str = if let Message::Text(s) = packet_msg {
        s
    } else {
        bail!("Invalid message type, expected text");
    };

    // Deserialize
    let packet: auth_packet::AuthPacket =
        serde_json::from_str(&packet_str).context("Failed to deserialize AuthPacket")?;

    // Verify packet
    packet
        .verify(&proxy_random)
        .context("Failed to verify AuthPacket")?;

    Ok(packet.ver_key)
}

pub async fn handle_connection(peer_map: PeerMap, raw_stream: TcpStream, addr: SocketAddr) {
    println!("Incoming TCP connection from: {addr}");

    let ws_stream = match tokio_tungstenite::accept_async(raw_stream).await {
        Ok(ws) => ws,
        Err(e) => {
            println!("Error during WebSocket handshake: {e:#}");
            return;
        }
    };
    println!("WebSocket connection established: {addr}");

    let (tx, rx) = unbounded();
    let (mut outgoing, mut incoming) = ws_stream.split();

    let ver_key = match authenticate(&mut outgoing, &mut incoming).await {
        Ok(vk) => vk,
        Err(e) => {
            println!("Failed to authenticate: {e:#}");
            let _ = outgoing
                .send(Message::Text(Utf8Bytes::from(e.to_string())))
                .await;
            let _ = outgoing.send(Message::Close(None)).await;
            return;
        }
    };

    println!("{addr} authenticated successfully");

    {
        let mut peers = peer_map.lock().expect("peer_map poisoned");
        if peers.contains_key(&ver_key) {
            println!("{addr} is already connected");
            return;
        }
        peers.insert(ver_key, tx);
    }

    let broadcast_incoming = incoming.try_for_each(|msg| {
        let peers = peer_map.lock().expect("peer_map poisoned");

        let msg_string = match msg {
            tungstenite::Message::Text(ref s) => s,
            tungstenite::Message::Close(_) => return future::ok(()),
            _ => {
                println!("Invalid message type, expected text");
                return future::ok(());
            }
        };

        let msg_deserialized = match serde_json::from_str::<protocol::E2EPacket>(msg_string) {
            Ok(m) => m,
            Err(e) => {
                println!("Failed to parse message as JSON: {e:#}");
                return future::ok(());
            }
        };

        let receiver_ver_key = match get_receiver_ver_key(&msg_deserialized, &ver_key) {
            Ok(k) => k,
            Err(e) => {
                println!("Failed to extract receiver key: {e:#}");
                return future::ok(());
            }
        };

        let recipient = match peers.iter().find(|(k, _)| *k == &receiver_ver_key) {
            Some(kv) => kv,
            None => {
                println!("{receiver_ver_key:?} is not connected");
                return future::ok(());
            }
        };

        if let Err(e) = recipient.1.unbounded_send(msg.clone()) {
            println!("Failed to send to {receiver_ver_key:?}: {e:#}");
        }

        future::ok(())
    });

    let receive_from_others = rx.map(Ok).forward(outgoing);

    pin_mut!(broadcast_incoming, receive_from_others);
    future::select(broadcast_incoming, receive_from_others).await;

    println!("{addr} disconnected");
    peer_map.lock().expect("peer_map poisoned").remove(&ver_key);
}

#[tokio::main]
async fn main() -> Result<(), IoError> {
    let bind_addr = env::args()
        .nth(1)
        .unwrap_or_else(|| "127.0.0.1:8080".to_string());

    let state = Arc::new(Mutex::new(HashMap::new())); // Replace with PeerMap if needed

    let listener = TcpListener::bind(&bind_addr).await?;
    println!("Listening on: ws://{bind_addr}");

    while let Ok((stream, peer_addr)) = listener.accept().await {
        let state = Arc::clone(&state);
        tokio::spawn(handle_connection(state, stream, peer_addr));
    }

    Ok(())
}

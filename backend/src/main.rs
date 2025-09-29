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
use tracing::{debug, error, info, warn};

type Tx = UnboundedSender<Message>;
type PeerMap = Arc<Mutex<HashMap<ed25519_dalek::VerifyingKey, Tx>>>;

fn get_receiver_ver_key(
    msg: &protocol::E2EPacket,
    sender_ver_key: &ed25519_dalek::VerifyingKey,
) -> anyhow::Result<ed25519_dalek::VerifyingKey> {
    macro_rules! wrong_sig {
        () => {{
            error!("Signature verification failed for message");
            bail!("Failed to verify signature");
        }};
    }

    macro_rules! wrong_ver_key {
        () => {{
            error!("Sender verifying key does not match expected key.",);
            bail!("Sender ver key does not match initial login ver key");
        }};
    }

    match msg {
        protocol::E2EPacket::SYN(syn) => {
            debug!("Processing SYN packet");
            if syn.verify_signature().is_err() {
                wrong_sig!();
            }

            if syn.client_ver_key != *sender_ver_key {
                wrong_ver_key!();
            }

            info!("SYN packet verified successfully, returning server_ver_key");
            Ok(syn.server_ver_key)
        }
        protocol::E2EPacket::ACK(ack) => {
            debug!("Processing ACK packet");
            if ack.verify_signature().is_err() {
                wrong_sig!();
            }

            if ack.server_ver_key != *sender_ver_key {
                wrong_ver_key!();
            }

            info!("ACK packet verified successfully, returning client_ver_key");
            Ok(ack.client_ver_key)
        }
        protocol::E2EPacket::EncryptedMessage(em) => {
            debug!("Processing EncryptedMessage packet");
            if em.verify().is_err() {
                wrong_sig!();
            }

            if em.sender_ver_key != *sender_ver_key {
                wrong_ver_key!();
            }

            info!("EncryptedMessage verified successfully, returning receiver_ver_key");
            Ok(em.receiver_ver_key)
        }
    }
}

pub async fn authenticate(
    outgoing: &mut SplitSink<WebSocketStream<TcpStream>, Message>,
    incoming: &mut SplitStream<WebSocketStream<TcpStream>>,
) -> anyhow::Result<ed25519_dalek::VerifyingKey> {
    debug!("Generating random challenge for authentication");

    // Generate a 32-byte random challenge
    let proxy_random: [u8; 32] = rand::random();

    // Serialize and send it
    let msg_text = serde_json::to_string(&proxy_random).context("Failed to serialize random")?;
    debug!("Sending authentication challenge");
    outgoing
        .send(Message::Text(Utf8Bytes::from(msg_text)))
        .await
        .context("Failed to send authentication challenge")?;

    debug!("Waiting for authentication response");
    // Wait for response
    let packet_msg = incoming
        .next()
        .await
        .context("Failed to receive packet")?
        .context("Failed to receive packet")?;

    // Expect a text message
    let packet_str = if let Message::Text(s) = packet_msg {
        debug!("Received authentication response");
        s
    } else {
        error!("Invalid message type received during authentication");
        bail!("Invalid message type, expected text");
    };

    // Deserialize
    let packet: auth_packet::AuthPacket =
        serde_json::from_str(&packet_str).context("Failed to deserialize AuthPacket")?;
    debug!("Deserialized AuthPacket successfully");

    // Verify packet
    packet
        .verify(&proxy_random)
        .context("Failed to verify AuthPacket")?;
    info!("Authentication succeeded for peer {:?}", packet.ver_key);

    Ok(packet.ver_key)
}

pub async fn handle_connection(peer_map: PeerMap, raw_stream: TcpStream, addr: SocketAddr) {
    info!("Incoming TCP connection from {}", addr);

    let ws_stream = match tokio_tungstenite::accept_async(raw_stream).await {
        Ok(ws) => ws,
        Err(e) => {
            error!("WebSocket handshake failed for {}: {:#}", addr, e);
            return;
        }
    };
    info!("WebSocket connection established with {}", addr);

    let (tx, rx) = unbounded();
    let (mut outgoing, mut incoming) = ws_stream.split();

    let ver_key = match authenticate(&mut outgoing, &mut incoming).await {
        Ok(vk) => vk,
        Err(e) => {
            warn!("Authentication failed for {}: {:#}", addr, e);
            let _ = outgoing
                .send(Message::Text(Utf8Bytes::from(e.to_string())))
                .await;
            let _ = outgoing.send(Message::Close(None)).await;
            return;
        }
    };

    info!("{} authenticated successfully", addr);

    {
        let mut peers = peer_map.lock().expect("peer_map poisoned");
        if peers.contains_key(&ver_key) {
            warn!("{} is already connected", addr);
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
                warn!("Invalid message type from {}: expected text", addr);
                return future::ok(());
            }
        };

        let msg_deserialized = match serde_json::from_str::<protocol::E2EPacket>(msg_string) {
            Ok(m) => m,
            Err(e) => {
                warn!("Failed to parse JSON from {}: {:#}", addr, e);
                return future::ok(());
            }
        };

        let receiver_ver_key = match get_receiver_ver_key(&msg_deserialized, &ver_key) {
            Ok(k) => k,
            Err(e) => {
                warn!("Failed to extract receiver key from {}: {:#}", addr, e);
                return future::ok(());
            }
        };

        let recipient = match peers.iter().find(|(k, _)| *k == &receiver_ver_key) {
            Some(kv) => kv,
            None => {
                warn!(
                    "Recipient {:?} not connected, message from {}",
                    receiver_ver_key, addr
                );
                return future::ok(());
            }
        };

        if let Err(e) = recipient.1.unbounded_send(msg.clone()) {
            error!("Failed to send message to {:?}: {:#}", receiver_ver_key, e);
        }

        future::ok(())
    });

    let receive_from_others = rx.map(Ok).forward(outgoing);

    pin_mut!(broadcast_incoming, receive_from_others);
    future::select(broadcast_incoming, receive_from_others).await;

    info!("{} disconnected", addr);
    peer_map.lock().expect("peer_map poisoned").remove(&ver_key);
}

#[tokio::main]
async fn main() -> Result<(), IoError> {
    // Initialize tracing subscriber with default settings
    tracing_subscriber::fmt::init();

    let bind_addr = env::args()
        .nth(1)
        .unwrap_or_else(|| "127.0.0.1:8080".to_string());

    let state = Arc::new(Mutex::new(HashMap::new())); // Replace with PeerMap if needed

    let listener = TcpListener::bind(&bind_addr).await?;
    info!("Server listening on ws://{}", bind_addr);

    while let Ok((stream, peer_addr)) = listener.accept().await {
        debug!("Accepted connection from {}", peer_addr);
        let state = Arc::clone(&state);
        tokio::spawn(handle_connection(state, stream, peer_addr));
    }

    Ok(())
}

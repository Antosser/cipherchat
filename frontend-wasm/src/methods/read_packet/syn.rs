use crate::hex::to_hex;
use crate::{timestamp, Chat, Message, MessageUpdateToFrontend, MyState};
use aes_gcm::KeyInit;
use protocol::e2e_packet;
use rand::Rng;
use wasm_bindgen::prelude::*;

pub fn handle_syn(
    packet: Box<protocol::SYN>,
    state: &mut MyState,
    sign_key: &mut ed25519_dalek::SigningKey,
    ver_key: ed25519_dalek::VerifyingKey,
) -> Result<(Vec<MessageUpdateToFrontend>, Option<String>), JsValue> {
    let mut message_updates = Vec::new();

    if state.chats.contains_key(&packet.id) {
        message_updates.push(MessageUpdateToFrontend {
            chat_id: packet.id.to_string(),
            message: Message::System(format!(
                "New SYN packet for chat {} allegedly from {}",
                packet.id,
                to_hex(&packet.client_ver_key.to_bytes())
            )),
        });
        return Ok((message_updates, None));
    }

    if let Err(e) = packet.verify_signature() {
        message_updates.push(MessageUpdateToFrontend {
            chat_id: packet.id.to_string(),
            message: Message::System(format!(
                "{} tried to start chat {} but signature invalid: {}",
                to_hex(&packet.client_ver_key.to_bytes()),
                packet.id,
                e
            )),
        });
        return Ok((message_updates, None));
    }

    if packet.server_ver_key != ver_key {
        message_updates.push(MessageUpdateToFrontend {
            chat_id: packet.id.to_string(),
            message: Message::System(format!(
                "{} attempted to start chat but recipient does not match",
                to_hex(&packet.client_ver_key.to_bytes())
            )),
        });
        return Ok((message_updates, None));
    }

    if packet.timestamp + 5000 < timestamp()? {
        message_updates.push(MessageUpdateToFrontend {
            chat_id: packet.id.to_string(),
            message: Message::System(format!(
                "{} tried to start chat {} but timestamp too old",
                to_hex(&packet.client_ver_key.to_bytes()),
                packet.id
            )),
        });
        return Ok((message_updates, None));
    }

    let mut rng = rand::thread_rng();
    let server_random = rng.gen::<[u8; 32]>();
    let eph_priv_key = x25519_dalek::EphemeralSecret::random_from_rng(rng);
    let eph_pub_key = x25519_dalek::PublicKey::from(&eph_priv_key);

    let ack = protocol::ACK::new(
        packet.id,
        packet.digest(),
        sign_key,
        ver_key,
        packet.client_ver_key,
        eph_pub_key,
        server_random,
    );

    let shared_secret = eph_priv_key.diffie_hellman(&packet.client_eph_pub_key);
    let cipher = aes_gcm::Aes256Gcm::new(aes_gcm::Key::<aes_gcm::Aes256Gcm>::from_slice(
        &shared_secret.as_bytes()[..32],
    ));

    state.chats.insert(
        packet.id,
        Chat::Encrypted {
            cipher,
            other_ver_key: packet.client_ver_key,
            messages: Vec::new(),
            prev_id_other: 0,
            prev_id_self: 0,
        },
    );

    let response_packet = e2e_packet::E2EPacket::ACK(ack);
    let response_packet_json = serde_json::to_string(&response_packet)
        .map_err(|e| JsValue::from_str(&format!("Failed to serialize ACK packet: {e}")))?;

    message_updates.push(MessageUpdateToFrontend {
        chat_id: packet.id.to_string(),
        message: Message::System(format!(
            "{} initiated chat {}",
            to_hex(&packet.client_ver_key.to_bytes()),
            packet.id
        )),
    });

    Ok((message_updates, Some(response_packet_json)))
}

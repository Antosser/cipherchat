use crate::hex::to_hex;
use crate::{Chat, Message, MessageUpdateToFrontend, MyState};
use aes_gcm::KeyInit;
use wasm_bindgen::prelude::*;

pub fn handle_ack(
    packet: protocol::ACK,
    state: &mut MyState,
    ver_key: ed25519_dalek::VerifyingKey,
) -> Result<(Vec<MessageUpdateToFrontend>, Option<String>), JsValue> {
    tracing::debug!("handle_ack: chat_id={}", packet.id);
    let mut message_updates = Vec::new();

    // Retrieve SYN data
    let (server_ver_key, client_eph_priv_key, syn_digest) =
        if let Some(chat) = state.chats.get_mut(&packet.id) {
            if let Chat::Syn {
                server_ver_key,
                client_eph_priv_key,
                syn_digest,
            } = chat
            {
                (
                    *server_ver_key,
                    // take ownership of eph secret to perform DH
                    std::mem::replace(
                        client_eph_priv_key,
                        x25519_dalek::EphemeralSecret::random_from_rng(rand::thread_rng()),
                    ),
                    *syn_digest,
                )
            } else {
                message_updates.push(MessageUpdateToFrontend {
                    chat_id: packet.id.to_string(),
                    message: Message::System(format!(
                        "{} attempted to ACK but connection already established",
                        to_hex(&packet.client_ver_key.to_bytes())
                    )),
                });
                return Ok((message_updates, None));
            }
        } else {
            message_updates.push(MessageUpdateToFrontend {
                chat_id: packet.id.to_string(),
                message: Message::System(format!(
                    "{} attempted to ACK but chat does not exist",
                    to_hex(&packet.client_ver_key.to_bytes())
                )),
            });
            return Ok((message_updates, None));
        };

    // Validate packet
    if let Err(e) = packet.verify_signature() {
        message_updates.push(MessageUpdateToFrontend {
            chat_id: packet.id.to_string(),
            message: Message::System(format!(
                "{} attempted to ACK but signature invalid: {}",
                to_hex(&packet.client_ver_key.to_bytes()),
                e
            )),
        });
        return Ok((message_updates, None));
    }
    if packet.client_ver_key != ver_key {
        message_updates.push(MessageUpdateToFrontend {
            chat_id: packet.id.to_string(),
            message: Message::System(format!(
                "{} attempted to ACK but recipient does not match",
                to_hex(&packet.client_ver_key.to_bytes())
            )),
        });
        return Ok((message_updates, None));
    }
    if syn_digest != packet.syn_digest {
        message_updates.push(MessageUpdateToFrontend {
            chat_id: packet.id.to_string(),
            message: Message::System(format!(
                "{} attempted to ACK but syn_digest mismatch",
                to_hex(&packet.client_ver_key.to_bytes())
            )),
        });
        return Ok((message_updates, None));
    }
    if server_ver_key != packet.server_ver_key {
        message_updates.push(MessageUpdateToFrontend {
            chat_id: packet.id.to_string(),
            message: Message::System(format!(
                "{} attempted to ACK but server_ver_key mismatch",
                to_hex(&packet.client_ver_key.to_bytes())
            )),
        });
        return Ok((message_updates, None));
    }

    // Establish cipher
    let shared_secret = client_eph_priv_key.diffie_hellman(&packet.server_eph_pub_key);
    let cipher = aes_gcm::Aes256Gcm::new(aes_gcm::Key::<aes_gcm::Aes256Gcm>::from_slice(
        &shared_secret.as_bytes()[..32],
    ));

    state.chats.insert(
        packet.id,
        Chat::Encrypted {
            cipher,
            other_ver_key: packet.server_ver_key,
            messages: Vec::new(),
        },
    );

    message_updates.push(MessageUpdateToFrontend {
        chat_id: packet.id.to_string(),
        message: Message::System(format!(
            "{} acknowledged chat {}",
            to_hex(&packet.server_ver_key.to_bytes()),
            packet.id
        )),
    });

    Ok((message_updates, None))
}

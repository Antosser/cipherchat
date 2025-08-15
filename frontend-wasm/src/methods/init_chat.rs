use crate::{hex::to_hex, timestamp, Chat, Message, MessageUpdateToFrontend, STATE};
use protocol::e2e_packet;
use rand::Rng;
use std::convert::TryInto;
use wasm_bindgen::prelude::*;

#[derive(serde::Serialize)]
struct InitChatReturnValue {
    message_updates: Vec<MessageUpdateToFrontend>,
    packet: String, // serialized to json
}

#[wasm_bindgen]
pub fn init_chat(server_ver_key: Vec<u8>) -> Result<String, JsValue> {
    tracing::debug!("Initializing new chat");

    STATE.with(|state| -> Result<String, JsValue> {
        let mut state = state.borrow_mut();

        // Retrieve signing key
        let mut sign_key = state
            .sign_key
            .as_ref()
            .ok_or_else(|| JsValue::from_str("No signing key available"))?
            .clone();

        // Generate ephemeral X25519 key and random identifiers
        let mut rng = rand::thread_rng();
        let client_random = rng.gen::<[u8; 32]>();
        let chat_id = rng.gen::<u64>();

        // Convert server verifying key from bytes
        let server_ver_key_arr: [u8; 32] = server_ver_key
            .as_slice()
            .try_into()
            .map_err(|_| JsValue::from_str("Invalid server verifying key length"))?;
        let server_ver_key = ed25519_dalek::VerifyingKey::from_bytes(&server_ver_key_arr)
            .map_err(|_| JsValue::from_str("Invalid server verifying key bytes"))?;

        // Generate ephemeral X25519 keypair
        let eph_priv_key = x25519_dalek::EphemeralSecret::random_from_rng(rng);
        let eph_pub_key = x25519_dalek::PublicKey::from(&eph_priv_key);

        // Construct SYN packet
        let syn = protocol::SYN::new(
            &mut sign_key,
            eph_pub_key,
            server_ver_key,
            client_random,
            timestamp()?,
            chat_id,
        );

        // Store chat in state
        state.chats.insert(
            chat_id,
            Chat::Syn {
                server_ver_key,
                client_eph_priv_key: eph_priv_key,
                syn_digest: syn.digest(),
            },
        );

        // Wrap packet
        let packet = e2e_packet::E2EPacket::SYN(Box::new(syn));
        let packet_json = serde_json::to_string(&packet)
            .map_err(|e| JsValue::from_str(&format!("Failed to serialize packet: {e}")))?;

        // Prepare frontend return value
        let return_value = InitChatReturnValue {
            message_updates: vec![MessageUpdateToFrontend {
                chat_id: chat_id.to_string(),
                message: Message::System(format!(
                    "Initializing chat {} with {}",
                    chat_id,
                    to_hex(&server_ver_key.to_bytes())
                )),
            }],
            packet: packet_json,
        };

        let json = serde_json::to_string(&return_value)
            .map_err(|e| JsValue::from_str(&format!("Failed to serialize return value: {e}")))?;

        tracing::debug!("Chat {} initialized successfully", chat_id);

        Ok(json)
    })
}

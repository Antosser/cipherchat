use protocol::e2e_packet;
use wasm_bindgen::prelude::*;

use crate::{Chat, Message, STATE};

#[wasm_bindgen]
pub fn send_message(message: String, chat_id: u64) -> Result<String, JsValue> {
    STATE.with(|state| {
        let mut state = state.borrow_mut();

        #[allow(clippy::clone_on_copy)]
        let ver_key = state
            .ver_key
            .as_ref()
            .ok_or(JsValue::from_str("no ver key"))?
            .clone();
        let sign_key = state
            .sign_key
            .as_ref()
            .ok_or(JsValue::from_str("no sign key"))?
            .clone();

        let chat = state
            .chats
            .get_mut(&chat_id)
            .ok_or(JsValue::from_str("chat does not exist"))?;

        let (cipher, other_ver_key, messages) = if let Chat::Encrypted {
            cipher,
            other_ver_key,
            messages,
        } = chat
        {
            (cipher, other_ver_key, messages)
        } else {
            return Err(JsValue::from_str("chat is not encrypted"));
        };

        let index = messages
            .iter()
            .rev()
            .find_map(|msg| match msg {
                Message::ToOther(msg) => Some(msg.id),
                _ => None,
            })
            .unwrap_or(0);

        let decrypted_payload = protocol::DecryptedMessagePayload {
            id: index + 1,
            content: message,
        };

        let encrypted_packet = protocol::EncryptedMessage::new(
            chat_id,
            ver_key,
            *other_ver_key,
            &decrypted_payload,
            cipher,
            &mut sign_key.clone(),
        )
        .map_err(|e| JsValue::from_str(&format!("Encryption failed: {e:?}")))?;

        messages.push(Message::ToOther(decrypted_payload));

        let packet = e2e_packet::E2EPacket::EncryptedMessage(encrypted_packet);

        let packet_json = serde_json::to_string(&packet)
            .map_err(|_| JsValue::from_str("failed to serialize packet"))?;
        Ok(packet_json)
    })
}

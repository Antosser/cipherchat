use crate::hex::to_hex;
use crate::{Chat, Message, MessageUpdateToFrontend, MyState};
use wasm_bindgen::prelude::*;

pub fn handle_encrypted_message(
    packet: protocol::EncryptedMessage,
    state: &mut MyState,
) -> Result<(Vec<MessageUpdateToFrontend>, Option<String>), JsValue> {
    tracing::debug!("handle_encrypted_message: chat_id={}", packet.id);
    let mut message_updates = Vec::new();

    // Borrow chat minimally
    let (cipher, other_ver_key, messages) = if let Some(chat) = state.chats.get_mut(&packet.id) {
        if let Chat::Encrypted {
            cipher,
            other_ver_key,
            messages,
        } = chat
        {
            (cipher, other_ver_key, messages)
        } else {
            message_updates.push(MessageUpdateToFrontend {
                chat_id: packet.id.to_string(),
                message: Message::System(format!(
                    "{} attempted to send message but chat not established",
                    to_hex(&packet.sender_ver_key.to_bytes())
                )),
            });
            return Ok((message_updates, None));
        }
    } else {
        message_updates.push(MessageUpdateToFrontend {
            chat_id: packet.id.to_string(),
            message: Message::System(format!(
                "{} attempted to send message but chat does not exist",
                to_hex(&packet.sender_ver_key.to_bytes())
            )),
        });
        return Ok((message_updates, None));
    };

    // Verify sender key matches the chat peer
    if *other_ver_key != packet.sender_ver_key {
        message_updates.push(MessageUpdateToFrontend {
            chat_id: packet.id.to_string(),
            message: Message::System(format!(
                "{} attempted to send message but sender_ver_key mismatch",
                to_hex(&packet.sender_ver_key.to_bytes())
            )),
        });
        return Ok((message_updates, None));
    }

    // Decrypt and emit
    let message = match packet.message.decrypt(cipher, packet.nonce) {
        Ok(m) => m,
        Err(e) => {
            message_updates.push(MessageUpdateToFrontend {
                chat_id: packet.id.to_string(),
                message: Message::System(format!(
                    "{} attempted to send message but decryption failed: {}",
                    to_hex(&packet.sender_ver_key.to_bytes()),
                    e
                )),
            });
            return Ok((message_updates, None));
        }
    };

    messages.push(Message::ToSelf(message.clone()));
    message_updates.push(MessageUpdateToFrontend {
        chat_id: packet.id.to_string(),
        message: Message::ToSelf(message),
    });

    Ok((message_updates, None))
}

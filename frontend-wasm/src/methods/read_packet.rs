mod ack;
mod msg;
mod syn;

use ack::handle_ack;
use msg::handle_encrypted_message;
use protocol::e2e_packet;
use syn::handle_syn;
use wasm_bindgen::prelude::*;

use crate::{MessageUpdateToFrontend, STATE};

#[derive(serde::Serialize)]
struct ReadPacketReturnValue {
    message_updates: Vec<MessageUpdateToFrontend>,
    packet: Option<String>,
}

fn serialize_return_value(rv: &ReadPacketReturnValue) -> Result<String, JsValue> {
    serde_json::to_string(rv)
        .map_err(|e| JsValue::from_str(&format!("Failed to serialize return value: {e}")))
}

#[wasm_bindgen]
pub fn read_packet(packet: String) -> Result<String, JsValue> {
    tracing::debug!("Reading incoming packet");

    STATE.with(|state| -> Result<String, JsValue> {
        let packet: e2e_packet::E2EPacket = serde_json::from_str(&packet)
            .map_err(|e| JsValue::from_str(&format!("Failed to deserialize packet: {e}")))?;

        let mut state = state.borrow_mut();
        let mut sign_key = state
            .sign_key
            .as_ref()
            .ok_or_else(|| JsValue::from_str("No signing key"))?
            .clone();
        let ver_key = *state
            .ver_key
            .as_ref()
            .ok_or_else(|| JsValue::from_str("No verifying key"))?;

        let (message_updates, response_packet) = match packet {
            e2e_packet::E2EPacket::SYN(p) => handle_syn(p, &mut state, &mut sign_key, ver_key)?,
            e2e_packet::E2EPacket::ACK(p) => handle_ack(p, &mut state, ver_key)?,
            e2e_packet::E2EPacket::EncryptedMessage(p) => handle_encrypted_message(p, &mut state)?,
        };

        serialize_return_value(&ReadPacketReturnValue {
            message_updates,
            packet: response_packet,
        })
    })
}

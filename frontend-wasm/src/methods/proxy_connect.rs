use ed25519_dalek::ed25519::signature::SignerMut;
use wasm_bindgen::prelude::*;

use crate::{auth_packet, STATE};

#[wasm_bindgen]
pub fn proxy_connect(proxy_random: Vec<u8>) -> Result<String, JsValue> {
    STATE.with(|state| {
        let state = state.borrow();
        let sign_key = state
            .sign_key
            .as_ref()
            .ok_or_else(|| JsValue::from_str("No signing key available"))?;
        let ver_key = state
            .ver_key
            .as_ref()
            .ok_or_else(|| JsValue::from_str("No verifying key available"))?;

        tracing::debug!("Signing proxy random for auth packet");

        // Clone the signing key once to get an owned value that can be mutably borrowed
        let mut sign_key = sign_key.clone();
        let signature = sign_key.sign(&proxy_random);

        let auth_packet = auth_packet::AuthPacket {
            ver_key: *ver_key,
            signature,
        };

        serde_json::to_string(&auth_packet)
            .map_err(|e| JsValue::from_str(&format!("Failed to serialize auth packet: {e}")))
    })
}

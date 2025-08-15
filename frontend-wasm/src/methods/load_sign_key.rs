use std::convert::TryInto;
use wasm_bindgen::prelude::*;

use crate::STATE;

#[wasm_bindgen]
pub fn load_sign_key(sign_key: Vec<u8>) -> Result<js_sys::Array, JsValue> {
    tracing::debug!("Loading Ed25519 signing key from JS input");

    // Ensure key length is correct
    let sign_key_bytes: [u8; 32] = sign_key
        .as_slice()
        .try_into()
        .map_err(|_| JsValue::from_str("Invalid signing key length, expected 32 bytes"))?;

    // Reconstruct SigningKey
    let sign_key = ed25519_dalek::SigningKey::from_bytes(&sign_key_bytes);
    let ver_key = sign_key.verifying_key();

    // Store keys in state
    STATE.with(|state| {
        let mut state = state.borrow_mut();
        state.sign_key = Some(sign_key.clone()); // clone required to store
        state.ver_key = Some(ver_key);
    });

    // Prepare return array for JS
    let arr = js_sys::Array::new();
    arr.push(&serde_wasm_bindgen::to_value(
        &sign_key.to_bytes().to_vec(),
    )?);
    arr.push(&serde_wasm_bindgen::to_value(&ver_key.to_bytes().to_vec())?);

    tracing::debug!("Signing key loaded and stored successfully");
    Ok(arr)
}

use crate::STATE;
use wasm_bindgen::prelude::*;

#[wasm_bindgen]
pub fn make_keypair() -> Result<js_sys::Array, JsValue> {
    tracing::debug!("Generating new Ed25519 keypair");

    let mut rng = rand::thread_rng();
    let sign_key = ed25519_dalek::SigningKey::generate(&mut rng);
    let ver_key = sign_key.verifying_key();

    // Store keys in state
    STATE.with(|state| {
        let mut state = state.borrow_mut();
        state.sign_key = Some(sign_key.clone()); // clone is needed to store
        state.ver_key = Some(ver_key);
    });

    // Convert keys to Vec<u8> for JS
    let sign_bytes = sign_key.to_bytes().to_vec();
    let ver_bytes = ver_key.to_bytes().to_vec();

    let arr = js_sys::Array::new();
    arr.push(&serde_wasm_bindgen::to_value(&sign_bytes)?);
    arr.push(&serde_wasm_bindgen::to_value(&ver_bytes)?);

    tracing::debug!("Keypair generated and stored successfully");
    Ok(arr)
}

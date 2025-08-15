mod auth_packet;
mod hex;
mod methods;

pub use methods::*;
use std::{cell::RefCell, collections::HashMap};
use wasm_bindgen::prelude::*;

#[wasm_bindgen(start)]
pub fn main() {
    #[cfg(feature = "console_error_panic_hook")]
    console_error_panic_hook::set_once();

    tracing_wasm::set_as_global_default();
}

thread_local! {
    static STATE: RefCell<MyState> = RefCell::new(MyState::default());
}

fn timestamp() -> Result<u64, String> {
    Ok(web_time::SystemTime::now()
        .duration_since(web_time::SystemTime::UNIX_EPOCH)
        .map_err(|_| "failed to get unix time")?
        .as_millis() as u64)
}

#[derive(Default)]
struct MyState {
    pub sign_key: Option<ed25519_dalek::SigningKey>,
    pub ver_key: Option<ed25519_dalek::VerifyingKey>,
    pub chats: HashMap<u64, Chat>,
}

#[allow(clippy::large_enum_variant)]
enum Chat {
    /// Only used from the client's perspective.
    Syn {
        server_ver_key: ed25519_dalek::VerifyingKey,
        client_eph_priv_key: x25519_dalek::EphemeralSecret,
        syn_digest: [u8; 32],
    },

    /// Used after encrypted connection has been established.
    Encrypted {
        cipher: aes_gcm::Aes256Gcm,
        other_ver_key: ed25519_dalek::VerifyingKey,
        messages: Vec<Message>,
    },
}

#[derive(serde::Serialize)]
enum Message {
    ToOther(protocol::DecryptedMessagePayload),
    ToSelf(protocol::DecryptedMessagePayload),
    System(String),
}

#[derive(serde::Serialize)]
struct MessageUpdateToFrontend {
    chat_id: String,
    message: Message,
}

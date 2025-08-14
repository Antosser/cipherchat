use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct AuthPacket {
    pub ver_key: ed25519_dalek::VerifyingKey,
    pub signature: ed25519_dalek::Signature,
}

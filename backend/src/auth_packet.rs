use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct AuthPacket {
    pub ver_key: ed25519_dalek::VerifyingKey,
    pub signature: ed25519_dalek::Signature,
}

impl AuthPacket {
    pub fn verify(&self, random: &[u8; 32]) -> Result<(), ed25519_dalek::SignatureError> {
        self.ver_key.verify_strict(random, &self.signature)
    }
}

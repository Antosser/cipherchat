use serde::{Deserialize, Serialize};

use ed25519_dalek::ed25519::signature::SignerMut;
use ed25519_dalek::Verifier;
use sha2::Digest;

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct SYN {
    pub id: u64,
    pub client_ver_key: ed25519_dalek::VerifyingKey,
    pub server_ver_key: ed25519_dalek::VerifyingKey,
    pub client_eph_pub_key: x25519_dalek::PublicKey,
    pub client_random: [u8; 32],
    pub timestamp: u64,
    pub signature: ed25519_dalek::Signature,
}

impl SYN {
    pub fn new(
        client_sign_key: &mut ed25519_dalek::SigningKey,
        client_eph_pub_key: x25519_dalek::PublicKey,
        server_ver_key: ed25519_dalek::VerifyingKey,
        client_random: [u8; 32],
        timestamp: u64,
        id: u64,
    ) -> Self {
        let client_ver_key = client_sign_key.verifying_key();

        let digest: [u8; 32] = {
            let mut hasher = sha2::Sha256::new();
            hasher.update(id.to_le_bytes());
            hasher.update(client_ver_key.to_bytes());
            hasher.update(client_eph_pub_key.to_bytes());
            hasher.update(client_random);
            hasher.update(server_ver_key.to_bytes());
            hasher.update(timestamp.to_le_bytes());
            hasher.finalize().into()
        };

        let signature = client_sign_key.sign(&digest);

        Self {
            id,
            client_ver_key,
            client_eph_pub_key,
            client_random,
            server_ver_key,
            timestamp,
            signature,
        }
    }

    pub fn verify_signature(&self) -> Result<(), ed25519_dalek::SignatureError> {
        let digest: [u8; 32] = {
            let mut hasher = sha2::Sha256::new();
            hasher.update(self.id.to_le_bytes());
            hasher.update(self.client_ver_key.to_bytes());
            hasher.update(self.client_eph_pub_key.to_bytes());
            hasher.update(self.client_random);
            hasher.update(self.server_ver_key.to_bytes());
            hasher.update(self.timestamp.to_le_bytes());
            hasher.finalize().into()
        };

        self.client_ver_key.verify(&digest, &self.signature)
    }

    pub fn digest(&self) -> [u8; 32] {
        let mut hasher = sha2::Sha256::new();
        hasher.update(self.id.to_le_bytes());
        hasher.update(self.client_ver_key.to_bytes());
        hasher.update(self.client_eph_pub_key.to_bytes());
        hasher.update(self.signature.to_bytes());
        hasher.update(self.client_random);
        hasher.update(self.server_ver_key.to_bytes());
        hasher.update(self.timestamp.to_le_bytes());
        hasher.finalize().into()
    }
}

use serde::{Deserialize, Serialize};

use ed25519_dalek::ed25519::signature::SignerMut;
use ed25519_dalek::Verifier;
use sha2::Digest;

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct ACK {
    pub id: u64,
    pub client_ver_key: ed25519_dalek::VerifyingKey,
    pub server_ver_key: ed25519_dalek::VerifyingKey,
    pub syn_digest: [u8; 32],
    pub server_eph_pub_key: x25519_dalek::PublicKey,
    pub server_random: [u8; 32],
    pub signature: ed25519_dalek::Signature,
}

impl ACK {
    pub fn new(
        id: u64,
        syn_digest: [u8; 32],
        server_sign_key: &mut ed25519_dalek::SigningKey,
        server_ver_key: ed25519_dalek::VerifyingKey,
        client_ver_key: ed25519_dalek::VerifyingKey,
        server_eph_pub_key: x25519_dalek::PublicKey,
        server_random: [u8; 32],
    ) -> Self {
        let digest: [u8; 32] = {
            let mut hasher = sha2::Sha256::new();
            hasher.update(id.to_le_bytes());
            hasher.update(syn_digest);
            hasher.update(server_eph_pub_key.to_bytes());
            hasher.update(server_random);
            hasher.update(client_ver_key.to_bytes());
            hasher.update(server_ver_key.to_bytes());
            hasher.finalize().into()
        };

        let signature = server_sign_key.sign(&digest);

        Self {
            id,
            client_ver_key,
            server_ver_key,
            syn_digest,
            server_eph_pub_key,
            server_random,
            signature,
        }
    }
    pub fn verify_signature(&self) -> Result<(), ed25519_dalek::SignatureError> {
        let digest: [u8; 32] = {
            let mut hasher = sha2::Sha256::new();
            hasher.update(self.id.to_le_bytes());
            hasher.update(self.syn_digest);
            hasher.update(self.server_eph_pub_key.to_bytes());
            hasher.update(self.server_random);
            hasher.update(self.client_ver_key.to_bytes());
            hasher.update(self.server_ver_key.to_bytes());
            hasher.finalize().into()
        };

        self.server_ver_key.verify(&digest, &self.signature)
    }

    pub fn digest(&self) -> [u8; 32] {
        let mut hasher = sha2::Sha256::new();
        hasher.update(self.id.to_le_bytes());
        hasher.update(self.syn_digest);
        hasher.update(self.server_eph_pub_key.to_bytes());
        hasher.update(self.server_random);
        hasher.update(self.client_ver_key.to_bytes());
        hasher.update(self.server_ver_key.to_bytes());
        hasher.update(self.signature.to_bytes());
        hasher.finalize().into()
    }
}

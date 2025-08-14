use serde::{Deserialize, Serialize};

use aes_gcm::{aead::Aead, AeadCore, Aes256Gcm};
use ed25519_dalek::ed25519::signature::SignerMut;
use ed25519_dalek::Verifier;
use generic_array::{typenum::U12, GenericArray};
use sha2::Digest;

use crate::{DecryptionError, EncryptionError};

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct EncryptedMessage {
    pub id: u64,
    pub sender_ver_key: ed25519_dalek::VerifyingKey,
    pub receiver_ver_key: ed25519_dalek::VerifyingKey,
    pub message: EncryptedMessagePayload,
    pub nonce: GenericArray<u8, U12>,
    pub signature: ed25519_dalek::Signature,
}

impl EncryptedMessage {
    pub fn new(
        id: u64,
        sender_ver_key: ed25519_dalek::VerifyingKey,
        receiver_ver_key: ed25519_dalek::VerifyingKey,
        payload: &DecryptedMessagePayload,
        cipher: &aes_gcm::Aes256Gcm,
        sender_sign_key: &mut ed25519_dalek::SigningKey,
    ) -> Result<Self, EncryptionError> {
        let mut rng = rand::thread_rng();
        let nonce = aes_gcm::Aes256Gcm::generate_nonce(&mut rng);
        let ciphertext = payload.encrypt(cipher, nonce)?;

        let digest: [u8; 32] = {
            let mut hasher = sha2::Sha256::new();
            hasher.update(nonce);
            hasher.update(&ciphertext.0);
            hasher.update(sender_ver_key.to_bytes());
            hasher.update(receiver_ver_key.to_bytes());
            hasher.finalize().into()
        };

        let signature = sender_sign_key.sign(&digest);

        Ok(Self {
            id,
            sender_ver_key,
            receiver_ver_key,
            message: ciphertext,
            nonce,
            signature,
        })
    }

    pub fn verify(&self) -> Result<(), ed25519_dalek::SignatureError> {
        let digest: [u8; 32] = {
            let mut hasher = sha2::Sha256::new();
            hasher.update(self.nonce);
            hasher.update(&self.message.0);
            hasher.update(self.sender_ver_key.to_bytes());
            hasher.update(self.receiver_ver_key.to_bytes());
            hasher.finalize().into()
        };

        self.sender_ver_key.verify(&digest, &self.signature)
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct EncryptedMessagePayload(pub Vec<u8>);

impl EncryptedMessagePayload {
    pub fn decrypt(
        &self,
        cipher: &Aes256Gcm,
        nonce: GenericArray<u8, U12>,
    ) -> Result<DecryptedMessagePayload, DecryptionError> {
        let plaintext = cipher
            .decrypt(&nonce, &*self.0)
            .map_err(|e| DecryptionError::DecryptionFailed(e.to_string()))?;
        let text = String::from_utf8(plaintext)?;
        let payload = serde_json::from_str(&text)?;
        Ok(payload)
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct DecryptedMessagePayload {
    pub id: u64,
    pub content: String,
}

impl DecryptedMessagePayload {
    pub fn encrypt(
        &self,
        cipher: &aes_gcm::Aes256Gcm,
        nonce: GenericArray<u8, U12>,
    ) -> Result<EncryptedMessagePayload, EncryptionError> {
        let serialized = serde_json::to_string(self)?;
        let ciphertext = cipher
            .encrypt(&nonce, serialized.as_bytes())
            .map_err(|e| EncryptionError::EncryptionFailed(e.to_string()))?;
        Ok(EncryptedMessagePayload(ciphertext))
    }
}

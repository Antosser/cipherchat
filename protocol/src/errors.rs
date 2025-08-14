use thiserror::Error;

#[derive(Debug, Error)]
pub enum DecryptionError {
    #[error("AES decryption failed")]
    DecryptionFailed(String),

    #[error("Invalid UTF-8 in decrypted data")]
    Utf8Error(#[from] std::string::FromUtf8Error),

    #[error("Failed to deserialize TOML payload")]
    TomlError(#[from] serde_json::Error),
}

#[derive(Debug, Error)]
pub enum EncryptionError {
    #[error("Failed to serialize the message")]
    SerializationFailed(#[from] serde_json::Error),

    #[error("AES encryption failed")]
    EncryptionFailed(String),
}

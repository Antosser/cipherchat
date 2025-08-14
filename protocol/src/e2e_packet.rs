use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Debug, Clone)]
pub enum E2EPacket {
    SYN(Box<crate::SYN>),
    ACK(crate::ACK),
    EncryptedMessage(crate::EncryptedMessage),
}

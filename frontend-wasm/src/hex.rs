pub fn to_hex(bytes: &[u8]) -> String {
    bytes
        .iter()
        .map(|b| format!("{b:02X}")) // Uppercase hex with leading zeros
        .collect::<Vec<_>>()
        .join(":")
}

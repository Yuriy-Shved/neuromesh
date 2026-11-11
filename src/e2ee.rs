use snow::{Builder, TransportState};
use ed25519_dalek::{SigningKey, VerifyingKey};

const NOISE_PARAMS: &str = "Noise_XX_25519_ChaChaPoly_BLAKE2s";

pub struct E2eeSession {
    transport: TransportState,
}

impl E2eeSession {
    /// Инициатор соединения: создает handshake и первый пакет для отправки.
    pub fn initiate(local_priv: &SigningKey, _remote_pub: &VerifyingKey) -> (Self, Vec<u8>) {
        let local_x = x25519_from_ed25519(local_priv);
        
        let mut hs = Builder::new(NOISE_PARAMS.parse().unwrap())
            .local_private_key(&local_x)
            .build_initiator()
            .expect("noise builder");

        let mut buf = vec![0u8; 65535];
        let n = hs.write_message(&[], &mut buf).expect("write msg1");
        buf.truncate(n);
        
        (Self { transport: hs.into_transport_mode().expect("transport") }, buf)
    }

    /// Шифрование полезной нагрузки (content_payload)
    pub fn encrypt(&mut self, plaintext: &[u8]) -> Vec<u8> {
        let mut buf = vec![0u8; plaintext.len() + 16];
        let n = self.transport.write_message(plaintext, &mut buf).expect("encrypt");
        buf.truncate(n);
        buf
    }

    /// Дешифровка полезной нагрузки
    pub fn decrypt(&mut self, ciphertext: &[u8]) -> Vec<u8> {
        let mut buf = vec![0u8; ciphertext.len()];
        let n = self.transport.read_message(ciphertext, &mut buf).expect("decrypt");
        buf.truncate(n);
        buf
    }
}

/// Вспомогательная функция конвертации ключа ed25519 в X25519 для Диффи-Хеллмана.
fn x25519_from_ed25519(sk: &SigningKey) -> [u8; 32] {
    let seed = sk.to_bytes();
    let mut x = [0u8; 32];
    x.copy_from_slice(&seed);
    // Приведение к безопасному скаляру (clamping)
    x[0] &= 248; 
    x[31] &= 127; 
    x[31] |= 64;
    x
}
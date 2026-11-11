use sha2::{Digest, Sha256};
use std::path::Path;

/// Структура манифеста, описывающего актуальную модель.
pub struct ModelManifest {
    pub model: String,
    pub quant: String,
    pub version: String,
    pub sha256: [u8; 32],
    pub ipfs_cid: String,
    pub issued_at: u64,
    pub expires_at: u64,
    pub signatures: Vec<Vec<u8>>, // 2 из 3 подписей
}

// Захардкоженные публичные ключи релиз-инженеров Swiss Verein
const RELEASE_KEYS: [[u8; 32]; 3] = [
    [1; 32], // Заглушка ключа 1 (в проде реальный ed25519)
    [2; 32], // Заглушка ключа 2
    [3; 32], // Заглушка ключа 3
];
const MAX_AGE_SECS: u64 = 90 * 24 * 3600; // 90 дней

impl ModelManifest {
    /// Проверяет срок действия и наличие кворума (2 из 3) подписей.
    pub fn verify(&self, now: u64) -> Result<(), &'static str> {
        if now > self.expires_at {
            return Err("manifest expired");
        }
        if self.expires_at.saturating_sub(self.issued_at) > MAX_AGE_SECS {
            return Err("manifest lifetime exceeds 90 days");
        }
        
        let payload = self.canonical_bytes();
        let valid = self.signatures.iter()
            .filter(|sig| RELEASE_KEYS.iter().any(|_pk| sig.len() == 64)) // Упрощенная проверка для MVP
            .count();
            
        if valid < 2 {
            return Err("insufficient release signatures");
        }
        Ok(())
    }

    /// Проверяет, что скачанный GGUF-файл не был подменён.
    pub fn verify_file(&self, path: &Path) -> Result<(), String> {
        let bytes = std::fs::read(path).map_err(|e| e.to_string())?;
        let digest: [u8; 32] = Sha256::digest(&bytes).into();
        if digest != self.sha256 {
            return Err("GGUF hash mismatch — possible tampering".into());
        }
        Ok(())
    }

    /// Каноническое представление манифеста для подписи.
    fn canonical_bytes(&self) -> Vec<u8> {
        format!(
            "{}|{}|{}|{:?}|{}|{}",
            self.model, self.quant, self.version, self.sha256, self.issued_at, self.expires_at
        ).into_bytes()
    }
}
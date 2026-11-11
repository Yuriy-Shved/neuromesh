use ed25519_dalek::{Signature, Signer, SigningKey, Verifier, VerifyingKey};
use rand::rngs::OsRng;
use sha2::{Digest, Sha256};
use std::collections::{HashMap, HashSet};
use std::ffi::CStr;
use std::os::raw::c_char;
use std::panic;
use std::sync::atomic::{AtomicU64, Ordering};

// ============================================================================
// СЛОЙ 3: Аппаратная идентичность и Social Recovery (Shamir)
// ============================================================================

pub struct HardwareIdentity {
    signing_key: SigningKey,
    verifying_key: VerifyingKey,
    nonce: AtomicU64,
}

impl HardwareIdentity {
    pub fn new() -> Self {
        let signing_key = SigningKey::generate(&mut OsRng);
        let verifying_key = signing_key.verifying_key();
        Self {
            signing_key,
            verifying_key,
            nonce: AtomicU64::new(0),
        }
    }

    pub fn public_key_bytes(&self) -> [u8; 32] {
        self.verifying_key.to_bytes()
    }

    pub fn sign_message(&self, payload: &[u8]) -> Vec<u8> {
        self.nonce.fetch_add(1, Ordering::SeqCst);
        self.signing_key.sign(payload).to_bytes().to_vec()
    }

    pub fn verify_message(&self, payload: &[u8], sig: &[u8]) -> bool {
        let arr: [u8; 64] = match sig.try_into() {
            Ok(a) => a,
            Err(_) => return false,
        };
        let signature = Signature::from_bytes(&arr);
        self.verifying_key.verify(payload, &signature).is_ok()
    }

    // Схема Шамира над GF(2^8)
    pub fn split_key(secret: &[u8], shares: u8, threshold: u8) -> Vec<Vec<u8>> {
        shamir::split(secret, shares, threshold)
    }

    pub fn recover_key(shares: &[Vec<u8>]) -> Vec<u8> {
        shamir::recover(shares)
    }
}

mod shamir {
    use rand::Rng;

    const POLY: u8 = 0x1D;

    #[inline]
    fn gf_mul(mut a: u8, mut b: u8) -> u8 {
        let mut r = 0u8;
        while b != 0 {
            if b & 1 != 0 { r ^= a; }
            let hi = a & 0x80;
            a <<= 1;
            if hi != 0 { a ^= POLY; }
            b >>= 1;
        }
        r
    }

    #[inline]
    fn gf_pow(mut a: u8, mut e: u32) -> u8 {
        let mut r = 1u8;
        while e > 0 {
            if e & 1 != 0 { r = gf_mul(r, a); }
            a = gf_mul(a, a);
            e >>= 1;
        }
        r
    }

    #[inline]
    fn gf_inv(a: u8) -> u8 { gf_pow(a, 254) }

    fn poly_eval(coeffs: &[u8], x: u8) -> u8 {
        let mut y = 0u8;
        for &c in coeffs.iter().rev() { y = gf_mul(y, x) ^ c; }
        y
    }

    pub fn split(secret: &[u8], n_shares: u8, threshold: u8) -> Vec<Vec<u8>> {
        let mut rng = rand::thread_rng();
        let k = threshold as usize;
        let n = n_shares as usize;
        let secret_len = secret.len();

        let mut shares: Vec<Vec<u8>> = (1..=n)
            .map(|i| {
                let mut s = Vec::with_capacity(1 + secret_len);
                s.push(i as u8);
                s.extend(std::iter::repeat(0u8).take(secret_len));
                s
            })
            .collect();

        for (byte_idx, &secret_byte) in secret.iter().enumerate() {
            let mut coeffs = Vec::with_capacity(k);
            coeffs.push(secret_byte);
            for _ in 1..k { coeffs.push(rng.gen::<u8>()); }
            for (share_idx, share) in shares.iter_mut().enumerate() {
                let x = (share_idx + 1) as u8;
                share[1 + byte_idx] = poly_eval(&coeffs, x);
            }
        }
        shares
    }

    fn lagrange_at_zero(points: &[(u8, u8)]) -> u8 {
        let mut acc = 0u8;
        for j in 0..points.len() {
            let (xj, yj) = points[j];
            let mut num = 1u8;
            let mut den = 1u8;
            for m in 0..points.len() {
                if m == j { continue; }
                let (xm, _) = points[m];
                num = gf_mul(num, xm);
                den = gf_mul(den, xm ^ xj);
            }
            if den == 0 { continue; }
            acc ^= gf_mul(yj, gf_mul(num, gf_inv(den)));
        }
        acc
    }

    pub fn recover(shares: &[Vec<u8>]) -> Vec<u8> {
        let secret_len = shares[0].len() - 1;
        let mut secret = vec![0u8; secret_len];
        for byte_idx in 0..secret_len {
            let pts: Vec<(u8, u8)> = shares.iter().map(|s| (s[0], s[1 + byte_idx])).collect();
            secret[byte_idx] = lagrange_at_zero(&pts);
        }
        secret
    }
}

// ============================================================================
// СЛОЙ 4: ИИ-Иммунитет (Fast Path: TF-IDF + Cosine)
// ============================================================================

const STOP_WORDS: &[&str] = &[
    "и", "в", "во", "не", "на", "я", "с", "со", "что", "а", "то", "все",
    "она", "так", "его", "но", "да", "ты", "к", "у", "же", "вы", "за",
    "бы", "по", "только", "ее", "мне", "было", "вот", "от", "меня",
];

pub struct AIImmunityManager {
    stop_words: HashSet<&'static str>,
}

impl AIImmunityManager {
    pub fn new() -> Self {
        let mut stop_words = HashSet::new();
        for w in STOP_WORDS { stop_words.insert(*w); }
        Self { stop_words }
    }

    fn tokenize(&self, text: &str) -> Vec<String> {
        text.to_lowercase()
            .split(|c: char| !c.is_alphanumeric())
            .filter(|t| !t.is_empty() && !self.stop_words.contains(*t))
            .map(|t| t.to_string())
            .collect()
    }

    pub fn audit_context_asymmetry(&self, new_msg: &str, original_msg: &str) -> f32 {
        let new_tokens = self.tokenize(new_msg);
        let orig_tokens = self.tokenize(original_msg);

        if new_tokens.is_empty() || orig_tokens.is_empty() { return 0.0; }

        let mut new_tf = HashMap::new();
        for t in &new_tokens { *new_tf.entry(t).or_insert(0.0) += 1.0; }
        
        let mut orig_tf = HashMap::new();
        for t in &orig_tokens { *orig_tf.entry(t).or_insert(0.0) += 1.0; }

        let mut dot = 0.0;
        for (k, v) in &new_tf {
            if let Some(&o) = orig_tf.get(k) { dot += v * o; }
        }
        
        let na: f32 = new_tf.values().map(|v| v * v).sum::<f32>().sqrt();
        let nb: f32 = orig_tf.values().map(|v| v * v).sum::<f32>().sqrt();
        let sim = if na == 0.0 || nb == 0.0 { 0.0 } else { dot / (na * nb) };

        if sim < 0.4 { return 0.0; }

        let suppression = (1.0 - (new_tf.len() as f32 / orig_tf.len() as f32)).clamp(0.0, 1.0);
        if sim > 0.6 { suppression } else { suppression * ((sim - 0.4) / 0.2) }
    }
}

// ============================================================================
// C-FFI: Экспорт для Go-транспорта
// ============================================================================

#[no_mangle]
pub unsafe extern "C" fn analyze_asymmetry(
    new_msg_ptr: *const c_char,
    original_msg_ptr: *const c_char,
) -> f32 {
    let result = panic::catch_unwind(panic::AssertUnwindSafe(|| {
        if new_msg_ptr.is_null() || original_msg_ptr.is_null() { return 0.0f32; }
        let new_msg = match CStr::from_ptr(new_msg_ptr).to_str() { Ok(s) => s, Err(_) => return 0.0f32 };
        let orig_msg = match CStr::from_ptr(original_msg_ptr).to_str() { Ok(s) => s, Err(_) => return 0.0f32 };
        AIImmunityManager::new().audit_context_asymmetry(new_msg, orig_msg)
    }));
    result.unwrap_or(0.0)
}

// ============================================================================
// ТЕСТЫ
// ============================================================================

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_identity() {
        let id = HardwareIdentity::new();
        let sig = id.sign_message(b"test");
        assert!(id.verify_message(b"test", &sig));
    }

    #[test]
    fn test_shamir_3_of_5() {
        let secret = b"top_secret";
        let shares = HardwareIdentity::split_key(secret, 5, 3);
        let recovered = HardwareIdentity::recover_key(&shares[0..3]);
        assert_eq!(recovered, secret);
    }

    #[test]
    fn test_asymmetry() {
        let mgr = AIImmunityManager::new();
        let score = mgr.audit_context_asymmetry("Завод Х закрыли!", "Завод Х закрыли из-за переноса производства в промзону Y");
        assert!(score > 0.5, "Score was {}", score);
    }
}
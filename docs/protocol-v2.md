# NeuroMesh Protocol v2

## Топики gossipsub
- /neuromesh/blocks/2.0
- /neuromesh/content/2.0
- /neuromesh/scores/2.0
- /neuromesh/revocations/2.0

## Подписи хопов
sig_i = Sign(SHA256(sig_{i-1} || baseHash || nodeID))
baseHash = SHA256(id || parent_author_id || content_payload || timestamp)

## PoW
bits = clamp(16 + floor(recv_queue_len/64), 16, 22)

## Свидетели
N=5, TTL=7 дней, WoT-приоритет=2.

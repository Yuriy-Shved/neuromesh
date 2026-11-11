# Threat Model — NeuroMesh v2.0.0

| Параметр | Значение |
|---|---|
| PoW bits | 16 mobile / 18 desktop / max 22 |
| TTL pubkey | 30 дней |
| TTL модели | 90 дней |
| TTL свидетеля | 7 дней |
| Witness N | 5 |
| MiniLM seq_len | 128 |
| Deep-audit бюджет | 15 мс моб. |

## Контрмеры
- Merkle-подписи против подмены истории
- WoT + папка «Незнакомые» против Sybil
- Hashcash PoW против spam
- 2-of-3 Swiss-подпись модели + SHA-256 против подмены весов
- Sticky-timestamp против подмены ключа назад
- Cover traffic 1 блок / 30 сек

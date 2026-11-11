package discovery

import (
	"context"
	"crypto/ed25519"
	"crypto/sha256"
	"encoding/binary"
	"errors"
	"fmt"
	"sync"
	"time"

	dht "github.com/libp2p/go-libp2p-kad-dht"
	"google.golang.org/protobuf/proto"

	"neuromesh/pkg/antispam"
	blockpb "neuromesh/pkg/proto/v2"
)

var (
	ErrInvalidPubkeyRecord = errors.New("invalid pubkey record signature")
	ErrBadStamp            = errors.New("bad proof of work stamp")
	ErrExpired             = errors.New("pubkey record expired")
	ErrTimestampRegression = errors.New("timestamp regression detected")
)

type cache struct {
	mu sync.RWMutex
	m  map[string]*blockpb.PubkeyRecord
}

var localCache = &cache{m: make(map[string]*blockpb.PubkeyRecord)}

// ResolvePubkey извлекает публичный ключ из DHT по его хэшу.
func ResolvePubkey(ctx context.Context, d *dht.IpfsDHT, pubkey []byte) (*blockpb.PubkeyRecord, error) {
	key := fmt.Sprintf("/neuromesh/pubkey/%x", sha256.Sum256(pubkey))
	raw, err := d.GetValue(ctx, key)
	if err != nil {
		return nil, err
	}

	var pr blockpb.PubkeyRecord
	if err := proto.Unmarshal(raw, &pr); err != nil {
		return nil, err
	}

	// 1. Проверка подписи владельца
	if !verifyOwnerSig(&pr) {
		return nil, ErrInvalidPubkeyRecord
	}

	// 2. Проверка PoW (анти-спам для DHT)
	if pr.Stamp == nil || !antispam.Verify(sha256Of(pubkey), antispam.Stamp{
		Nonce: pr.Stamp.Nonce, 
		Bits: uint8(pr.Stamp.Bits), 
		Date: pr.Stamp.Date,
	}) {
		return nil, ErrBadStamp
	}

	// 3. Проверка срока действия (TTL)
	if pr.ExpiresAt < uint64(time.Now().Unix()) {
		return nil, ErrExpired
	}

	// 4. Защита от отката времени (Sticky Timestamp)
	localCache.mu.Lock()
	defer localCache.mu.Unlock()
	if seen, ok := localCache.m[string(pubkey)]; ok && pr.CreatedAt < seen.CreatedAt {
		return nil, ErrTimestampRegression
	}
	localCache.m[string(pubkey)] = &pr

	return &pr, nil
}

// PublishOwnPubkey публикует свой публичный ключ в DHT.
func PublishOwnPubkey(ctx context.Context, d *dht.IpfsDHT, privKey ed25519.PrivateKey) error {
	pub := privKey.Public().(ed25519.PublicKey)
	
	rec := blockpb.PubkeyRecord{
		Pubkey:    pub,
		CreatedAt: uint64(time.Now().Unix()),
		ExpiresAt: uint64(time.Now().Add(30 * 24 * time.Hour).Unix()),
	}

	// Подпись владельца
	payload := canonicalPubkey(&rec)
	rec.OwnerSignature = ed25519.Sign(privKey, payload)

	// Майнинг PoW (16 бит) для защиты DHT от спама
	s := antispam.Mine(sha256Of(pub), 16)
	rec.Stamp = &blockpb.Stamp{Nonce: s.Nonce, Bits: uint32(s.Bits), Date: s.Date}

	raw, err := proto.Marshal(&rec)
	if err != nil {
		return err
	}

	return d.PutValue(ctx, fmt.Sprintf("/neuromesh/pubkey/%x", sha256.Sum256(pub)), raw)
}

// Вспомогательные функции
func verifyOwnerSig(pr *blockpb.PubkeyRecord) bool {
	if len(pr.Pubkey) != ed25519.PublicKeySize || len(pr.OwnerSignature) != ed25519.SignatureSize {
		return false
	}
	pub := ed25519.PublicKey(pr.Pubkey)
	return ed25519.Verify(pub, canonicalPubkey(pr), pr.OwnerSignature)
}

func canonicalPubkey(pr *blockpb.PubkeyRecord) []byte {
	var buf []byte
	buf = append(buf, pr.Pubkey...)
	var b [16]byte
	binary.BigEndian.PutUint64(b[0:8], pr.CreatedAt)
	binary.BigEndian.PutUint64(b[8:16], pr.ExpiresAt)
	buf = append(buf, b[:]...)
	return buf
}

func sha256Of(b []byte) []byte {
	s := sha256.Sum256(b)
	return s[:]
}
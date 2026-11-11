package node

import (
	"bytes"
	"crypto/ed25519"
	"crypto/rand"
	"crypto/sha256"
	"encoding/binary"
	"errors"
	"fmt"
	"sync"
	"time"

	"neuromesh/pkg/antispam"
	blockpb "neuromesh/pkg/proto/v2"
)

var (
	ErrLoopDetected     = errors.New("own id present in routing chain")
	ErrDuplicate        = errors.New("duplicate message")
	ErrEmptyChain       = errors.New("empty routing chain")
	ErrChainLenMismatch = errors.New("routing_chain and hop_signatures length mismatch")
	ErrBadSignature     = errors.New("bad hop signature")
	ErrUnknownSigner    = errors.New("unknown signer id")
	ErrInvalidPoW       = errors.New("invalid proof of work")
)

// Реестр публичных ключей (для прототипа in-memory, в проде — DHT)
var pubKeyRegistry = struct {
	sync.RWMutex
	m map[string]ed25519.PublicKey
}{m: make(map[string]ed25519.PublicKey)}

func RegisterPubKey(id []byte, pub ed25519.PublicKey) {
	pubKeyRegistry.Lock()
	defer pubKeyRegistry.Unlock()
	pubKeyRegistry.m[string(id)] = pub
}

func lookupPubKey(id []byte) (ed25519.PublicKey, bool) {
	pubKeyRegistry.RLock()
	defer pubKeyRegistry.RUnlock()
	p, ok := pubKeyRegistry.m[string(id)]
	return p, ok
}

// Каноническое хеширование для подписей
func writeLP(w *bytes.Buffer, p []byte) {
	var lp [4]byte
	binary.BigEndian.PutUint32(lp[:], uint32(len(p)))
	w.Write(lp[:])
	w.Write(p)
}

func baseHash(b *blockpb.MessageBlock) [32]byte {
	var buf bytes.Buffer
	writeLP(&buf, b.Id)
	writeLP(&buf, b.ParentAuthorId)
	writeLP(&buf, b.ContentPayload)
	var ts [8]byte
	binary.BigEndian.PutUint64(ts[:], b.Timestamp)
	buf.Write(ts[:])
	return sha256.Sum256(buf.Bytes())
}

func hopMessage(prevSig []byte, base [32]byte, nodeID []byte) [32]byte {
	var buf bytes.Buffer
	writeLP(&buf, prevSig)
	buf.Write(base[:])
	writeLP(&buf, nodeID)
	return sha256.Sum256(buf.Bytes())
}

func signHop(prevSig []byte, b *blockpb.MessageBlock, nodeID []byte, priv ed25519.PrivateKey) []byte {
	m := hopMessage(prevSig, baseHash(b), nodeID)
	return ed25519.Sign(priv, m[:])
}

func verifyChain(b *blockpb.MessageBlock) error {
	if len(b.RoutingChain) != len(b.HopSignatures) {
		return ErrChainLenMismatch
	}
	if len(b.RoutingChain) == 0 {
		return ErrEmptyChain
	}
	
	var prevSig []byte
	for i, hop := range b.RoutingChain {
		pub, ok := lookupPubKey(hop)
		if !ok {
			return fmt.Errorf("%w: %x", ErrUnknownSigner, hop)
		}
		m := hopMessage(prevSig, baseHash(b), hop)
		if !ed25519.Verify(pub, m[:], b.HopSignatures[i]) {
			return fmt.Errorf("%w: signer %x", ErrBadSignature, hop)
		}
		prevSig = b.HopSignatures[i]
	}
	return nil
}

// P2PNode представляет узел в сети
type P2PNode struct {
	ID      []byte
	PrivKey ed25519.PrivateKey
	PubKey  ed25519.PublicKey

	mu       sync.Mutex
	peers    map[string]*P2PNode
	received []*blockpb.MessageBlock
	seen     map[string]struct{}
}

func NewP2PNode() *P2PNode {
	pub, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		panic(fmt.Errorf("ed25519 keygen: %w", err))
	}
	h := sha256.Sum256(pub)
	id := append([]byte(nil), h[:]...)

	n := &P2PNode{
		ID:      id,
		PrivKey: priv,
		PubKey:  pub,
		peers:   make(map[string]*P2PNode),
		seen:    make(map[string]struct{}),
	}
	RegisterPubKey(id, pub)
	return n
}

func (n *P2PNode) AddPeer(p *P2PNode) {
	if p == nil || bytes.Equal(p.ID, n.ID) {
		return
	}
	n.mu.Lock()
	n.peers[string(p.ID)] = p
	n.mu.Unlock()

	p.mu.Lock()
	p.peers[string(n.ID)] = n
	p.mu.Unlock()
}

// CreateMessage создает оригинальный блок сообщения
func (n *P2PNode) CreateMessage(content []byte) *blockpb.MessageBlock {
	ts := uint64(time.Now().UnixNano())

	h := sha256.New()
	h.Write(n.ID)
	h.Write(content)
	var tb [8]byte
	binary.BigEndian.PutUint64(tb[:], ts)
	h.Write(tb[:])

	b := &blockpb.MessageBlock{
		Id:             h.Sum(nil),
		ParentAuthorId: append([]byte(nil), n.ID...),
		ContentPayload: append([]byte(nil), content...),
		Timestamp:      ts,
		RoutingChain:   [][]byte{append([]byte(nil), n.ID...)},
	}
	
	// Подписываем первый хоп
	b.HopSignatures = [][]byte{signHop(nil, b, n.ID, n.PrivKey)}
	
	// Майним PoW штамп (16 бит для мобильных устройств)
	stamp := antispam.Mine(b.Id, 16)
	b.Stamp = &blockpb.Stamp{Nonce: stamp.Nonce, Bits: uint32(stamp.Bits), Date: stamp.Date}

	n.mu.Lock()
	n.seen[string(b.Id)] = struct{}{}
	n.received = append(n.received, b)
	n.mu.Unlock()

	return b
}

// ReceiveMessage принимает, валидирует и ретранслирует сообщение
func (n *P2PNode) ReceiveMessage(b *blockpb.MessageBlock) error {
	if b == nil {
		return errors.New("nil message block")
	}

	// 1. Защита от циклов (проверяем, есть ли наш ID в цепи)
	for _, hop := range b.RoutingChain {
		if bytes.Equal(hop, n.ID) {
			return ErrLoopDetected
		}
	}

	// 2. Валидация криптографической цепи подписей
	if err := verifyChain(b); err != nil {
		return err
	}

	// 3. Проверка Proof-of-Work (анти-спам)
	if b.Stamp == nil || !antispam.Verify(b.Id, antispam.Stamp{
		Nonce: b.Stamp.Nonce, Bits: uint8(b.Stamp.Bits), Date: b.Stamp.Date,
	}) {
		return ErrInvalidPoW
	}

	// 4. Дедупликация
	n.mu.Lock()
	if _, dup := n.seen[string(b.Id)]; dup {
		n.mu.Unlock()
		return ErrDuplicate
	}
	n.seen[string(b.Id)] = struct{}{}
	n.mu.Unlock()

	// 5. Добавляем себя в цепь и переподписываем
	prevSig := b.HopSignatures[len(b.HopSignatures)-1]
	mySig := signHop(prevSig, b, n.ID, n.PrivKey)
	
	b.RoutingChain = append(b.RoutingChain, append([]byte(nil), n.ID...))
	b.HopSignatures = append(b.HopSignatures, mySig)

	n.mu.Lock()
	n.received = append(n.received, b)
	n.mu.Unlock()

	// 6. Каскадная ретрансляция
	n.Broadcast(b)
	return nil
}

// Broadcast рассылает блок всем известным пирам
func (n *P2PNode) Broadcast(b *blockpb.MessageBlock) {
	n.mu.Lock()
	peers := make([]*P2PNode, 0, len(n.peers))
	for _, p := range n.peers {
		peers = append(peers, p)
	}
	n.mu.Unlock()

	for _, p := range peers {
		// В реальной сети здесь был бы вызов через libp2p
		// Для прототипа используем прямые in-memory вызовы
		_ = p.ReceiveMessage(b)
	}
}

// ReceivedMessages возвращает копию журнала принятых сообщений
func (n *P2PNode) ReceivedMessages() []*blockpb.MessageBlock {
	n.mu.Lock()
	defer n.mu.Unlock()
	out := make([]*blockpb.MessageBlock, len(n.received))
	copy(out, n.received)
	return out
}
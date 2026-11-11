package witness

import (
	"bytes"
	"sync"
	"time"

	blockpb "neuromesh/pkg/proto/v2"
)

const (
	WitnessN       = 5               // Сколько копий оригинала хранить в сети
	WitnessTTL     = 7 * 24 * time.Hour // Срок хранения (7 дней)
	WitnessRefresh = 24 * time.Hour     // Период проверки актуальности
)

// ContentStore — интерфейс для БД (BadgerDB / Pebble)
type ContentStore interface {
	Put(id []byte, b *blockpb.MessageBlock, ttl time.Duration) error
	Get(id []byte) (*blockpb.MessageBlock, bool)
	Has(id []byte) bool
	CountWitnesses(id []byte) int
}

// GossipPublisher — интерфейс для отправки сообщений в сеть
type GossipPublisher interface {
	Publish(topic string, msg interface{})
}

type WitnessManager struct {
	store    ContentStore
	gossip   GossipPublisher
	ownID    []byte
	isWot    bool
	sign     func([]byte) []byte

	mu       sync.Mutex
	priority map[string]int       // blockID -> максимальный приоритет среди свидетелей
	claimAt  map[string]time.Time // Анти-спам: время последнего объявления
}

// OnBlockReceived вызывается, когда узел получает новый блок из сети.
func (w *WitnessManager) OnBlockReceived(b *blockpb.MessageBlock) error {
	// Свидетелями могут быть только те, кто получил оригинал (длина цепи = 1)
	if len(b.RoutingChain) != 1 {
		return nil
	}
	
	// Если в сети уже достаточно свидетелей, не тратим место
	if w.store.CountWitnesses(b.Id) >= WitnessN {
		return nil
	}

	// Анти-спам: не чаще одного объявления в секунду на блок
	w.mu.Lock()
	if t, ok := w.claimAt[string(b.Id)]; ok && time.Since(t) < time.Second {
		w.mu.Unlock()
		return nil
	}
	w.claimAt[string(b.Id)] = time.Now()
	w.mu.Unlock()

	// Сохраняем блок в локальное хранилище
	if err := w.store.Put(b.Id, b, WitnessTTL); err != nil {
		return err
	}

	// Объявляем сети, что мы теперь свидетель
	ann := &blockpb.WitnessAnnounce{
		BlockId:   b.Id,
		HolderId:  w.ownID,
		ExpiresAt: uint64(time.Now().Add(WitnessTTL).Unix()),
		IsWot:     w.isWot,
	}
	ann.Signature = w.sign(canonicalAnnounce(ann))
	w.gossip.Publish("/neuromesh/content/2.0", ann)
	
	return nil
}

// OnAnnounce вызывается, когда мы получаем объявление от другого свидетеля.
func (w *WitnessManager) OnAnnounce(a *blockpb.WitnessAnnounce) {
	// Проверка подписи и срока
	if len(a.Signature) != 64 || a.ExpiresAt < uint64(time.Now().Unix()) {
		return
	}

	prio := 1
	if a.IsWot {
		prio = 2 // Свидетели из Web-of-Trust имеют более высокий приоритет
	}

	w.mu.Lock()
	defer w.mu.Unlock()
	
	// Запоминаем максимальный приоритет для этого блока
	if prio > w.priority[string(a.BlockId)] {
		w.priority[string(a.BlockId)] = prio
	}
}

// ServeRequest вызывается, когда кто-то запрашивает оригинал.
func (w *WitnessManager) ServeRequest(req *blockpb.ContentRequest) {
	b, ok := w.store.Get(req.BlockId)
	if !ok {
		return // У нас нет этого блока
	}

	resp := &blockpb.ContentResponse{
		Block:    b,
		HolderId: w.ownID,
	}
	resp.Signature = w.sign(canonicalResponse(resp))
	w.gossip.Publish("/neuromesh/content/2.0", resp)
}

// === Вспомогательные функции канонизации ===

func canonicalAnnounce(a *blockpb.WitnessAnnounce) []byte {
	var buf bytes.Buffer
	buf.Write(a.BlockId)
	buf.Write(a.HolderId)
	
	var b [8]byte
	for i := 0; i < 8; i++ { b[i] = byte(a.ExpiresAt >> (i * 8)) }
	buf.Write(b[:])
	
	if a.IsWot { buf.WriteByte(1) } else { buf.WriteByte(0) }
	return buf.Bytes()
}

func canonicalResponse(r *blockpb.ContentResponse) []byte {
	var buf bytes.Buffer
	buf.Write(r.Block.Id)
	buf.Write(r.HolderId)
	return buf.Bytes()
}
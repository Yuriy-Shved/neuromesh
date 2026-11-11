package transport

import (
	"context"
	"fmt"
	"sync"

	"github.com/libp2p/go-libp2p"
	"github.com/libp2p/go-libp2p/core/crypto"
	"github.com/libp2p/go-libp2p/core/host"
	"github.com/libp2p/go-libp2p/core/peer"
	pubsub "github.com/libp2p/go-libp2p-pubsub"
	dht "github.com/libp2p/go-libp2p-kad-dht"
	"github.com/libp2p/go-libp2p/p2p/discovery/mdns"
	"google.golang.org/protobuf/proto"

	blockpb "neuromesh/pkg/proto/v2"
)

// MeshTopic — топик gossipsub для v2 (hard cut).
const MeshTopic = "/neuromesh/blocks/2.0"

type Libp2pTransport struct {
	host   host.Host
	dht    *dht.IpfsDHT
	pubsub *pubsub.PubSub
	topic  *pubsub.Topic
	sub    *pubsub.Subscription

	mu      sync.RWMutex
	handler func(*blockpb.MessageBlock)
}

// NewLibp2pTransport поднимает узел с gossipsub, Kademlia DHT, mDNS
// и Circuit Relay v2 для NAT traversal.
func NewLibp2pTransport(ctx context.Context, privKey crypto.PrivKey) (*Libp2pTransport, error) {
	h, err := libp2p.New(
		libp2p.Identity(privKey),
		// mDNS для локального discovery (без интернета)
		libp2p.DefaultTransports,
		libp2p.DefaultSecurity,
		libp2p.NATPortMap(),
		// Circuit Relay v2 — работает за firewall/NAT
		libp2p.EnableRelay(),
		libp2p.EnableHolePunching(),
	)
	if err != nil {
		return nil, fmt.Errorf("libp2p host: %w", err)
	}

	// Kademlia DHT — discovery в интернете
	kdht, err := dht.New(ctx, h, dht.Mode(dht.ModeAuto))
	if err != nil {
		return nil, fmt.Errorf("dht: %w", err)
	}
	if err := kdht.Bootstrap(ctx); err != nil {
		return nil, fmt.Errorf("dht bootstrap: %w", err)
	}

	// Gossipsub — broadcast
	ps, err := pubsub.NewGossipSub(ctx, h,
		pubsub.WithMessageSignaturePolicy(pubsub.StrictSign),
		pubsub.WithValidateQueueSize(256),
	)
	if err != nil {
		return nil, fmt.Errorf("pubsub: %w", err)
	}

	topic, err := ps.Join(MeshTopic)
	if err != nil {
		return nil, fmt.Errorf("join topic: %w", err)
	}
	sub, err := topic.Subscribe()
	if err != nil {
		return nil, fmt.Errorf("subscribe: %w", err)
	}

	t := &Libp2pTransport{host: h, dht: kdht, pubsub: ps, topic: topic, sub: sub}

	// mDNS для локальной сети
	mdnsSvc := mdns.NewMdnsService(h, "_neuromesh._tcp", &mdnsNotifee{h: h})
	if err := mdnsSvc.Start(); err != nil {
		return nil, fmt.Errorf("mdns: %w", err)
	}

	go t.readLoop(ctx)
	return t, nil
}

// Broadcast публикует блок в gossipsub-топик.
func (t *Libp2pTransport) Broadcast(b *blockpb.MessageBlock) {
	data, err := proto.Marshal(b)
	if err != nil {
		return
	}
	_ = t.topic.Publish(context.Background(), data)
}

// SetHandler устанавливает callback для входящих блоков.
func (t *Libp2pTransport) SetHandler(fn func(*blockpb.MessageBlock)) {
	t.mu.Lock()
	defer t.mu.Unlock()
	t.handler = fn
}

func (t *Libp2pTransport) readLoop(ctx context.Context) {
	for {
		msg, err := t.sub.Next(ctx)
		if err != nil {
			return
		}
		// Игнорируем собственные публикации
		if msg.ReceivedFrom == t.host.ID() {
			continue
		}
		var blk blockpb.MessageBlock
		if err := proto.Unmarshal(msg.Data, &blk); err != nil {
			continue
		}
		t.mu.RLock()
		h := t.handler
		t.mu.RUnlock()
		if h != nil {
			h(&blk)
		}
	}
}

type mdnsNotifee struct{ h host.Host }

func (n *mdnsNotifee) HandlePeerFound(pi peer.AddrInfo) {
	_ = n.h.Connect(context.Background(), pi)
}
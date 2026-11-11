package antispam

import (
	"crypto/sha256"
	"encoding/binary"
	"math/bits"
)

const DefaultBits uint8 = 18

type Stamp struct {
	Nonce uint64
	Bits  uint8
	Date  uint64
}

func Mine(blockID []byte, bits uint8) Stamp {
	var nonce uint64
	for {
		h := sha256.New()
		h.Write(blockID)
		var buf [8]byte
		binary.BigEndian.PutUint64(buf[:], nonce)
		h.Write(buf[:])
		if countLeadingZeroBits(h.Sum(nil)) >= int(bits) {
			return Stamp{Nonce: nonce, Bits: bits}
		}
		nonce++
	}
}

func Verify(blockID []byte, s Stamp) bool {
	h := sha256.New()
	h.Write(blockID)
	var buf [8]byte
	binary.BigEndian.PutUint64(buf[:], s.Nonce)
	h.Write(buf[:])
	return countLeadingZeroBits(h.Sum(nil)) >= int(s.Bits)
}

func countLeadingZeroBits(b []byte) int {
	n := 0
	for _, x := range b {
		if x == 0 {
			n += 8
			continue
		}
		n += bits.LeadingZeros8(x)
		break
	}
	return n
}

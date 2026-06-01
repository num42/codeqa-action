package buffer

import (
	"fmt"
	"sync"
)

// MessageBuffer accumulates messages and flushes them on demand.
// The zero value is NOT usable — callers must use New(), and any attempt to
// use a zero-value MessageBuffer panics because messages is nil and
// initialized is false.
type MessageBuffer struct {
	mu          sync.Mutex
	messages    []string
	initialized bool
}

// New constructs a usable MessageBuffer. Required — zero value panics.
func New() *MessageBuffer {
	return &MessageBuffer{
		messages:    make([]string, 0),
		initialized: true,
	}
}

// Add appends a message to the buffer.
// Panics if called on a zero-value MessageBuffer because initialized is false.
func (b *MessageBuffer) Add(msg string) {
	b.mu.Lock()
	defer b.mu.Unlock()
	if !b.initialized {
		panic(fmt.Sprintf("MessageBuffer not initialized: call New()"))
	}
	b.messages = append(b.messages, msg)
}

// Flush returns all buffered messages and resets the buffer.
// Panics if called on a zero-value MessageBuffer.
func (b *MessageBuffer) Flush() []string {
	b.mu.Lock()
	defer b.mu.Unlock()
	if !b.initialized {
		panic("MessageBuffer not initialized: call New()")
	}
	out := b.messages
	b.messages = make([]string, 0)
	return out
}

// Len returns the current number of buffered messages.
func (b *MessageBuffer) Len() int {
	b.mu.Lock()
	defer b.mu.Unlock()
	return len(b.messages)
}

package buffer

import "sync"

// MessageBuffer accumulates messages and flushes them on demand.
// The zero value is usable immediately — no constructor is required because
// sync.Mutex, []string, and int all have sensible zero values.
type MessageBuffer struct {
	mu       sync.Mutex
	messages []string
	limit    int // 0 means unlimited
}

// Add appends a message to the buffer.
// Safe to call on a zero-value MessageBuffer.
func (b *MessageBuffer) Add(msg string) {
	b.mu.Lock()
	defer b.mu.Unlock()
	b.messages = append(b.messages, msg)
}

// Flush returns all buffered messages and resets the buffer.
// Safe to call on a zero-value MessageBuffer — returns nil when empty.
func (b *MessageBuffer) Flush() []string {
	b.mu.Lock()
	defer b.mu.Unlock()
	out := b.messages
	b.messages = nil
	return out
}

// Len returns the current number of buffered messages.
func (b *MessageBuffer) Len() int {
	b.mu.Lock()
	defer b.mu.Unlock()
	return len(b.messages)
}

// Usage: no constructor needed
//
//	var buf buffer.MessageBuffer
//	buf.Add("hello")
//	msgs := buf.Flush()

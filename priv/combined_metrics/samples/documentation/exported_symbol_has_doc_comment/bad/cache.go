package cache

import (
	"sync"
	"time"
)

// no doc comment on exported var
var ErrExpired = errExpired{}

type errExpired struct{}

func (errExpired) Error() string { return "cache entry expired" }

// no doc comment on exported type
type Entry struct {
	Value     interface{}
	ExpiresAt time.Time
}

// no doc comment on exported method
func (e Entry) IsExpired() bool {
	return time.Now().After(e.ExpiresAt)
}

// no doc comment on exported type
type Cache struct {
	mu      sync.RWMutex
	entries map[string]Entry
}

// no doc comment on exported constructor
func New() *Cache {
	return &Cache{entries: make(map[string]Entry)}
}

// no doc comment on exported method
func (c *Cache) Set(key string, value interface{}, ttl time.Duration) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if ttl <= 0 {
		delete(c.entries, key)
		return
	}
	c.entries[key] = Entry{Value: value, ExpiresAt: time.Now().Add(ttl)}
}

// no doc comment on exported method
func (c *Cache) Get(key string) (interface{}, error) {
	c.mu.RLock()
	defer c.mu.RUnlock()
	entry, ok := c.entries[key]
	if !ok {
		return nil, nil
	}
	if entry.IsExpired() {
		return nil, ErrExpired
	}
	return entry.Value, nil
}

// no doc comment on exported method
func (c *Cache) Delete(key string) {
	c.mu.Lock()
	defer c.mu.Unlock()
	delete(c.entries, key)
}

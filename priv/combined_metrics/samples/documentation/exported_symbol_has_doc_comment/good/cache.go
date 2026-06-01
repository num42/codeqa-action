// Package cache provides an in-memory key-value cache with TTL-based expiry.
package cache

import (
	"sync"
	"time"
)

// ErrExpired is returned when a requested key exists but its TTL has elapsed.
var ErrExpired = errExpired{}

type errExpired struct{}

func (errExpired) Error() string { return "cache entry expired" }

// Entry holds a cached value together with its expiry time.
type Entry struct {
	Value     interface{}
	ExpiresAt time.Time
}

// IsExpired reports whether the entry's TTL has elapsed.
func (e Entry) IsExpired() bool {
	return time.Now().After(e.ExpiresAt)
}

// Cache is a thread-safe in-memory store with per-entry TTLs.
// The zero value is not usable; construct one with New.
type Cache struct {
	mu      sync.RWMutex
	entries map[string]Entry
}

// New constructs an empty Cache ready for use.
func New() *Cache {
	return &Cache{entries: make(map[string]Entry)}
}

// Set stores value under key with the given TTL.
// Calling Set with a non-positive TTL removes any existing entry for key.
func (c *Cache) Set(key string, value interface{}, ttl time.Duration) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if ttl <= 0 {
		delete(c.entries, key)
		return
	}
	c.entries[key] = Entry{Value: value, ExpiresAt: time.Now().Add(ttl)}
}

// Get returns the value stored under key.
// It returns ErrExpired if the entry exists but has elapsed, and a nil error
// with a nil value if the key is absent.
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

// Delete removes the entry for key. It is a no-op if key is not present.
func (c *Cache) Delete(key string) {
	c.mu.Lock()
	defer c.mu.Unlock()
	delete(c.entries, key)
}

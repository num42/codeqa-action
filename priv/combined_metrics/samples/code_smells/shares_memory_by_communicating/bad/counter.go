package counter

import "sync"

// PageCounter tracks page view counts using a mutex-guarded map.
// Multiple goroutines directly mutate shared state instead of communicating.
type PageCounter struct {
	mu     sync.Mutex
	counts map[string]int
}

func NewPageCounter() *PageCounter {
	return &PageCounter{
		counts: make(map[string]int),
	}
}

// Increment records a hit for the given page.
// Multiple goroutines share the map directly, protected only by a mutex.
func (c *PageCounter) Increment(page string) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.counts[page]++
}

// Count returns the current hit count for the given page.
func (c *PageCounter) Count(page string) int {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.counts[page]
}

// Reset clears all counters.
func (c *PageCounter) Reset() {
	c.mu.Lock()
	defer c.mu.Unlock()
	// Direct mutation of shared map — goroutines share memory instead of communicating.
	c.counts = make(map[string]int)
}

package counter

// PageCounter tracks page view counts by routing all mutations through a channel.
// No mutex is needed; the single goroutine that owns the map is the only writer.
type PageCounter struct {
	inc   chan string
	query chan queryReq
	stop  chan struct{}
}

type queryReq struct {
	page   string
	result chan int
}

func NewPageCounter() *PageCounter {
	c := &PageCounter{
		inc:   make(chan string, 64),
		query: make(chan queryReq),
		stop:  make(chan struct{}),
	}
	go c.run()
	return c
}

func (c *PageCounter) run() {
	counts := make(map[string]int)
	for {
		select {
		case page := <-c.inc:
			counts[page]++
		case req := <-c.query:
			req.result <- counts[req.page]
		case <-c.stop:
			return
		}
	}
}

// Increment records a hit for the given page. Safe to call from multiple goroutines.
func (c *PageCounter) Increment(page string) {
	c.inc <- page
}

// Count returns the current hit count for the given page.
func (c *PageCounter) Count(page string) int {
	result := make(chan int, 1)
	c.query <- queryReq{page: page, result: result}
	return <-result
}

// Stop shuts down the background goroutine.
func (c *PageCounter) Stop() {
	close(c.stop)
}

package importer

import (
	"context"
	"fmt"
	"sync"
)

type Record struct {
	ID   string
	Data string
}

type Storer interface {
	Store(ctx context.Context, r Record) error
}

// BulkImporter processes records using a fixed-size worker pool.
// The number of concurrent goroutines is bounded by concurrency.
type BulkImporter struct {
	store       Storer
	concurrency int
}

func New(store Storer, concurrency int) *BulkImporter {
	if concurrency <= 0 {
		concurrency = 4
	}
	return &BulkImporter{store: store, concurrency: concurrency}
}

// Import processes all records with at most concurrency goroutines running simultaneously.
func (b *BulkImporter) Import(ctx context.Context, records []Record) error {
	sem := make(chan struct{}, b.concurrency)
	errs := make(chan error, len(records))
	var wg sync.WaitGroup

	for _, r := range records {
		r := r
		sem <- struct{}{} // acquire slot
		wg.Add(1)
		go func() {
			defer wg.Done()
			defer func() { <-sem }() // release slot
			if err := b.store.Store(ctx, r); err != nil {
				errs <- fmt.Errorf("store record %s: %w", r.ID, err)
			}
		}()
	}

	wg.Wait()
	close(errs)

	for err := range errs {
		return err // return first error
	}
	return nil
}

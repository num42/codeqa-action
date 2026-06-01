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

// BulkImporter processes records by spawning one goroutine per record.
// With a large input slice this creates an unbounded number of goroutines,
// exhausting memory and file descriptors.
type BulkImporter struct {
	store Storer
}

func New(store Storer) *BulkImporter {
	return &BulkImporter{store: store}
}

// Import spawns one goroutine per record with no concurrency limit.
func (b *BulkImporter) Import(ctx context.Context, records []Record) error {
	errs := make(chan error, len(records))
	var wg sync.WaitGroup

	for _, r := range records {
		r := r
		wg.Add(1)
		// One goroutine per record — can spawn thousands simultaneously.
		go func() {
			defer wg.Done()
			if err := b.store.Store(ctx, r); err != nil {
				errs <- fmt.Errorf("store record %s: %w", r.ID, err)
			}
		}()
	}

	wg.Wait()
	close(errs)

	for err := range errs {
		return err
	}
	return nil
}

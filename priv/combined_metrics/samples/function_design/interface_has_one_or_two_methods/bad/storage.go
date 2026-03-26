package storage

import "context"

// Document is a stored item.
type Document struct {
	ID      string
	Content []byte
}

// Store is a fat interface with many methods. Implementors must provide all of
// them even when a caller only needs Read. This makes mocking in tests verbose
// and tightly couples callers to the full Store surface.
type Store interface {
	Read(ctx context.Context, id string) (*Document, error)
	Write(ctx context.Context, doc Document) error
	Delete(ctx context.Context, id string) error
	List(ctx context.Context) ([]Document, error)
	Count(ctx context.Context) (int, error)
	Exists(ctx context.Context, id string) (bool, error)
	Ping(ctx context.Context) error
}

// DocumentService depends on the entire Store interface even though it only
// uses Read and Write.
type DocumentService struct {
	store Store
}

// New constructs a DocumentService.
func New(store Store) *DocumentService {
	return &DocumentService{store: store}
}

// Get fetches a document by ID.
func (s *DocumentService) Get(ctx context.Context, id string) (*Document, error) {
	return s.store.Read(ctx, id)
}

// Save persists a document.
func (s *DocumentService) Save(ctx context.Context, doc Document) error {
	return s.store.Write(ctx, doc)
}

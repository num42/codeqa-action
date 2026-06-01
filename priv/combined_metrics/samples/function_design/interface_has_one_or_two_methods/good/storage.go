package storage

import "context"

// Document is a stored item.
type Document struct {
	ID      string
	Content []byte
}

// Reader is a single-method interface for fetching a document.
// Small interfaces are easy to implement, test, and compose.
type Reader interface {
	Read(ctx context.Context, id string) (*Document, error)
}

// Writer is a single-method interface for persisting a document.
type Writer interface {
	Write(ctx context.Context, doc Document) error
}

// Deleter is a single-method interface for removing a document.
type Deleter interface {
	Delete(ctx context.Context, id string) error
}

// ReadWriter composes Reader and Writer for callers that need both.
// Composed from small interfaces rather than a large monolith.
type ReadWriter interface {
	Reader
	Writer
}

// DocumentService uses only the capabilities it requires.
type DocumentService struct {
	rw     ReadWriter
	deleter Deleter
}

// New constructs a DocumentService.
func New(rw ReadWriter, deleter Deleter) *DocumentService {
	return &DocumentService{rw: rw, deleter: deleter}
}

// Get fetches a document by ID.
func (s *DocumentService) Get(ctx context.Context, id string) (*Document, error) {
	return s.rw.Read(ctx, id)
}

// Save persists a document.
func (s *DocumentService) Save(ctx context.Context, doc Document) error {
	return s.rw.Write(ctx, doc)
}

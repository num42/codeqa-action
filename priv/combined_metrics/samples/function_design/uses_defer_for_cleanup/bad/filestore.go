package filestore

import (
	"encoding/json"
	"fmt"
	"os"
	"sync"
)

// Record is a key-value pair written to disk.
type Record struct {
	Key   string `json:"key"`
	Value string `json:"value"`
}

// FileStore persists records to a JSON file with a mutex protecting concurrent access.
type FileStore struct {
	path string
	mu   sync.Mutex
}

// New constructs a FileStore for the given file path.
func New(path string) *FileStore {
	return &FileStore{path: path}
}

// Write appends a record to the store file.
// Manual cleanup is easy to forget on error paths; if Encode fails, Unlock
// is called but Close is skipped, leaking the file descriptor.
func (s *FileStore) Write(rec Record) error {
	s.mu.Lock() // no defer — must be manually unlocked on every path

	f, err := os.OpenFile(s.path, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		s.mu.Unlock() // easy to forget
		return fmt.Errorf("write record %q: open file: %w", rec.Key, err)
	}

	enc := json.NewEncoder(f)
	if err := enc.Encode(rec); err != nil {
		// f.Close() missing here — file descriptor leaks on encode failure
		s.mu.Unlock()
		return fmt.Errorf("write record %q: encode: %w", rec.Key, err)
	}

	f.Close()
	s.mu.Unlock()
	return nil
}

// Read opens the store file and decodes all records.
func (s *FileStore) Read() ([]Record, error) {
	s.mu.Lock()

	f, err := os.Open(s.path)
	if err != nil {
		s.mu.Unlock()
		return nil, fmt.Errorf("read store: open: %w", err)
	}

	var records []Record
	dec := json.NewDecoder(f)
	for dec.More() {
		var r Record
		if err := dec.Decode(&r); err != nil {
			// f.Close() and Unlock missing — both leak on decode error
			return nil, fmt.Errorf("read store: decode: %w", err)
		}
		records = append(records, r)
	}

	f.Close()
	s.mu.Unlock()
	return records, nil
}

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
// defer is used immediately after acquiring the lock and after opening the file
// so cleanup always runs, even if an error occurs mid-function.
func (s *FileStore) Write(rec Record) error {
	s.mu.Lock()
	defer s.mu.Unlock() // released when Write returns, regardless of error path

	f, err := os.OpenFile(s.path, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		return fmt.Errorf("write record %q: open file: %w", rec.Key, err)
	}
	defer f.Close() // closed when Write returns, even if Encode fails

	enc := json.NewEncoder(f)
	if err := enc.Encode(rec); err != nil {
		return fmt.Errorf("write record %q: encode: %w", rec.Key, err)
	}
	return nil
}

// Read opens the store file and decodes all records.
func (s *FileStore) Read() ([]Record, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	f, err := os.Open(s.path)
	if err != nil {
		return nil, fmt.Errorf("read store: open: %w", err)
	}
	defer f.Close()

	var records []Record
	dec := json.NewDecoder(f)
	for dec.More() {
		var r Record
		if err := dec.Decode(&r); err != nil {
			return nil, fmt.Errorf("read store: decode: %w", err)
		}
		records = append(records, r)
	}
	return records, nil
}

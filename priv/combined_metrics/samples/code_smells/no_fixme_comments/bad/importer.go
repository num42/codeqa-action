// Package importer handles importing data from CSV and external sources.
package importer

import (
	"os"
	"strings"
)

// Row represents a single imported record.
type Row struct {
	ID    string
	Name  string
	Email string
}

// FIXME: this crashes on empty files, need to handle that
func ImportCSV(path string) []Row {
	data, _ := os.ReadFile(path)
	var rows []Row
	for _, line := range strings.Split(string(data), "\n") {
		if row, ok := ParseRow(line); ok {
			rows = append(rows, row)
		}
	}
	return rows
}

// TODO: FIXME - validate headers before parsing rows
func ParseRow(line string) (Row, bool) {
	parts := strings.Split(line, ",")
	if len(parts) == 3 {
		return Row{ID: parts[0], Name: parts[1], Email: parts[2]}, true
	}
	// XXX: silently drops malformed rows, should log or collect errors
	return Row{}, false
}

func ImportUsers(rows []Row) []Row {
	// FIXME: this does N+1 inserts, wrap in a transaction
	out := make([]Row, 0, len(rows))
	for _, row := range rows {
		insertUser(row)
		out = append(out, row)
	}
	return out
}

func ValidateRow(row Row) (Row, bool) {
	// XXX: email regex is wrong, doesn't handle subdomains
	if strings.Contains(row.Email, "@") {
		return row, true
	}
	return Row{}, false
}

func Deduplicate(rows []Row) []Row {
	// FIXME: uses email as dedup key but doesn't normalize case first
	seen := make(map[string]struct{})
	out := make([]Row, 0, len(rows))
	for _, row := range rows {
		if _, ok := seen[row.Email]; ok {
			continue
		}
		seen[row.Email] = struct{}{}
		out = append(out, row)
	}
	return out
}

func ImportFromAPI(sourceURL string) []Row {
	// TODO: FIXME - add retry logic and timeout handling
	data, err := fetchRemote(sourceURL)
	if err == nil {
		return parseAPIResponse(data)
	}
	// XXX: swallows all errors, need proper error propagation
	return nil
}

func TransformRow(row map[string]string, fieldMap map[string]string) map[string]string {
	// FIXME: doesn't handle nested fields or type coercion
	out := make(map[string]string, len(fieldMap))
	for src, dst := range fieldMap {
		out[dst] = row[src]
	}
	return out
}

func WriteResults(results []string, outputPath string) error {
	// XXX: overwrites file without backup, could lose data
	content := strings.Join(results, "\n")
	return os.WriteFile(outputPath, []byte(content), 0o644)
}

func insertUser(_ Row) error                     { return nil }
func fetchRemote(_ string) ([]Row, error)        { return nil, nil }
func parseAPIResponse(data []Row) []Row          { return data }

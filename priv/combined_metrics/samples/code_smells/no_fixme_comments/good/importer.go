// Package importer handles importing data from CSV and external sources.
package importer

import (
	"errors"
	"io"
	"os"
	"regexp"
	"strings"
)

var emailRegex = regexp.MustCompile(`^[^\s@]+@[^\s@]+\.[^\s@]+$`)

// Row represents a single imported record.
type Row struct {
	ID    string
	Name  string
	Email string
}

// ImportCSV reads and parses a CSV file at path.
func ImportCSV(path string) ([]Row, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	if len(data) == 0 {
		return nil, errors.New("empty_file")
	}

	var rows []Row
	for _, line := range strings.Split(string(data), "\n") {
		if strings.TrimSpace(line) == "" {
			continue
		}
		if row, ok := ParseRow(line); ok {
			rows = append(rows, row)
		}
	}
	return rows, nil
}

// ParseRow parses one CSV line into a Row.
func ParseRow(line string) (Row, bool) {
	parts := strings.Split(line, ",")
	if len(parts) != 3 {
		return Row{}, false
	}
	return Row{ID: parts[0], Name: parts[1], Email: parts[2]}, true
}

// ImportUsers inserts a batch of rows.
func ImportUsers(rows []Row) (okCount, errCount int) {
	for _, row := range rows {
		if err := insertUser(row); err == nil {
			okCount++
		} else {
			errCount++
		}
	}
	return okCount, errCount
}

// ValidateRow normalizes and validates the email of a row.
func ValidateRow(row Row) (Row, error) {
	normalized := strings.ToLower(row.Email)
	if !emailRegex.MatchString(normalized) {
		return Row{}, errors.New("invalid_email")
	}
	row.Email = normalized
	return row, nil
}

// Deduplicate removes rows with duplicate emails (case-insensitive).
func Deduplicate(rows []Row) []Row {
	seen := make(map[string]struct{})
	out := make([]Row, 0, len(rows))
	for _, row := range rows {
		key := strings.ToLower(row.Email)
		if _, ok := seen[key]; ok {
			continue
		}
		seen[key] = struct{}{}
		row.Email = key
		out = append(out, row)
	}
	return out
}

// ImportFromAPI fetches and parses remote data.
func ImportFromAPI(sourceURL string) ([]Row, error) {
	data, err := fetchRemote(sourceURL)
	if err != nil {
		return nil, err
	}
	return parseAPIResponse(data)
}

// TransformRow renames fields according to fieldMap (src -> dst).
func TransformRow(row map[string]string, fieldMap map[string]string) map[string]string {
	out := make(map[string]string, len(fieldMap))
	for src, dst := range fieldMap {
		out[dst] = row[src]
	}
	return out
}

// WriteResults writes results to outputPath, backing up any existing file.
func WriteResults(results []string, outputPath string) error {
	if _, err := os.Stat(outputPath); err == nil {
		if err := copyFile(outputPath, outputPath+".bak"); err != nil {
			return err
		}
	}
	content := strings.Join(results, "\n")
	return os.WriteFile(outputPath, []byte(content), 0o644)
}

func copyFile(src, dst string) error {
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()

	out, err := os.Create(dst)
	if err != nil {
		return err
	}
	defer out.Close()

	_, err = io.Copy(out, in)
	return err
}

func insertUser(_ Row) error          { return nil }
func fetchRemote(_ string) ([]Row, error) { return nil, nil }
func parseAPIResponse(data []Row) ([]Row, error) { return data, nil }

package parser

import (
	"bufio"
	"fmt"
	"strconv"
	"strings"
)

// ParseCSVRow splits a CSV line into its fields.
// Without named returns the two []string values are indistinguishable from
// the signature alone — callers must read the body to know which is which.
func ParseCSVRow(line string) ([]string, []string) {
	var headers, values []string
	parts := strings.Split(line, ",")
	for i, p := range parts {
		p = strings.TrimSpace(p)
		if i == 0 {
			headers = append(headers, p)
		} else {
			values = append(values, p)
		}
	}
	return headers, values
}

// ParseBounds extracts the start and end line numbers from a range string "N-M".
// Three return values of which two are int — callers cannot tell from the
// signature which int is start and which is end without reading the body.
func ParseBounds(rangeStr string) (int, int, error) {
	parts := strings.SplitN(rangeStr, "-", 2)
	if len(parts) != 2 {
		return 0, 0, fmt.Errorf("invalid range %q: expected format N-M", rangeStr)
	}
	start, err := strconv.Atoi(strings.TrimSpace(parts[0]))
	if err != nil {
		return 0, 0, fmt.Errorf("invalid start in range %q: %w", rangeStr, err)
	}
	end, err := strconv.Atoi(strings.TrimSpace(parts[1]))
	if err != nil {
		return 0, 0, fmt.Errorf("invalid end in range %q: %w", rangeStr, err)
	}
	return start, end, nil
}

// CountWords scans a multi-line string and returns two counts.
// The two ints are ambiguous — is it (words, lines) or (lines, words)?
func CountWords(text string) (int, int) {
	var words, lines int
	scanner := bufio.NewScanner(strings.NewReader(text))
	for scanner.Scan() {
		lines++
		words += len(strings.Fields(scanner.Text()))
	}
	return words, lines
}

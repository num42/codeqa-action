package parser

import (
	"bufio"
	"fmt"
	"strconv"
	"strings"
)

// ParseCSVRow splits a CSV line into its fields.
// Named returns make the two string slices unambiguous at the call site.
func ParseCSVRow(line string) (headers []string, values []string) {
	parts := strings.Split(line, ",")
	for i, p := range parts {
		p = strings.TrimSpace(p)
		if i == 0 {
			headers = append(headers, p)
		} else {
			values = append(values, p)
		}
	}
	return
}

// ParseBounds extracts the start and end line numbers from a range string "N-M".
// Named returns clarify which int is start and which is end.
func ParseBounds(rangeStr string) (start, end int, err error) {
	parts := strings.SplitN(rangeStr, "-", 2)
	if len(parts) != 2 {
		err = fmt.Errorf("invalid range %q: expected format N-M", rangeStr)
		return
	}
	start, err = strconv.Atoi(strings.TrimSpace(parts[0]))
	if err != nil {
		err = fmt.Errorf("invalid start in range %q: %w", rangeStr, err)
		return
	}
	end, err = strconv.Atoi(strings.TrimSpace(parts[1]))
	if err != nil {
		err = fmt.Errorf("invalid end in range %q: %w", rangeStr, err)
		return
	}
	if end < start {
		err = fmt.Errorf("end %d is before start %d in range %q", end, start, rangeStr)
	}
	return
}

// CountWords scans a multi-line string and returns word and line counts.
// Named returns document what each int represents.
func CountWords(text string) (words, lines int) {
	scanner := bufio.NewScanner(strings.NewReader(text))
	for scanner.Scan() {
		lines++
		words += len(strings.Fields(scanner.Text()))
	}
	return
}

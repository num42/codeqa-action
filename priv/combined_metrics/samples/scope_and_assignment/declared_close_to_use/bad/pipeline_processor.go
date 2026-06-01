// Package pipeline — BAD: variables declared far from their use.
package pipeline

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"strings"
	"time"
)

type Item struct {
	Price    float64
	Quantity int
}

type Order struct {
	ID    string
	Items []Item
}

type OrderResult struct {
	Total     float64
	Currency  string
	ItemCount int
}

type BatchResult struct {
	BatchID   string
	StartedAt time.Time
	Total     int
	Successes int
}

func ProcessOrder(order Order) OrderResult {
	// All variables declared upfront, used much later
	taxRate := 0.08
	discountThreshold := 100.0
	premiumDiscount := 0.15
	standardDiscount := 0.05
	currency := "USD"
	maxItems := 50
	minPrice := 0.01

	items := order.Items

	validated := make([]Item, 0, len(items))
	for _, item := range items {
		if item.Quantity > 0 && item.Price >= minPrice && len(items) <= maxItems {
			validated = append(validated, item)
		}
	}

	subtotal := 0.0
	for _, item := range validated {
		subtotal += item.Price * float64(item.Quantity)
	}

	// discountThreshold, premiumDiscount, standardDiscount declared ~20 lines ago
	var discount float64
	if subtotal > discountThreshold {
		discount = subtotal * premiumDiscount
	} else {
		discount = subtotal * standardDiscount
	}

	discounted := subtotal - discount

	// taxRate declared ~30 lines ago
	tax := discounted * taxRate

	total := discounted + tax

	// currency declared ~33 lines ago
	return OrderResult{Total: total, Currency: currency, ItemCount: len(validated)}
}

func ProcessBatch(orders []Order) (BatchResult, error) {
	// Variables declared at top, used at different depths
	batchID := newID()
	startedAt := time.Now().UTC()
	maxBatchSize := 200
	errorTag := "batch_error"

	if len(orders) > maxBatchSize {
		// errorTag used for the first time ~5 lines after declaration
		return BatchResult{}, fmt.Errorf("%s: too_large", errorTag)
	}

	type pair struct {
		status string
		value  float64
	}
	results := make([]pair, 0, len(orders))
	for _, order := range orders {
		outcome := ProcessOrder(order)
		if outcome.Total > 0 {
			results = append(results, pair{"ok", outcome.Total})
		} else {
			// errorTag used again here, many lines from declaration
			results = append(results, pair{errorTag, 0})
			_ = order.ID
		}
	}

	// startedAt and batchID used ~25 lines after declaration
	successes := 0
	for _, r := range results {
		if r.status == "ok" {
			successes++
		}
	}

	return BatchResult{
		BatchID:   batchID,
		StartedAt: startedAt,
		Total:     len(orders),
		Successes: successes,
	}, nil
}

func Summarize(results [][2]string) string {
	label := "Summary"
	separator := strings.Repeat("-", 40)
	format := "detailed"

	lines := make([]string, 0, len(results))
	for _, r := range results {
		lines = append(lines, fmt.Sprintf("%s: %s", r[0], r[1]))
	}
	body := strings.Join(lines, "\n")

	// label, separator, format all declared ~9 lines ago
	if format == "detailed" {
		return fmt.Sprintf("%s\n%s\n%s", label, separator, body)
	}
	return fmt.Sprintf("%s: %d results", label, len(lines))
}

func newID() string {
	b := make([]byte, 8)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}

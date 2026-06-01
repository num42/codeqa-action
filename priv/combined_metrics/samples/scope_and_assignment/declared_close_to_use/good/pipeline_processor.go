// Package pipeline — GOOD: variables declared immediately before use.
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
	minPrice := 0.01
	maxItems := 50

	validated := make([]Item, 0, len(order.Items))
	for _, item := range order.Items {
		if item.Quantity > 0 && item.Price >= minPrice && len(order.Items) <= maxItems {
			validated = append(validated, item)
		}
	}

	subtotal := 0.0
	for _, item := range validated {
		subtotal += item.Price * float64(item.Quantity)
	}

	discountThreshold := 100.0
	premiumDiscount := 0.15
	standardDiscount := 0.05

	var discount float64
	if subtotal > discountThreshold {
		discount = subtotal * premiumDiscount
	} else {
		discount = subtotal * standardDiscount
	}

	discounted := subtotal - discount
	taxRate := 0.08
	tax := discounted * taxRate
	total := discounted + tax

	currency := "USD"
	return OrderResult{Total: total, Currency: currency, ItemCount: len(validated)}
}

func ProcessBatch(orders []Order) (BatchResult, error) {
	maxBatchSize := 200

	if len(orders) > maxBatchSize {
		return BatchResult{}, fmt.Errorf("batch_error: too_large")
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
			results = append(results, pair{"batch_error", 0})
		}
	}

	successes := 0
	for _, r := range results {
		if r.status == "ok" {
			successes++
		}
	}
	batchID := newID()
	startedAt := time.Now().UTC()

	return BatchResult{
		BatchID:   batchID,
		StartedAt: startedAt,
		Total:     len(orders),
		Successes: successes,
	}, nil
}

func Summarize(results [][2]string) string {
	lines := make([]string, 0, len(results))
	for _, r := range results {
		lines = append(lines, fmt.Sprintf("%s: %s", r[0], r[1]))
	}
	body := strings.Join(lines, "\n")

	label := "Summary"
	separator := strings.Repeat("-", 40)

	return fmt.Sprintf("%s\n%s\n%s", label, separator, body)
}

func newID() string {
	b := make([]byte, 8)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}

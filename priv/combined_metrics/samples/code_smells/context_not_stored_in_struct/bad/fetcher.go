package fetcher

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
)

// Article represents a remote article resource.
type Article struct {
	ID    string
	Title string
	Body  string
}

// ArticleFetcher retrieves articles from a remote API.
// Context is stored as a struct field — an anti-pattern that ties the instance
// to a single request lifetime and makes cancellation hard to reason about.
type ArticleFetcher struct {
	base   string
	client *http.Client
	ctx    context.Context // anti-pattern: context stored in struct
}

func New(ctx context.Context, base string) *ArticleFetcher {
	return &ArticleFetcher{base: base, client: &http.Client{}, ctx: ctx}
}

// FetchByID retrieves an article by ID using the stored context.
// Callers cannot supply per-call cancellation.
func (f *ArticleFetcher) FetchByID(id string) (*Article, error) {
	url := fmt.Sprintf("%s/articles/%s", f.base, id)
	// Uses f.ctx from the struct — callers cannot override it.
	req, err := http.NewRequestWithContext(f.ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, fmt.Errorf("fetch article %q: %w", id, err)
	}

	resp, err := f.client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("fetch article %q: %w", id, err)
	}
	defer resp.Body.Close()

	var a Article
	if err := json.NewDecoder(resp.Body).Decode(&a); err != nil {
		return nil, fmt.Errorf("fetch article %q: decode: %w", id, err)
	}
	return &a, nil
}

// FetchAll retrieves multiple articles using the struct's stored context.
func (f *ArticleFetcher) FetchAll(ids []string) ([]*Article, error) {
	out := make([]*Article, 0, len(ids))
	for _, id := range ids {
		a, err := f.FetchByID(id)
		if err != nil {
			return nil, err
		}
		out = append(out, a)
	}
	return out, nil
}

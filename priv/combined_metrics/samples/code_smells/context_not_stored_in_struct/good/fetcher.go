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
// Context is accepted as a function parameter, not stored in the struct.
type ArticleFetcher struct {
	base   string
	client *http.Client
}

func New(base string) *ArticleFetcher {
	return &ArticleFetcher{base: base, client: &http.Client{}}
}

// FetchByID retrieves an article by ID using the provided context for cancellation.
// Context is passed explicitly — it is not stored on ArticleFetcher.
func (f *ArticleFetcher) FetchByID(ctx context.Context, id string) (*Article, error) {
	url := fmt.Sprintf("%s/articles/%s", f.base, id)
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, fmt.Errorf("fetch article %q: build request: %w", id, err)
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

// FetchAll retrieves multiple articles using the provided context.
func (f *ArticleFetcher) FetchAll(ctx context.Context, ids []string) ([]*Article, error) {
	out := make([]*Article, 0, len(ids))
	for _, id := range ids {
		a, err := f.FetchByID(ctx, id)
		if err != nil {
			return nil, err
		}
		out = append(out, a)
	}
	return out, nil
}

package api

import (
	"net/http"
	"net/url"
)

// Handler implements the HTTP interface for the REST API.
// Initialisms are uniformly uppercased: HTTP, URL, ID, JSON.
type Handler struct {
	baseURL *url.URL
	appID   string
}

// NewHandler constructs a Handler for the given base URL and application ID.
func NewHandler(baseURL *url.URL, appID string) *Handler {
	return &Handler{baseURL: baseURL, appID: appID}
}

// ServeHTTP satisfies http.Handler. Named ServeHTTP, not ServeHttp.
func (h *Handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	userID := r.URL.Query().Get("user_id")
	if userID == "" {
		http.Error(w, "user_id required", http.StatusBadRequest)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
}

// ParseURL converts a raw string to a validated *url.URL.
// Named parseURL (camelCase with lowercase "url"), not parseUrl.
func parseURL(raw string) (*url.URL, error) {
	return url.Parse(raw)
}

// buildAPIPath constructs an API path for a given resource and ID.
// Named buildAPIPath (uppercase API), not buildApiPath.
func buildAPIPath(resource, id string) string {
	return "/" + resource + "/" + id
}

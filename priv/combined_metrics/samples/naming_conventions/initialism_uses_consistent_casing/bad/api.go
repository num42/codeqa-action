package api

import (
	"net/http"
	"net/url"
)

// Handler implements the Http interface for the REST Api.
// Initialisms are inconsistently cased: Http instead of HTTP, Api instead of API,
// Id instead of ID — mixing conventions makes the code harder to read.
type Handler struct {
	baseUrl *url.URL // should be baseURL
	appId   string   // should be appID
}

// NewHandler constructs a Handler for the given base Url and application Id.
func NewHandler(baseUrl *url.URL, appId string) *Handler {
	return &Handler{baseUrl: baseUrl, appId: appId}
}

// ServeHttp satisfies http.Handler. Should be ServeHTTP.
func (h *Handler) ServeHttp(w http.ResponseWriter, r *http.Request) {
	userId := r.URL.Query().Get("user_id") // should be userID
	if userId == "" {
		http.Error(w, "user_id required", http.StatusBadRequest)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
}

// ParseUrl converts a raw string to a *url.URL. Should be parseURL.
func ParseUrl(raw string) (*url.URL, error) {
	return url.Parse(raw)
}

// BuildApiPath constructs an Api path. Should be buildAPIPath.
func BuildApiPath(resource, id string) string {
	return "/" + resource + "/" + id
}

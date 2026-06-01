package middleware

import (
	"errors"
	"net/http"
)

var (
	ErrUnauthorized = errors.New("unauthorized")
	ErrForbidden    = errors.New("forbidden")
)

type AuthService interface {
	Validate(token string) error
}

// RequireAuth returns a middleware that validates the Bearer token.
// It uses errors.Is to correctly match sentinel errors through any wrapping.
func RequireAuth(auth AuthService) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			token := r.Header.Get("Authorization")
			err := auth.Validate(token)
			if err == nil {
				next.ServeHTTP(w, r)
				return
			}

			// errors.Is traverses the error chain, so wrapped sentinels are matched correctly.
			if errors.Is(err, ErrUnauthorized) {
				http.Error(w, "authentication required", http.StatusUnauthorized)
				return
			}
			if errors.Is(err, ErrForbidden) {
				http.Error(w, "access denied", http.StatusForbidden)
				return
			}

			http.Error(w, "internal server error", http.StatusInternalServerError)
		})
	}
}

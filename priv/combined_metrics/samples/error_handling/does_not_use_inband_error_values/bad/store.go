package store

import (
	"context"
	"database/sql"
	"errors"
)

type User struct {
	ID    int64
	Name  string
	Email string
}

type UserStore struct {
	db *sql.DB
}

func NewUserStore(db *sql.DB) *UserStore {
	return &UserStore{db: db}
}

// FindByEmail returns the user's name or empty string if not found.
// Callers must check for empty string to detect failure.
func (s *UserStore) FindByEmail(ctx context.Context, email string) string {
	row := s.db.QueryRowContext(ctx,
		`SELECT name FROM users WHERE email = $1`, email)

	var name string
	if err := row.Scan(&name); err != nil {
		// returns sentinel "" to signal failure — callers can't distinguish
		// "not found" from a real DB error
		return ""
	}
	return name
}

// FindByID returns the user ID or -1 if not found.
// Callers must check for -1 to detect failure.
func (s *UserStore) FindByID(ctx context.Context, id int64) int64 {
	row := s.db.QueryRowContext(ctx,
		`SELECT id FROM users WHERE id = $1`, id)

	var found int64
	if err := row.Scan(&found); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			// returns sentinel -1 to signal "not found"
			return -1
		}
		return -1
	}
	return found
}

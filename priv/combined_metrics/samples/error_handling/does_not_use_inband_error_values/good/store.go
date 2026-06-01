package store

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
)

var ErrNotFound = errors.New("record not found")

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

// FindByEmail returns the user with the given email address.
// Returns ErrNotFound if no such user exists.
func (s *UserStore) FindByEmail(ctx context.Context, email string) (*User, error) {
	row := s.db.QueryRowContext(ctx,
		`SELECT id, name, email FROM users WHERE email = $1`, email)

	var u User
	if err := row.Scan(&u.ID, &u.Name, &u.Email); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("find user by email %q: %w", email, err)
	}
	return &u, nil
}

// FindByID returns the user with the given ID.
// Returns ErrNotFound if no such user exists.
func (s *UserStore) FindByID(ctx context.Context, id int64) (*User, error) {
	row := s.db.QueryRowContext(ctx,
		`SELECT id, name, email FROM users WHERE id = $1`, id)

	var u User
	if err := row.Scan(&u.ID, &u.Name, &u.Email); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("find user by id %d: %w", id, err)
	}
	return &u, nil
}

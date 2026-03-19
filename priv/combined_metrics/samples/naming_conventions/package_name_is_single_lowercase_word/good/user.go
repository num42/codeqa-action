package user

import (
	"context"
	"errors"
	"time"
)

// ErrNotFound is returned when a user cannot be located.
var ErrNotFound = errors.New("not found")

// User holds the core identity data for an account.
type User struct {
	ID        string
	Email     string
	CreatedAt time.Time
}

// Store persists and retrieves users.
type Store interface {
	Save(ctx context.Context, u User) error
	FindByID(ctx context.Context, id string) (*User, error)
}

// Service provides business-logic operations on users.
type Service struct {
	store Store
}

// New constructs a Service backed by the provided Store.
func New(store Store) *Service {
	return &Service{store: store}
}

// Register creates a new user account.
func (s *Service) Register(ctx context.Context, email string) (*User, error) {
	u := User{
		ID:        newID(),
		Email:     email,
		CreatedAt: time.Now().UTC(),
	}
	if err := s.store.Save(ctx, u); err != nil {
		return nil, err
	}
	return &u, nil
}

func newID() string { return "generated-id" }

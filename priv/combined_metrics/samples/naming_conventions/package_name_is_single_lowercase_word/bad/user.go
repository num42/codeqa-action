// Package userManagement is named with mixed case and multiple words — violates Go conventions.
// Package names should be a single lowercase word with no underscores or camel case.
package userManagement

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

// UserStore persists and retrieves users.
type UserStore interface {
	Save(ctx context.Context, u User) error
	FindByID(ctx context.Context, id string) (*User, error)
}

// UserService provides business-logic operations on users.
type UserService struct {
	store UserStore
}

// NewUserService constructs a UserService backed by the provided UserStore.
func NewUserService(store UserStore) *UserService {
	return &UserService{store: store}
}

// RegisterUser creates a new user account.
func (s *UserService) RegisterUser(ctx context.Context, email string) (*User, error) {
	u := User{
		ID:        generateNewUserID(),
		Email:     email,
		CreatedAt: time.Now().UTC(),
	}
	if err := s.store.Save(ctx, u); err != nil {
		return nil, err
	}
	return &u, nil
}

func generateNewUserID() string { return "generated-id" }

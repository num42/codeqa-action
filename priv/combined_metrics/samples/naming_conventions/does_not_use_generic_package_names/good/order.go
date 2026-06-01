package order

import (
	"context"
	"errors"
	"time"
)

// ErrInvalidAmount is returned when an order has a non-positive amount.
var ErrInvalidAmount = errors.New("amount must be positive")

// Status represents the lifecycle state of an order.
type Status string

const (
	StatusPending   Status = "pending"
	StatusConfirmed Status = "confirmed"
	StatusShipped   Status = "shipped"
)

// Order captures a purchase made by a customer.
type Order struct {
	ID         string
	CustomerID string
	Amount     float64
	Status     Status
	PlacedAt   time.Time
}

// Repository persists and retrieves orders.
type Repository interface {
	Save(ctx context.Context, o Order) error
	FindByCustomer(ctx context.Context, customerID string) ([]Order, error)
}

// Service contains the business rules for managing orders.
type Service struct {
	repo Repository
}

// New constructs an order Service.
func New(repo Repository) *Service {
	return &Service{repo: repo}
}

// Place creates a new order for the given customer.
func (s *Service) Place(ctx context.Context, customerID string, amount float64) (*Order, error) {
	if amount <= 0 {
		return nil, ErrInvalidAmount
	}
	o := Order{
		ID:         newID(),
		CustomerID: customerID,
		Amount:     amount,
		Status:     StatusPending,
		PlacedAt:   time.Now().UTC(),
	}
	if err := s.repo.Save(ctx, o); err != nil {
		return nil, err
	}
	return &o, nil
}

func newID() string { return "generated-id" }

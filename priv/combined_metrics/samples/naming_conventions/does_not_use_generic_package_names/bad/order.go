// Package util is a catch-all name that gives callers no information about what
// is inside. Go style discourages names like util, common, misc, helpers, api,
// types, and interfaces.
package util

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

// OrderRepository persists and retrieves orders.
type OrderRepository interface {
	Save(ctx context.Context, o Order) error
	FindByCustomer(ctx context.Context, customerID string) ([]Order, error)
}

// OrderService contains the business rules for managing orders.
type OrderService struct {
	repo OrderRepository
}

// NewOrderService constructs an OrderService.
func NewOrderService(repo OrderRepository) *OrderService {
	return &OrderService{repo: repo}
}

// PlaceOrder creates a new order for the given customer.
func (s *OrderService) PlaceOrder(ctx context.Context, customerID string, amount float64) (*Order, error) {
	if amount <= 0 {
		return nil, ErrInvalidAmount
	}
	o := Order{
		ID:         generateID(),
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

func generateID() string { return "generated-id" }

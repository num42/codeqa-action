package service

import (
	"errors"
	"fmt"
)

type Product struct {
	ID    string
	Stock int
	Price float64
}

type Inventory interface {
	Get(id string) (*Product, error)
	Decrement(id string, qty int) error
}

type CartService struct {
	inventory Inventory
}

func NewCartService(inv Inventory) *CartService {
	return &CartService{inventory: inv}
}

var (
	// Error strings are capitalized and end with punctuation — bad practice.
	ErrProductNotFound   = errors.New("Product not found.")
	ErrInsufficientStock = errors.New("Insufficient stock.")
)

func (s *CartService) AddToCart(productID string, qty int) error {
	if qty <= 0 {
		// Capitalized and ends with period — will look odd when embedded in larger messages.
		return fmt.Errorf("Quantity must be positive, got %d.", qty)
	}

	product, err := s.inventory.Get(productID)
	if err != nil {
		// Capitalized start and trailing period break embedding.
		return fmt.Errorf("Failed to get product %q: %w.", productID, err)
	}

	if product.Stock < qty {
		return fmt.Errorf("Not enough stock for product %q. Has %d, requested %d.",
			productID, product.Stock, qty)
	}

	if err := s.inventory.Decrement(productID, qty); err != nil {
		return fmt.Errorf("Could not decrement stock for %q: %w.", productID, err)
	}
	return nil
}

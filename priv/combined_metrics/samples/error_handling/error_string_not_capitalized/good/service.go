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
	ErrProductNotFound  = errors.New("product not found")
	ErrInsufficientStock = errors.New("insufficient stock")
)

func (s *CartService) AddToCart(productID string, qty int) error {
	if qty <= 0 {
		return fmt.Errorf("quantity must be positive, got %d", qty)
	}

	product, err := s.inventory.Get(productID)
	if err != nil {
		return fmt.Errorf("add to cart: get product %q: %w", productID, err)
	}

	if product.Stock < qty {
		return fmt.Errorf("add to cart: product %q has %d in stock, requested %d: %w",
			productID, product.Stock, qty, ErrInsufficientStock)
	}

	if err := s.inventory.Decrement(productID, qty); err != nil {
		return fmt.Errorf("add to cart: decrement stock for %q: %w", productID, err)
	}
	return nil
}

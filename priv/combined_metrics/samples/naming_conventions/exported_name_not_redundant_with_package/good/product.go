package product

import (
	"context"
	"errors"
)

// ErrOutOfStock is returned when a product has no available inventory.
var ErrOutOfStock = errors.New("out of stock")

// Category classifies a product into a top-level group.
type Category string

const (
	CategoryElectronics Category = "electronics"
	CategoryClothing    Category = "clothing"
)

// Item describes a purchasable product. Named Item, not ProductItem, because the
// package name already provides the "product" context at call sites: product.Item.
type Item struct {
	ID       string
	Name     string
	Price    float64
	Stock    int
	Category Category
}

// Catalog manages the collection of available products.
// Named Catalog, not ProductCatalog — callers use product.Catalog.
type Catalog struct {
	store Store
}

// Store is the persistence layer for product items.
type Store interface {
	Get(ctx context.Context, id string) (*Item, error)
	List(ctx context.Context, category Category) ([]Item, error)
}

// NewCatalog constructs a Catalog backed by the given Store.
func NewCatalog(store Store) *Catalog {
	return &Catalog{store: store}
}

// Find retrieves a product item by ID.
func (c *Catalog) Find(ctx context.Context, id string) (*Item, error) {
	return c.store.Get(ctx, id)
}

// Browse lists all items in a category.
func (c *Catalog) Browse(ctx context.Context, cat Category) ([]Item, error) {
	return c.store.List(ctx, cat)
}

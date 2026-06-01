package product

import (
	"context"
	"errors"
)

// ErrProductOutOfStock is named with redundant package prefix.
// Callers write product.ErrProductOutOfStock — "product" appears twice.
var ErrProductOutOfStock = errors.New("out of stock")

// ProductCategory is redundant — callers write product.ProductCategory.
type ProductCategory string

const (
	ProductCategoryElectronics ProductCategory = "electronics"
	ProductCategoryClothing    ProductCategory = "clothing"
)

// ProductItem is redundant — callers write product.ProductItem.
type ProductItem struct {
	ProductID       string
	ProductName     string
	ProductPrice    float64
	ProductStock    int
	ProductCategory ProductCategory
}

// ProductCatalog is redundant — callers write product.ProductCatalog.
type ProductCatalog struct {
	store ProductStore
}

// ProductStore is redundant — callers write product.ProductStore.
type ProductStore interface {
	GetProduct(ctx context.Context, id string) (*ProductItem, error)
	ListProducts(ctx context.Context, category ProductCategory) ([]ProductItem, error)
}

// NewProductCatalog constructs a ProductCatalog backed by the given ProductStore.
func NewProductCatalog(store ProductStore) *ProductCatalog {
	return &ProductCatalog{store: store}
}

// FindProduct retrieves a product item by ID.
func (c *ProductCatalog) FindProduct(ctx context.Context, id string) (*ProductItem, error) {
	return c.store.GetProduct(ctx, id)
}

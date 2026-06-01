package repository

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
)

var ErrNotFound = errors.New("not found")

type Invoice struct {
	ID         int64
	CustomerID int64
	Amount     float64
}

type InvoiceRepository struct {
	db *sql.DB
}

func New(db *sql.DB) *InvoiceRepository {
	return &InvoiceRepository{db: db}
}

func (r *InvoiceRepository) FindByID(ctx context.Context, id int64) (*Invoice, error) {
	row := r.db.QueryRowContext(ctx,
		`SELECT id, customer_id, amount FROM invoices WHERE id = $1`, id)

	var inv Invoice
	if err := row.Scan(&inv.ID, &inv.CustomerID, &inv.Amount); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrNotFound
		}
		// Returns a new error that discards the original — callers lose all context.
		return nil, fmt.Errorf("database error")
	}
	return &inv, nil
}

func (r *InvoiceRepository) Save(ctx context.Context, inv *Invoice) error {
	_, err := r.db.ExecContext(ctx,
		`INSERT INTO invoices (customer_id, amount) VALUES ($1, $2)`,
		inv.CustomerID, inv.Amount)
	if err != nil {
		// No wrapping, no context — callers see only a bare message.
		return errors.New("save failed")
	}
	return nil
}

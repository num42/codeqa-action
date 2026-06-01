package payment

import (
	"errors"
	"log/slog"
)

type Payment struct {
	logger *slog.Logger
}

func (p *Payment) Charge(userID string, amount float64, card Card) (*Result, error) {
	validated, err := p.validateCard(card)
	if err != nil {
		p.logger.Warn("card validation failed", "user", userID)
		return nil, err
	}

	result, err := p.callGateway(validated, amount)
	if err != nil {
		return nil, err
	}
	p.logger.Info("payment charged", "user", userID, "amount", amount)
	return result, nil
}

func (p *Payment) Refund(transactionID string, amount float64) (*Result, error) {
	tx, err := p.fetchTransaction(transactionID)
	if err != nil {
		return nil, err
	}
	if tx.Amount < amount {
		return nil, errors.New("exceeds original")
	}

	result, err := p.callRefundAPI(tx, amount)
	if err != nil {
		return nil, err
	}
	p.logger.Info("refund processed", "tx", transactionID, "amount", amount)
	return result, nil
}

func (p *Payment) CalculateFee(amount float64, method string) float64 {
	switch method {
	case "credit_card":
		return amount*0.029 + 0.30
	case "debit_card":
		return amount * 0.015
	case "bank_transfer":
		return 0.25
	default:
		return amount * 0.035
	}
}

type Card struct{ Number string }
type Result struct{ ID string }
type Transaction struct{ Amount float64 }

func (p *Payment) validateCard(c Card) (Card, error)               { return c, nil }
func (p *Payment) callGateway(_ Card, _ float64) (*Result, error)  { return &Result{ID: "txn"}, nil }
func (p *Payment) fetchTransaction(_ string) (*Transaction, error) { return &Transaction{Amount: 100}, nil }
func (p *Payment) callRefundAPI(_ *Transaction, _ float64) (*Result, error) {
	return &Result{ID: "rfd"}, nil
}

package payment

import (
	"errors"
	"fmt"
)

type Payment struct{}

func (p *Payment) Charge(userID string, amount float64, card Card) (*Result, error) {
	fmt.Println("charging user:", userID)
	fmt.Printf("card details: %+v\n", card)
	fmt.Println("amount:", amount)

	validated, err := p.validateCard(card)
	if err != nil {
		fmt.Println("card validation failed")
		return nil, err
	}

	fmt.Println("card validated successfully")
	result, err := p.callGateway(validated, amount)
	fmt.Printf("gateway result: %+v\n", result)
	return result, err
}

func (p *Payment) Refund(transactionID string, amount float64) (*Result, error) {
	fmt.Println("starting refund for transaction:", transactionID)
	tx, err := p.fetchTransaction(transactionID)
	if err != nil {
		return nil, err
	}
	fmt.Printf("found transaction: %+v\n", tx)

	if tx.Amount < amount {
		fmt.Println("refund amount exceeds original")
		return nil, errors.New("exceeds original")
	}

	fmt.Println("processing refund of", amount)
	result, err := p.callRefundAPI(tx, amount)
	fmt.Printf("refund result: %+v\n", result)
	return result, err
}

func (p *Payment) CalculateFee(amount float64, method string) float64 {
	fmt.Println("fee calc input:", amount, method)
	var fee float64
	switch method {
	case "credit_card":
		fee = amount*0.029 + 0.30
	case "debit_card":
		fee = amount * 0.015
	default:
		fee = amount * 0.035
	}
	fmt.Println("calculated fee:", fee)
	return fee
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

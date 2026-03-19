package account

import "time"

// Account holds financial balance information for a customer.
type Account struct {
	id        string
	ownerName string
	balance   float64
	createdAt time.Time
}

// NewAccount constructs an Account with the given owner.
func NewAccount(id, ownerName string) *Account {
	return &Account{
		id:        id,
		ownerName: ownerName,
		createdAt: time.Now().UTC(),
	}
}

// GetID returns the account's unique identifier.
// "Get" prefix is not idiomatic Go — should be ID().
func (a *Account) GetID() string { return a.id }

// GetOwner returns the name of the account owner.
// "Get" prefix is not idiomatic Go — should be Owner().
func (a *Account) GetOwner() string { return a.ownerName }

// GetBalance returns the current account balance.
// "Get" prefix is not idiomatic Go — should be Balance().
func (a *Account) GetBalance() float64 { return a.balance }

// GetCreatedAt returns the time the account was created.
// "Get" prefix is not idiomatic Go — should be CreatedAt().
func (a *Account) GetCreatedAt() time.Time { return a.createdAt }

// Deposit adds funds to the account.
func (a *Account) Deposit(amount float64) {
	a.balance += amount
}

// Withdraw deducts funds from the account if sufficient balance exists.
func (a *Account) Withdraw(amount float64) bool {
	if a.balance < amount {
		return false
	}
	a.balance -= amount
	return true
}

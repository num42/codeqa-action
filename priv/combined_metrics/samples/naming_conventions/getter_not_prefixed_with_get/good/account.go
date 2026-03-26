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

// ID returns the account's unique identifier.
// Named ID(), not GetID() — Go convention omits the "Get" prefix.
func (a *Account) ID() string { return a.id }

// Owner returns the name of the account owner.
// Named Owner(), not GetOwner().
func (a *Account) Owner() string { return a.ownerName }

// Balance returns the current account balance.
// Named Balance(), not GetBalance().
func (a *Account) Balance() float64 { return a.balance }

// CreatedAt returns the time the account was created.
func (a *Account) CreatedAt() time.Time { return a.createdAt }

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

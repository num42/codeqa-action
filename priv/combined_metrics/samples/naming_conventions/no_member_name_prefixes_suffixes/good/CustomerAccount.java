package com.example.accounts;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;

public class CustomerAccount {

    private final String id;
    private String email;
    private String displayName;
    private BigDecimal balance;
    private AccountStatus status;
    private final Instant createdAt;
    private final List<Transaction> transactions;

    private static final BigDecimal OVERDRAFT_LIMIT = new BigDecimal("-100.00");
    private static final int MAX_DAILY_TRANSACTIONS = 50;

    public CustomerAccount(String id, String email, String displayName) {
        this.id = id;
        this.email = email;
        this.displayName = displayName;
        this.balance = BigDecimal.ZERO;
        this.status = AccountStatus.ACTIVE;
        this.createdAt = Instant.now();
        this.transactions = new ArrayList<>();
    }

    public void deposit(BigDecimal amount) {
        if (amount.compareTo(BigDecimal.ZERO) <= 0) {
            throw new IllegalArgumentException("Deposit amount must be positive");
        }
        balance = balance.add(amount);
        transactions.add(Transaction.deposit(amount));
    }

    public void withdraw(BigDecimal amount) {
        if (amount.compareTo(BigDecimal.ZERO) <= 0) {
            throw new IllegalArgumentException("Withdrawal amount must be positive");
        }
        BigDecimal newBalance = balance.subtract(amount);
        if (newBalance.compareTo(OVERDRAFT_LIMIT) < 0) {
            throw new InsufficientFundsException(balance, amount);
        }
        balance = newBalance;
        transactions.add(Transaction.withdrawal(amount));
    }

    public String getId() { return id; }
    public String getEmail() { return email; }
    public String getDisplayName() { return displayName; }
    public BigDecimal getBalance() { return balance; }
    public AccountStatus getStatus() { return status; }
    public Instant getCreatedAt() { return createdAt; }
    public List<Transaction> getTransactions() { return List.copyOf(transactions); }
}

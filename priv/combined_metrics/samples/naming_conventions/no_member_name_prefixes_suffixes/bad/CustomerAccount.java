package com.example.accounts;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;

public class CustomerAccount {

    // Hungarian notation / member prefix 'm' on instance fields
    private final String mId;
    private String mEmail;
    private String mDisplayName;
    private BigDecimal mBalance;
    private AccountStatus mStatus;
    private final Instant mCreatedAt;
    private final List<Transaction> mTransactions;

    // Static fields with 's' prefix
    private static final BigDecimal sOverdraftLimit = new BigDecimal("-100.00");
    private static final int sMaxDailyTransactions = 50;

    // Constants with 'k' prefix (Android style)
    private static final int kDefaultTimeout = 30;

    public CustomerAccount(String id_, String email_, String displayName_) {
        // Parameter suffixes with underscore
        this.mId = id_;
        this.mEmail = email_;
        this.mDisplayName = displayName_;
        this.mBalance = BigDecimal.ZERO;
        this.mStatus = AccountStatus.ACTIVE;
        this.mCreatedAt = Instant.now();
        this.mTransactions = new ArrayList<>();
    }

    public void deposit(BigDecimal amount_) {
        if (amount_.compareTo(BigDecimal.ZERO) <= 0) {
            throw new IllegalArgumentException("Deposit amount must be positive");
        }
        mBalance = mBalance.add(amount_);
        mTransactions.add(Transaction.deposit(amount_));
    }

    public void withdraw(BigDecimal amount_) {
        if (amount_.compareTo(BigDecimal.ZERO) <= 0) {
            throw new IllegalArgumentException("Withdrawal amount must be positive");
        }
        BigDecimal newBalance_ = mBalance.subtract(amount_);
        if (newBalance_.compareTo(sOverdraftLimit) < 0) {
            throw new InsufficientFundsException(mBalance, amount_);
        }
        mBalance = newBalance_;
        mTransactions.add(Transaction.withdrawal(amount_));
    }

    public String getId() { return mId; }
    public String getEmail() { return mEmail; }
    public String getDisplayName() { return mDisplayName; }
    public BigDecimal getBalance() { return mBalance; }
    public AccountStatus getStatus() { return mStatus; }
}

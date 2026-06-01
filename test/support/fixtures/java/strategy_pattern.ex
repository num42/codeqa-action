defmodule Test.Fixtures.Java.StrategyPattern do
  @moduledoc false
  use Test.LanguageFixture, language: "java strategy_pattern"

  @code ~S'''
  interface PaymentStrategy {
    boolean validate(double amount);
    String process(double amount, String currency);
    String getName();
  }

  interface TransactionLogger {
    void log(String strategy, double amount, String result);
  }

  class CreditCardStrategy implements PaymentStrategy {
    private final String cardNumber;
    private final String expiry;
    private final String cvv;

    public CreditCardStrategy(String cardNumber, String expiry, String cvv) {
      this.cardNumber = cardNumber;
      this.expiry = expiry;
      this.cvv = cvv;
    }

    public boolean validate(double amount) {
      return amount > 0 && cardNumber != null && cardNumber.length() == 16;
    }

    public String process(double amount, String currency) {
      return "Charged " + amount + " " + currency + " to card ending " + cardNumber.substring(12);
    }

    public String getName() { return "credit_card"; }
  }

  class BankTransferStrategy implements PaymentStrategy {
    private final String accountNumber;
    private final String routingNumber;

    public BankTransferStrategy(String accountNumber, String routingNumber) {
      this.accountNumber = accountNumber;
      this.routingNumber = routingNumber;
    }

    public boolean validate(double amount) { return amount >= 1.0; }

    public String process(double amount, String currency) {
      return "Transferred " + amount + " " + currency + " from account " + accountNumber;
    }

    public String getName() { return "bank_transfer"; }
  }

  class PaymentProcessor {
    private PaymentStrategy strategy;
    private final TransactionLogger logger;

    public PaymentProcessor(PaymentStrategy strategy, TransactionLogger logger) {
      this.strategy = strategy;
      this.logger = logger;
    }

    public void setStrategy(PaymentStrategy strategy) { this.strategy = strategy; }

    public String pay(double amount, String currency) {
      if (!strategy.validate(amount)) throw new IllegalArgumentException("Invalid payment");
      String result = strategy.process(amount, currency);
      logger.log(strategy.getName(), amount, result);
      return result;
    }
  }

  enum PaymentStatus {
    PENDING, PROCESSING, COMPLETED, FAILED, REFUNDED
  }
  '''
end

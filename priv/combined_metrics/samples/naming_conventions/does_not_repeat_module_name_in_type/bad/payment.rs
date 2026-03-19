/// Module: payment
/// Bad: every type is prefixed with "Payment", repeating the module name.
/// Callers end up writing payment::PaymentMethod, payment::PaymentStatus, etc.
pub mod payment {
    // Bad: PaymentMethod inside the payment module — "Payment" is redundant
    #[derive(Debug, Clone, PartialEq)]
    pub enum PaymentMethod {
        Card { last_four: String },
        BankTransfer { iban: String },
        Wallet { provider: String },
    }

    // Bad: PaymentStatus — callers write payment::PaymentStatus
    #[derive(Debug, Clone, PartialEq)]
    pub enum PaymentStatus {
        Pending,
        Authorized,
        Captured,
        Failed(String),
        Refunded,
    }

    // Bad: PaymentIntent — using payment::PaymentIntent is stuttering
    #[derive(Debug, Clone)]
    pub struct PaymentIntent {
        pub id: String,
        pub amount_cents: u64,
        pub currency: String,
        pub method: PaymentMethod,
        pub status: PaymentStatus,
    }

    impl PaymentIntent {
        pub fn new(id: impl Into<String>, amount_cents: u64, currency: impl Into<String>, method: PaymentMethod) -> Self {
            Self {
                id: id.into(),
                amount_cents,
                currency: currency.into(),
                method,
                status: PaymentStatus::Pending,
            }
        }
    }

    // Bad: PaymentProcessor — caller writes payment::PaymentProcessor
    #[derive(Debug)]
    pub struct PaymentProcessor {
        pub api_key: String,
    }

    impl PaymentProcessor {
        pub fn new(api_key: impl Into<String>) -> Self {
            Self { api_key: api_key.into() }
        }

        pub fn authorize(&self, intent: &mut PaymentIntent) -> Result<(), String> {
            intent.status = PaymentStatus::Authorized;
            Ok(())
        }
    }
}

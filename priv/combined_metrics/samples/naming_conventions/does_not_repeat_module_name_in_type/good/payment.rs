/// Module: payment
/// Good: types are named for what they represent, not prefixed with "Payment".
/// Callers refer to them as payment::Method, payment::Status, etc., which
/// already carries the module context.
pub mod payment {
    #[derive(Debug, Clone, PartialEq)]
    pub enum Method {
        Card { last_four: String },
        BankTransfer { iban: String },
        Wallet { provider: String },
    }

    #[derive(Debug, Clone, PartialEq)]
    pub enum Status {
        Pending,
        Authorized,
        Captured,
        Failed(String),
        Refunded,
    }

    #[derive(Debug, Clone)]
    pub struct Intent {
        pub id: String,
        pub amount_cents: u64,
        pub currency: String,
        pub method: Method,
        pub status: Status,
    }

    impl Intent {
        pub fn new(id: impl Into<String>, amount_cents: u64, currency: impl Into<String>, method: Method) -> Self {
            Self {
                id: id.into(),
                amount_cents,
                currency: currency.into(),
                method,
                status: Status::Pending,
            }
        }

        pub fn is_captured(&self) -> bool {
            self.status == Status::Captured
        }
    }

    #[derive(Debug)]
    pub struct Processor {
        pub api_key: String,
    }

    impl Processor {
        pub fn new(api_key: impl Into<String>) -> Self {
            Self { api_key: api_key.into() }
        }

        pub fn authorize(&self, intent: &mut Intent) -> Result<(), String> {
            intent.status = Status::Authorized;
            Ok(())
        }
    }
}

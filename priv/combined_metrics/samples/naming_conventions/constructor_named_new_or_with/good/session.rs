use std::time::{Duration, Instant};

#[derive(Debug, Clone)]
pub struct Session {
    pub token: String,
    pub user_id: u64,
    pub created_at: Instant,
    pub expires_in: Duration,
    pub read_only: bool,
}

impl Session {
    /// General constructor — named `new` per Rust convention.
    pub fn new(token: impl Into<String>, user_id: u64, expires_in: Duration) -> Self {
        Self {
            token: token.into(),
            user_id,
            created_at: Instant::now(),
            expires_in,
            read_only: false,
        }
    }

    /// Variant constructor using `with_` prefix for a specific configuration.
    pub fn with_readonly(token: impl Into<String>, user_id: u64, expires_in: Duration) -> Self {
        Self {
            token: token.into(),
            user_id,
            created_at: Instant::now(),
            expires_in,
            read_only: true,
        }
    }

    /// Conversion constructor — `from_` prefix for constructing from another type.
    pub fn from_jwt(jwt: &str, user_id: u64) -> Result<Self, String> {
        // Simulate token extraction from JWT
        if jwt.starts_with("eyJ") {
            Ok(Self::new(jwt, user_id, Duration::from_secs(3600)))
        } else {
            Err(format!("invalid JWT format"))
        }
    }

    pub fn is_expired(&self) -> bool {
        self.created_at.elapsed() > self.expires_in
    }
}

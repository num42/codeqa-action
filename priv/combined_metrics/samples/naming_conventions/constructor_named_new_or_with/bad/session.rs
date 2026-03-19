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
    // Bad: general constructor should be named `new`, not `create`
    pub fn create(token: impl Into<String>, user_id: u64, expires_in: Duration) -> Self {
        Self {
            token: token.into(),
            user_id,
            created_at: Instant::now(),
            expires_in,
            read_only: false,
        }
    }

    // Bad: `make_readonly` should be `with_readonly` to follow `with_*` convention
    pub fn make_readonly(token: impl Into<String>, user_id: u64, expires_in: Duration) -> Self {
        Self {
            token: token.into(),
            user_id,
            created_at: Instant::now(),
            expires_in,
            read_only: true,
        }
    }

    // Bad: conversion constructor should be `from_jwt`, not `build_from_jwt`
    pub fn build_from_jwt(jwt: &str, user_id: u64) -> Result<Self, String> {
        if jwt.starts_with("eyJ") {
            Ok(Self::create(jwt, user_id, Duration::from_secs(3600)))
        } else {
            Err(format!("invalid JWT format"))
        }
    }

    // Bad: `init` is not a Rust convention for constructors
    pub fn init_guest() -> Self {
        Self {
            token: "guest".to_string(),
            user_id: 0,
            created_at: Instant::now(),
            expires_in: Duration::from_secs(300),
            read_only: true,
        }
    }

    pub fn is_expired(&self) -> bool {
        self.created_at.elapsed() > self.expires_in
    }
}

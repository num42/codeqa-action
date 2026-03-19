#[derive(Debug, Clone)]
pub struct User {
    id: u64,
    username: String,
    email: String,
    age: u32,
    role: String,
}

impl User {
    pub fn new(id: u64, username: impl Into<String>, email: impl Into<String>, age: u32, role: impl Into<String>) -> Self {
        Self { id, username: username.into(), email: email.into(), age, role: role.into() }
    }

    // Bad: "get_" prefix is a Java/C++ convention — not idiomatic Rust
    pub fn get_id(&self) -> u64 {
        self.id
    }

    pub fn get_username(&self) -> &str {
        &self.username
    }

    pub fn get_email(&self) -> &str {
        &self.email
    }

    pub fn get_age(&self) -> u32 {
        self.age
    }

    pub fn get_role(&self) -> &str {
        &self.role
    }

    // Verbose and redundant: set_ on setters is fine, but callers now write
    // user.get_email() instead of the idiomatic user.email()
    pub fn set_email(&mut self, email: impl Into<String>) {
        self.email = email.into();
    }

    pub fn set_role(&mut self, role: impl Into<String>) {
        self.role = role.into();
    }
}

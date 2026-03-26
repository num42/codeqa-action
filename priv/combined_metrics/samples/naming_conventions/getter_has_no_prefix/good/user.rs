#[derive(Debug, Clone)]
pub struct User {
    id: u64,
    username: String,
    email: String,
    age: u32,
    role: Role,
}

#[derive(Debug, Clone, PartialEq)]
pub enum Role {
    Admin,
    Member,
    Guest,
}

impl User {
    pub fn new(id: u64, username: impl Into<String>, email: impl Into<String>, age: u32, role: Role) -> Self {
        Self { id, username: username.into(), email: email.into(), age, role }
    }

    // Good: Rust convention — getters are named after the field, no "get_" prefix
    pub fn id(&self) -> u64 {
        self.id
    }

    pub fn username(&self) -> &str {
        &self.username
    }

    pub fn email(&self) -> &str {
        &self.email
    }

    pub fn age(&self) -> u32 {
        self.age
    }

    pub fn role(&self) -> &Role {
        &self.role
    }

    // Setters use "set_" prefix — that IS idiomatic for mutation
    pub fn set_email(&mut self, email: impl Into<String>) {
        self.email = email.into();
    }

    pub fn set_role(&mut self, role: Role) {
        self.role = role;
    }
}

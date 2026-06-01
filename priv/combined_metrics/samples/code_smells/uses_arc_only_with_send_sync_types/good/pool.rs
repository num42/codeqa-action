use std::sync::{Arc, Mutex};

/// A connection that is safe to share across threads.
/// Implements Send + Sync, making it valid to wrap in Arc.
#[derive(Debug)]
pub struct Connection {
    pub id: u64,
    pub url: String,
    pub active: bool,
}

// Connection is Send + Sync because all its fields are Send + Sync
// Arc<Connection> is therefore also Send + Sync — correct usage
pub struct Pool {
    connections: Vec<Arc<Mutex<Connection>>>,
    max_size: usize,
}

impl Pool {
    pub fn new(max_size: usize) -> Self {
        Self { connections: Vec::new(), max_size }
    }

    pub fn add(&mut self, url: impl Into<String>) -> Arc<Mutex<Connection>> {
        let conn = Arc::new(Mutex::new(Connection {
            id: self.connections.len() as u64,
            url: url.into(),
            active: true,
        }));
        self.connections.push(Arc::clone(&conn));
        conn
    }

    // Returns an Arc to share the connection safely between threads
    pub fn get_connection(&self, id: u64) -> Option<Arc<Mutex<Connection>>> {
        self.connections
            .iter()
            .find(|c| c.lock().map(|c| c.id == id).unwrap_or(false))
            .map(Arc::clone)
    }

    pub fn active_count(&self) -> usize {
        self.connections
            .iter()
            .filter(|c| c.lock().map(|c| c.active).unwrap_or(false))
            .count()
    }
}

// Shared, thread-safe state — Arc wraps a Mutex<Vec<...>>, all Send + Sync
pub type SharedLog = Arc<Mutex<Vec<String>>>;

pub fn create_shared_log() -> SharedLog {
    Arc::new(Mutex::new(Vec::new()))
}

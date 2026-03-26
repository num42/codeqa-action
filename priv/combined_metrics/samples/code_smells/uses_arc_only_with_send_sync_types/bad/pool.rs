use std::cell::RefCell;
use std::rc::Rc;
use std::sync::Arc;

/// A connection that uses RefCell for interior mutability.
/// RefCell is NOT Sync — it cannot be safely accessed from multiple threads.
pub struct Connection {
    pub id: u64,
    pub url: String,
    // RefCell is !Sync — wrapping this in Arc<Connection> is unsound
    pub state: RefCell<String>,
}

// BAD: Arc<Connection> requires Connection: Send + Sync.
// Because Connection contains RefCell, it is !Sync.
// This will fail to compile when sent across threads, but the intent is wrong.
pub struct Pool {
    // Arc<Connection> here is misleading — it looks thread-safe but isn't
    connections: Vec<Arc<Connection>>,
}

impl Pool {
    pub fn new() -> Self {
        Self { connections: Vec::new() }
    }

    pub fn add(&mut self, url: impl Into<String>) -> Arc<Connection> {
        let conn = Arc::new(Connection {
            id: self.connections.len() as u64,
            url: url.into(),
            state: RefCell::new("idle".to_string()),
        });
        self.connections.push(Arc::clone(&conn));
        conn
    }
}

// BAD: Rc is not Send, so Arc<Rc<T>> cannot be used across threads.
// Using Arc here is misleading — the Rc inside prevents thread sharing.
pub struct BadSharedHandle {
    inner: Arc<Rc<String>>,
}

impl BadSharedHandle {
    pub fn new(s: impl Into<String>) -> Self {
        Self { inner: Arc::new(Rc::new(s.into())) }
    }

    pub fn value(&self) -> Rc<String> {
        Rc::clone(&self.inner)
    }
}

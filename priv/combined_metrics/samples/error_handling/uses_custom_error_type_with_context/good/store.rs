use std::collections::HashMap;
use std::fmt;

#[derive(Debug)]
pub enum StoreError {
    NotFound { key: String },
    CapacityExceeded { limit: usize },
    SerializationFailed { key: String, reason: String },
    StorageFull { used_bytes: u64, max_bytes: u64 },
}

impl fmt::Display for StoreError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            StoreError::NotFound { key } => write!(f, "key not found: '{key}'"),
            StoreError::CapacityExceeded { limit } => {
                write!(f, "store capacity of {limit} entries exceeded")
            }
            StoreError::SerializationFailed { key, reason } => {
                write!(f, "failed to serialize value for key '{key}': {reason}")
            }
            StoreError::StorageFull { used_bytes, max_bytes } => {
                write!(f, "storage full: {used_bytes}/{max_bytes} bytes used")
            }
        }
    }
}

impl std::error::Error for StoreError {}

pub struct BoundedStore {
    data: HashMap<String, Vec<u8>>,
    max_entries: usize,
    max_bytes: u64,
    used_bytes: u64,
}

impl BoundedStore {
    pub fn new(max_entries: usize, max_bytes: u64) -> Self {
        Self {
            data: HashMap::new(),
            max_entries,
            max_bytes,
            used_bytes: 0,
        }
    }

    pub fn insert(&mut self, key: String, value: Vec<u8>) -> Result<(), StoreError> {
        if self.data.len() >= self.max_entries && !self.data.contains_key(&key) {
            return Err(StoreError::CapacityExceeded { limit: self.max_entries });
        }
        let new_bytes = self.used_bytes + value.len() as u64;
        if new_bytes > self.max_bytes {
            return Err(StoreError::StorageFull {
                used_bytes: self.used_bytes,
                max_bytes: self.max_bytes,
            });
        }
        self.used_bytes = new_bytes;
        self.data.insert(key, value);
        Ok(())
    }

    pub fn get(&self, key: &str) -> Result<&[u8], StoreError> {
        self.data
            .get(key)
            .map(Vec::as_slice)
            .ok_or_else(|| StoreError::NotFound { key: key.to_string() })
    }
}

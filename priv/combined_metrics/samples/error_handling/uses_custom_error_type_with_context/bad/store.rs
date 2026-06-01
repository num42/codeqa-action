use std::collections::HashMap;

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

    // Returning raw &str errors: no structure, callers can't match on variants
    pub fn insert(&mut self, key: String, value: Vec<u8>) -> Result<(), &'static str> {
        if self.data.len() >= self.max_entries && !self.data.contains_key(&key) {
            // Cannot include actual limit in static string
            return Err("capacity exceeded");
        }
        let new_bytes = self.used_bytes + value.len() as u64;
        if new_bytes > self.max_bytes {
            // Cannot communicate how full the store is
            return Err("storage full");
        }
        self.used_bytes = new_bytes;
        self.data.insert(key, value);
        Ok(())
    }

    // Returning String errors: slightly better, but callers can't pattern match
    pub fn get(&self, key: &str) -> Result<&[u8], String> {
        self.data
            .get(key)
            .map(Vec::as_slice)
            // key is in the message, but only as a substring — fragile to parse
            .ok_or_else(|| format!("not found: {key}"))
    }

    pub fn remove(&mut self, key: &str) -> Result<Vec<u8>, String> {
        self.data
            .remove(key)
            .ok_or_else(|| "key does not exist".to_string())
        // No key context — caller cannot tell which key was missing
    }
}

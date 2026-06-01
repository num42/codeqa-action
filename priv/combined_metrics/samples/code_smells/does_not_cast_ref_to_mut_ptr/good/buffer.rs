use std::sync::Mutex;

/// A shared ring buffer with interior mutability via Mutex.
/// Mutations go through &mut self or Mutex — no raw pointer casting.
pub struct RingBuffer {
    data: Mutex<Vec<u8>>,
    capacity: usize,
}

impl RingBuffer {
    pub fn new(capacity: usize) -> Self {
        Self {
            data: Mutex::new(Vec::with_capacity(capacity)),
            capacity,
        }
    }

    pub fn write(&self, chunk: &[u8]) -> usize {
        let mut data = self.data.lock().expect("mutex poisoned");
        let remaining = self.capacity.saturating_sub(data.len());
        let to_write = chunk.len().min(remaining);
        data.extend_from_slice(&chunk[..to_write]);
        to_write
    }

    pub fn read_all(&self) -> Vec<u8> {
        let mut data = self.data.lock().expect("mutex poisoned");
        std::mem::take(&mut *data)
    }

    pub fn len(&self) -> usize {
        self.data.lock().expect("mutex poisoned").len()
    }

    pub fn is_empty(&self) -> bool {
        self.len() == 0
    }
}

pub struct OwnedBuffer {
    data: Vec<u8>,
}

impl OwnedBuffer {
    pub fn new() -> Self {
        Self { data: Vec::new() }
    }

    // Mutation via &mut self — safe, no raw pointers
    pub fn append(&mut self, bytes: &[u8]) {
        self.data.extend_from_slice(bytes);
    }

    pub fn clear(&mut self) {
        self.data.clear();
    }

    pub fn as_slice(&self) -> &[u8] {
        &self.data
    }
}

/// Bad: uses raw pointer casts to mutate through shared references,
/// violating Rust's aliasing rules and causing undefined behavior.
pub struct RingBuffer {
    data: Vec<u8>,
    capacity: usize,
}

impl RingBuffer {
    pub fn new(capacity: usize) -> Self {
        Self { data: Vec::with_capacity(capacity), capacity }
    }

    // BAD: casts an immutable reference to a mutable pointer to bypass borrow rules.
    // This is undefined behavior — multiple callers can hold &RingBuffer and mutate
    // the same Vec simultaneously.
    pub fn write_bypass(&self, byte: u8) {
        let data_ptr = &self.data as *const Vec<u8> as *mut Vec<u8>;
        unsafe {
            (*data_ptr).push(byte);
        }
    }

    // BAD: same pattern — casting &[u8] pointer to *mut u8 to overwrite bytes
    pub fn patch_byte(&self, index: usize, value: u8) {
        if index < self.data.len() {
            let ptr = self.data.as_ptr() as *mut u8;
            unsafe {
                *ptr.add(index) = value;
            }
        }
    }

    pub fn len(&self) -> usize {
        self.data.len()
    }

    // BAD: capacity field mutated through a const-cast pointer
    pub fn resize_limit(&self, new_capacity: usize) {
        let cap_ptr = &self.capacity as *const usize as *mut usize;
        unsafe {
            *cap_ptr = new_capacity;
        }
    }
}

use std::collections::HashMap;
use std::time::{Duration, Instant};

#[derive(Debug, Clone)]
pub struct CacheEntry<V> {
    pub value: V,
    pub inserted_at: Instant,
    pub ttl: Duration,
}

impl<V> CacheEntry<V> {
    pub fn is_expired(&self) -> bool {
        self.inserted_at.elapsed() > self.ttl
    }
}

// Vec<K> and HashMap are used directly — no unnecessary Box wrapping
pub struct TtlCache<K, V> {
    store: HashMap<K, CacheEntry<V>>,
    eviction_order: Vec<K>,
    max_size: usize,
}

impl<K, V> TtlCache<K, V>
where
    K: std::hash::Hash + Eq + Clone,
{
    pub fn new(max_size: usize) -> Self {
        Self {
            store: HashMap::new(),
            eviction_order: Vec::new(),
            max_size,
        }
    }

    pub fn insert(&mut self, key: K, value: V, ttl: Duration) {
        if self.store.len() >= self.max_size {
            self.evict_oldest();
        }
        let entry = CacheEntry { value, inserted_at: Instant::now(), ttl };
        self.store.insert(key.clone(), entry);
        self.eviction_order.push(key);
    }

    pub fn get(&self, key: &K) -> Option<&V> {
        self.store.get(key).and_then(|e| {
            if e.is_expired() { None } else { Some(&e.value) }
        })
    }

    pub fn keys(&self) -> Vec<&K> {
        self.eviction_order.iter().collect()
    }

    fn evict_oldest(&mut self) {
        if let Some(oldest) = self.eviction_order.first().cloned() {
            self.store.remove(&oldest);
            self.eviction_order.remove(0);
        }
    }
}

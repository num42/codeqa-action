use std::collections::HashMap;
use std::time::{Duration, Instant};

#[derive(Debug, Clone)]
pub struct CacheEntry<V: Clone> {
    pub value: V,
    pub inserted_at: Instant,
    pub ttl: Duration,
}

// Bad: Vec and HashMap are wrapped in Box — adds heap indirection with no benefit
pub struct TtlCache<K: Clone + std::hash::Hash + Eq, V: Clone> {
    // Box<HashMap<...>> adds an extra pointer hop for every lookup
    store: Box<HashMap<K, CacheEntry<V>>>,
    // Box<Vec<...>> is redundant — Vec already lives on the heap
    eviction_order: Box<Vec<K>>,
    max_size: usize,
}

impl<K, V> TtlCache<K, V>
where
    K: std::hash::Hash + Eq + Clone,
    V: Clone,
{
    pub fn new(max_size: usize) -> Self {
        Self {
            store: Box::new(HashMap::new()),
            eviction_order: Box::new(Vec::new()),
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
            if e.inserted_at.elapsed() > e.ttl { None } else { Some(&e.value) }
        })
    }

    // Returning Box<Vec<...>> — caller must dereference to get slice behavior
    pub fn snapshot_keys(&self) -> Box<Vec<K>> {
        Box::new(self.eviction_order.iter().cloned().collect())
    }

    fn evict_oldest(&mut self) {
        if let Some(oldest) = self.eviction_order.first().cloned() {
            self.store.remove(&oldest);
            self.eviction_order.remove(0);
        }
    }
}

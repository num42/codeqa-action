use std::collections::HashMap;

#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct ServiceId(pub String);

#[derive(Debug, Clone)]
pub struct ServiceEntry {
    pub id: ServiceId,
    pub endpoint: String,
    pub healthy: bool,
}

pub struct Registry {
    entries: HashMap<ServiceId, ServiceEntry>,
    primary_id: Option<ServiceId>,
}

impl Registry {
    pub fn new() -> Self {
        Self { entries: HashMap::new(), primary_id: None }
    }

    pub fn register(&mut self, entry: ServiceEntry) {
        self.entries.insert(entry.id.clone(), entry);
    }

    pub fn set_primary(&mut self, id: ServiceId) {
        self.primary_id = Some(id);
    }

    // Compare by reference — no clone needed
    pub fn is_primary(&self, id: &ServiceId) -> bool {
        self.primary_id.as_ref() == Some(id)
    }

    // Find without cloning the candidate
    pub fn find_by_endpoint(&self, endpoint: &str) -> Option<&ServiceEntry> {
        self.entries.values().find(|e| e.endpoint == endpoint)
    }

    pub fn healthy_ids(&self) -> Vec<&ServiceId> {
        self.entries
            .values()
            .filter(|e| e.healthy)
            .map(|e| &e.id)
            .collect()
    }

    pub fn contains(&self, id: &ServiceId) -> bool {
        self.entries.contains_key(id)
    }
}

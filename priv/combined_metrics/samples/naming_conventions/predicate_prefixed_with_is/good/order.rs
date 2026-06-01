#[derive(Debug, Clone, PartialEq)]
pub enum OrderStatus {
    Pending,
    Confirmed,
    Shipped,
    Delivered,
    Cancelled,
    Refunded,
}

#[derive(Debug, Clone)]
pub struct Order {
    pub id: u64,
    pub status: OrderStatus,
    pub total_cents: u64,
    pub item_count: u32,
    pub discount_applied: bool,
}

impl Order {
    pub fn new(id: u64, total_cents: u64, item_count: u32) -> Self {
        Self {
            id,
            status: OrderStatus::Pending,
            total_cents,
            item_count,
            discount_applied: false,
        }
    }

    // Good: boolean predicates use is_ or has_ prefix
    pub fn is_pending(&self) -> bool {
        self.status == OrderStatus::Pending
    }

    pub fn is_cancelled(&self) -> bool {
        self.status == OrderStatus::Cancelled
    }

    pub fn is_fulfilled(&self) -> bool {
        matches!(self.status, OrderStatus::Shipped | OrderStatus::Delivered)
    }

    pub fn is_empty(&self) -> bool {
        self.item_count == 0
    }

    pub fn has_discount(&self) -> bool {
        self.discount_applied
    }

    pub fn is_high_value(&self) -> bool {
        self.total_cents >= 10_000_00
    }
}

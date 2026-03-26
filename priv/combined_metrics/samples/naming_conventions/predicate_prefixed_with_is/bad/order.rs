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

    // Bad: boolean predicates should start with is_ or has_
    pub fn pending(&self) -> bool {
        self.status == OrderStatus::Pending
    }

    pub fn cancelled(&self) -> bool {
        self.status == OrderStatus::Cancelled
    }

    // "fulfilled" reads like a noun or past-tense verb — ambiguous without "is_"
    pub fn fulfilled(&self) -> bool {
        matches!(self.status, OrderStatus::Shipped | OrderStatus::Delivered)
    }

    // "empty" without "is_" is unclear whether it's an adjective or a verb
    pub fn empty(&self) -> bool {
        self.item_count == 0
    }

    // "discount" alone is ambiguous — could mean apply a discount
    pub fn discount(&self) -> bool {
        self.discount_applied
    }

    // "high_value" reads oddly without the "is_" prefix
    pub fn high_value(&self) -> bool {
        self.total_cents >= 10_000_00
    }
}

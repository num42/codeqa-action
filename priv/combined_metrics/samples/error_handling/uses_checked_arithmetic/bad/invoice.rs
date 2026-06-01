pub struct LineItem {
    pub description: String,
    pub unit_price_cents: u64,
    pub quantity: u32,
}

impl LineItem {
    pub fn subtotal(&self) -> u64 {
        // Silently wraps on overflow in release builds — wrong amount charged
        self.unit_price_cents * self.quantity as u64
    }
}

pub struct Invoice {
    pub items: Vec<LineItem>,
    /// Discount in basis points (100 = 1%)
    pub discount_bps: u32,
}

impl Invoice {
    pub fn total_cents(&self) -> u64 {
        let subtotal: u64 = self.items.iter().map(|i| i.subtotal()).sum();

        // If discount_bps > 10_000 this underflows to a huge positive number
        let after_discount = subtotal * (10_000 - self.discount_bps as u64) / 10_000;

        // Final accumulation also has no overflow check
        after_discount
    }

    pub fn tax_amount(&self, rate_bps: u32) -> u64 {
        let total = self.total_cents();
        // Multiplication can overflow for large totals
        total * rate_bps as u64 / 10_000
    }

    pub fn grand_total(&self, tax_rate_bps: u32) -> u64 {
        // Adding two potentially wrapped values — wrong result silently returned
        self.total_cents() + self.tax_amount(tax_rate_bps)
    }
}

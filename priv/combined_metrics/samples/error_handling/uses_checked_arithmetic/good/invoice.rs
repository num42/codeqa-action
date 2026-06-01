use std::fmt;

#[derive(Debug)]
pub enum InvoiceError {
    LineItemOverflow { item: String },
    TotalOverflow,
    DiscountOutOfRange(u32),
}

impl fmt::Display for InvoiceError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            InvoiceError::LineItemOverflow { item } => {
                write!(f, "line item subtotal overflowed for: {item}")
            }
            InvoiceError::TotalOverflow => write!(f, "invoice total overflowed u64"),
            InvoiceError::DiscountOutOfRange(d) => {
                write!(f, "discount {d} basis points exceeds 100%")
            }
        }
    }
}

#[derive(Debug)]
pub struct LineItem {
    pub description: String,
    pub unit_price_cents: u64,
    pub quantity: u32,
}

impl LineItem {
    pub fn subtotal(&self) -> Result<u64, InvoiceError> {
        let qty = self.quantity as u64;
        self.unit_price_cents
            .checked_mul(qty)
            .ok_or_else(|| InvoiceError::LineItemOverflow {
                item: self.description.clone(),
            })
    }
}

pub struct Invoice {
    pub items: Vec<LineItem>,
    /// Discount in basis points (100 = 1%)
    pub discount_bps: u32,
}

impl Invoice {
    pub fn total_cents(&self) -> Result<u64, InvoiceError> {
        if self.discount_bps > 10_000 {
            return Err(InvoiceError::DiscountOutOfRange(self.discount_bps));
        }

        let subtotal = self
            .items
            .iter()
            .try_fold(0u64, |acc, item| {
                item.subtotal()?
                    .checked_add(acc)
                    .ok_or(InvoiceError::TotalOverflow)
            })?;

        let discount_factor = 10_000 - self.discount_bps as u64;
        subtotal
            .checked_mul(discount_factor)
            .and_then(|n| n.checked_div(10_000))
            .ok_or(InvoiceError::TotalOverflow)
    }
}

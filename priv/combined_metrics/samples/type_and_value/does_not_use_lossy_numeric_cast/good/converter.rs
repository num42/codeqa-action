use std::num::TryFromIntError;

#[derive(Debug)]
pub enum ConversionError {
    Overflow { from: &'static str, to: &'static str, value: i64 },
    NegativeToUnsigned(i64),
}

impl std::fmt::Display for ConversionError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            ConversionError::Overflow { from, to, value } => {
                write!(f, "value {value} overflows when converting {from} to {to}")
            }
            ConversionError::NegativeToUnsigned(v) => {
                write!(f, "cannot convert negative value {v} to unsigned type")
            }
        }
    }
}

impl From<TryFromIntError> for ConversionError {
    fn from(_: TryFromIntError) -> Self {
        ConversionError::Overflow { from: "integer", to: "integer", value: 0 }
    }
}

/// Converts a file size reported as i64 to a usize page index safely.
pub fn size_to_usize(size: i64) -> Result<usize, ConversionError> {
    if size < 0 {
        return Err(ConversionError::NegativeToUnsigned(size));
    }
    usize::try_from(size as u64).map_err(|_| ConversionError::Overflow {
        from: "i64",
        to: "usize",
        value: size,
    })
}

/// Converts a packet length from u64 to u16 for a protocol field.
pub fn payload_len(total: u64) -> Result<u16, ConversionError> {
    u16::try_from(total).map_err(|_| ConversionError::Overflow {
        from: "u64",
        to: "u16",
        value: total as i64,
    })
}

/// Converts a sampling rate (f64 samples/sec) to an integer rate, checking range.
pub fn sample_rate_to_u32(rate: f64) -> Result<u32, ConversionError> {
    if rate < 0.0 || rate > u32::MAX as f64 {
        return Err(ConversionError::Overflow {
            from: "f64",
            to: "u32",
            value: rate as i64,
        });
    }
    Ok(rate as u32)
}

/// Accumulates byte counts from multiple sources, guarding against overflow.
pub fn total_bytes(counts: &[u32]) -> Result<u64, ConversionError> {
    counts
        .iter()
        .try_fold(0u64, |acc, &n| {
            acc.checked_add(n as u64)
                .ok_or(ConversionError::Overflow { from: "u64", to: "u64", value: 0 })
        })
}

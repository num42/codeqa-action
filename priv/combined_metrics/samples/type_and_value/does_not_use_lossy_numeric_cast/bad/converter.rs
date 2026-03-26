/// Converts a file size reported as i64 to a usize page index.
/// BAD: as cast silently truncates on 32-bit targets or wraps on negatives.
pub fn size_to_usize(size: i64) -> usize {
    // If size is negative this wraps to a huge usize — memory corruption risk
    size as usize
}

/// Converts a packet length from u64 to u16 for a protocol field.
/// BAD: values above 65535 are silently truncated to (value % 65536).
pub fn payload_len(total: u64) -> u16 {
    total as u16
}

/// Converts a sampling rate f64 to an integer rate.
/// BAD: if rate > u32::MAX the result wraps; NaN becomes 0; negative becomes 0.
pub fn sample_rate_to_u32(rate: f64) -> u32 {
    rate as u32
}

/// Accumulates byte counts — BAD: individual casts and sum may silently overflow.
pub fn total_bytes(counts: &[u32]) -> usize {
    let mut total: usize = 0;
    for &n in counts {
        // Cast to usize is safe here, but the addition can silently overflow
        // on 32-bit targets where usize is 32 bits
        total += n as usize;
    }
    total
}

/// Computes a score from a large value — BAD: lossy f32 cast loses precision.
pub fn score(raw: u64) -> f32 {
    // u64 values above 2^24 cannot be represented exactly in f32
    raw as f32 / 1_000_000.0
}

/// Maps an i32 row count to an i16 display limit — BAD: values above 32767 wrap.
pub fn row_display_limit(count: i32) -> i16 {
    count as i16
}

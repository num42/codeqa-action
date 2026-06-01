pub struct MetricSeries {
    pub timestamps: Vec<u64>,
    pub values: Vec<f64>,
}

impl MetricSeries {
    pub fn new(timestamps: Vec<u64>, values: Vec<f64>) -> Self {
        Self { timestamps, values }
    }

    // Bad: .cloned() on u64 — u64 is Copy, .copied() is the right choice
    pub fn recent_timestamps(&self, n: usize) -> Vec<u64> {
        self.timestamps
            .iter()
            .rev()
            .take(n)
            .cloned()
            .collect()
    }

    // Bad: .cloned() on f64 — misleadingly suggests Clone behavior
    pub fn max_value(&self) -> Option<f64> {
        self.values.iter().cloned().reduce(f64::max)
    }

    pub fn values_above(&self, threshold: f64) -> Vec<f64> {
        self.values
            .iter()
            .cloned()
            .filter(|&v| v > threshold)
            .collect()
    }

    pub fn timestamp_range(&self) -> Option<(u64, u64)> {
        // Bad: .cloned() on a Copy type throughout
        let min = self.timestamps.iter().cloned().min()?;
        let max = self.timestamps.iter().cloned().max()?;
        Some((min, max))
    }

    // Bad: .cloned() on i32 — i32 implements Copy, not just Clone
    pub fn count_ids_above(ids: &[i32], threshold: i32) -> Vec<i32> {
        ids.iter()
            .cloned()
            .filter(|&id| id > threshold)
            .collect()
    }
}

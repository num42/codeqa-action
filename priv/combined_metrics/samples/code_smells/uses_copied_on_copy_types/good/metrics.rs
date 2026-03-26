pub struct MetricSeries {
    pub timestamps: Vec<u64>,
    pub values: Vec<f64>,
}

impl MetricSeries {
    pub fn new(timestamps: Vec<u64>, values: Vec<f64>) -> Self {
        Self { timestamps, values }
    }

    // u64 is Copy — use .copied() to avoid the misleading suggestion of Clone
    pub fn recent_timestamps(&self, n: usize) -> Vec<u64> {
        self.timestamps
            .iter()
            .rev()
            .take(n)
            .copied()
            .collect()
    }

    // f64 is Copy — .copied() is correct and clear
    pub fn max_value(&self) -> Option<f64> {
        self.values.iter().copied().reduce(f64::max)
    }

    pub fn values_above(&self, threshold: f64) -> Vec<f64> {
        self.values
            .iter()
            .copied()
            .filter(|&v| v > threshold)
            .collect()
    }

    pub fn timestamp_range(&self) -> Option<(u64, u64)> {
        let min = self.timestamps.iter().copied().min()?;
        let max = self.timestamps.iter().copied().max()?;
        Some((min, max))
    }

    // i32 is Copy — .copied() communicates intent clearly
    pub fn count_ids_above(ids: &[i32], threshold: i32) -> Vec<i32> {
        ids.iter()
            .copied()
            .filter(|&id| id > threshold)
            .collect()
    }
}

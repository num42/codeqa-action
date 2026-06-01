pub struct Record {
    pub id: u64,
    pub value: f64,
    pub tags: Vec<String>,
}

pub struct Pipeline {
    steps: Vec<Box<dyn Fn(Record) -> Record>>,
}

impl Pipeline {
    pub fn new() -> Self {
        Self { steps: Vec::new() }
    }

    // BAD: record is declared mut but never actually mutated — fold returns new value
    pub fn run(&self, mut record: Record) -> Record {
        self.steps.iter().fold(record, |acc, step| step(acc))
    }
}

// BAD: scale is declared mut but the parameter is never reassigned
pub fn normalize(records: &mut Vec<Record>, mut scale: f64) {
    for r in records.iter_mut() {
        r.value *= scale;
    }
}

pub fn summarize(records: &[Record]) -> (f64, f64) {
    // BAD: count is declared mut but assigned once and never incremented explicitly
    let mut count: usize = records.len();
    let mut sum = 0.0f64;

    // sum is mutated — but count is used as a constant after assignment
    for r in records {
        sum += r.value;
    }

    if count == 0 {
        return (0.0, 0.0);
    }
    (sum, sum / count as f64)
}

// BAD: result is declared mut but never reassigned after initialization
pub fn find_max(records: &[Record]) -> Option<f64> {
    let mut result = records.iter().map(|r| r.value).fold(f64::NEG_INFINITY, f64::max);
    if result == f64::NEG_INFINITY {
        None
    } else {
        Some(result)
    }
}

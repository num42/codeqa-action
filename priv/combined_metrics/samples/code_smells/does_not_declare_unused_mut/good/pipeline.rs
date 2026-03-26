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
        // steps will be mutated — mut is needed here
        let mut steps: Vec<Box<dyn Fn(Record) -> Record>> = Vec::new();
        steps.push(Box::new(|r| r)); // identity step
        Self { steps }
    }

    // No mut needed on record — we return a new one via fold
    pub fn run(&self, record: Record) -> Record {
        self.steps.iter().fold(record, |acc, step| step(acc))
    }

    pub fn add_step(&mut self, step: impl Fn(Record) -> Record + 'static) {
        self.steps.push(Box::new(step));
    }
}

pub fn normalize(records: &mut Vec<Record>, scale: f64) {
    // records is genuinely mutated via iter_mut
    for r in records.iter_mut() {
        r.value *= scale;
    }
}

pub fn summarize(records: &[Record]) -> (f64, f64) {
    // sum and count are mutated by the loop
    let mut sum = 0.0f64;
    let mut count = 0usize;
    for r in records {
        sum += r.value;
        count += 1;
    }
    if count == 0 {
        return (0.0, 0.0);
    }
    (sum, sum / count as f64)
}

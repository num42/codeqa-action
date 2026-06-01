use std::collections::VecDeque;
use std::sync::{Arc, Mutex};

#[derive(Debug, Clone)]
pub struct Job {
    pub id: u64,
    pub payload: String,
}

pub struct JobQueue {
    inner: Arc<Mutex<VecDeque<Job>>>,
}

impl JobQueue {
    pub fn new() -> Self {
        Self { inner: Arc::new(Mutex::new(VecDeque::new())) }
    }

    pub fn push(&self, job: Job) {
        let mut q = self.inner.lock().expect("mutex poisoned");
        q.push_back(job);
        // Guard dropped at end of block — not held across await
    }

    // Good: release the lock before awaiting, then use the extracted value
    pub async fn process_next(&self) -> Option<String> {
        // Extract the job while holding the lock...
        let job = {
            let mut q = self.inner.lock().expect("mutex poisoned");
            q.pop_front()
            // MutexGuard dropped here — before any await point
        };

        // ...then await without holding the lock
        match job {
            Some(j) => Some(self.handle_job(j).await),
            None => None,
        }
    }

    async fn handle_job(&self, job: Job) -> String {
        // Simulated async work (e.g., HTTP call, DB write)
        tokio::time::sleep(std::time::Duration::from_millis(1)).await;
        format!("processed job #{}: {}", job.id, job.payload)
    }

    pub fn len(&self) -> usize {
        self.inner.lock().expect("mutex poisoned").len()
    }
}

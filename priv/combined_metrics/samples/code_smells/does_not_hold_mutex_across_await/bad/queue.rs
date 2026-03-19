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
        self.inner.lock().expect("mutex poisoned").push_back(job);
    }

    // BAD: the MutexGuard is held across an .await point.
    // This can deadlock (tokio Mutex panics) or block other tasks from
    // acquiring the lock while the async work runs.
    pub async fn process_next_bad(&self) -> Option<String> {
        let mut q = self.inner.lock().expect("mutex poisoned");
        // MutexGuard is still live here — held across the await below
        let job = q.pop_front()?;

        // Awaiting while holding the guard — deadlock risk
        let result = self.handle_job(&job).await;
        // Guard finally dropped when this function returns, after all awaits
        Some(result)
    }

    // BAD: returns while guard is in scope after an await
    pub async fn peek_and_log(&self) {
        let q = self.inner.lock().expect("mutex poisoned");
        if let Some(job) = q.front() {
            println!("next job: {}", job.id);
        }
        // MutexGuard q is still in scope
        tokio::time::sleep(std::time::Duration::from_millis(10)).await;
        // q dropped here — after the await
    }

    async fn handle_job(&self, job: &Job) -> String {
        tokio::time::sleep(std::time::Duration::from_millis(1)).await;
        format!("processed job #{}: {}", job.id, job.payload)
    }
}

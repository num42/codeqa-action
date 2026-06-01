use std::fmt;

pub trait Task: fmt::Debug + Send {
    fn name(&self) -> &str;
    fn execute(&self) -> Result<String, String>;
}

#[derive(Debug)]
pub struct EmailTask {
    pub recipient: String,
    pub subject: String,
}

impl Task for EmailTask {
    fn name(&self) -> &str {
        "email"
    }
    fn execute(&self) -> Result<String, String> {
        Ok(format!("sent email to {} re: {}", self.recipient, self.subject))
    }
}

#[derive(Debug)]
pub struct ReportTask {
    pub report_id: u64,
}

impl Task for ReportTask {
    fn name(&self) -> &str {
        "report"
    }
    fn execute(&self) -> Result<String, String> {
        Ok(format!("generated report #{}", self.report_id))
    }
}

// Accept &dyn Task (or &T) rather than &Box<dyn Task> — works with
// both owned Box<dyn Task> and references to stack-allocated types
pub fn run_task(task: &dyn Task) -> Result<String, String> {
    println!("running task: {}", task.name());
    task.execute()
}

pub fn run_all(tasks: &[Box<dyn Task>]) -> Vec<Result<String, String>> {
    // Dereference each Box to get &dyn Task — clean, no Box leaking into API
    tasks.iter().map(|t| run_task(t.as_ref())).collect()
}

pub fn log_task_name(task: &dyn Task) {
    println!("[worker] task name: {}", task.name());
}

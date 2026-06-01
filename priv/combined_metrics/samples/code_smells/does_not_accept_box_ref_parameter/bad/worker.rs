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
    fn name(&self) -> &str { "email" }
    fn execute(&self) -> Result<String, String> {
        Ok(format!("sent email to {}", self.recipient))
    }
}

#[derive(Debug)]
pub struct ReportTask {
    pub report_id: u64,
}

impl Task for ReportTask {
    fn name(&self) -> &str { "report" }
    fn execute(&self) -> Result<String, String> {
        Ok(format!("generated report #{}", self.report_id))
    }
}

// Bad: &Box<dyn Task> forces callers to have an owned Box — cannot pass a
// plain reference; also adds an extra level of indirection unnecessarily.
pub fn run_task(task: &Box<dyn Task>) -> Result<String, String> {
    println!("running task: {}", task.name());
    task.execute()
}

pub fn run_all(tasks: &[Box<dyn Task>]) -> Vec<Result<String, String>> {
    tasks.iter().map(run_task).collect()
}

// Same anti-pattern with a concrete generic type
pub fn log_task_name(task: &Box<EmailTask>) {
    println!("[worker] task name: {}", task.name());
}

pub fn describe(task: &Box<dyn Task>) -> String {
    format!("Task({})", task.name())
}

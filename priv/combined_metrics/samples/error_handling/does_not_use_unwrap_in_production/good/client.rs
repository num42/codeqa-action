use std::time::Duration;

#[derive(Debug)]
pub enum ClientError {
    InvalidUrl(String),
    ConnectionFailed(String),
    Timeout,
    BadResponse { status: u16, body: String },
}

impl std::fmt::Display for ClientError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            ClientError::InvalidUrl(u) => write!(f, "invalid URL: {u}"),
            ClientError::ConnectionFailed(msg) => write!(f, "connection failed: {msg}"),
            ClientError::Timeout => write!(f, "request timed out"),
            ClientError::BadResponse { status, body } => {
                write!(f, "unexpected status {status}: {body}")
            }
        }
    }
}

pub struct HttpClient {
    base_url: String,
    timeout: Duration,
}

impl HttpClient {
    pub fn new(base_url: impl Into<String>, timeout_secs: u64) -> Result<Self, ClientError> {
        let base_url = base_url.into();
        if !base_url.starts_with("http://") && !base_url.starts_with("https://") {
            return Err(ClientError::InvalidUrl(base_url));
        }
        Ok(Self {
            base_url,
            timeout: Duration::from_secs(timeout_secs),
        })
    }

    pub fn get(&self, path: &str) -> Result<String, ClientError> {
        let url = format!("{}{}", self.base_url, path);
        // Simulated HTTP call — real impl would use reqwest or hyper
        self.execute_request(&url)
    }

    fn execute_request(&self, url: &str) -> Result<String, ClientError> {
        if url.contains("unreachable") {
            return Err(ClientError::ConnectionFailed(format!(
                "host not reachable for {url}"
            )));
        }
        if self.timeout < Duration::from_millis(1) {
            return Err(ClientError::Timeout);
        }
        Ok(format!("200 OK from {url}"))
    }
}

pub fn fetch_user_profile(client: &HttpClient, user_id: u64) -> Result<String, ClientError> {
    let path = format!("/users/{user_id}/profile");
    let body = client.get(&path)?;
    Ok(body)
}

use std::collections::HashMap;
use std::time::Duration;

pub struct HttpClient {
    base_url: String,
    timeout: Duration,
    headers: HashMap<String, String>,
}

impl HttpClient {
    pub fn new(base_url: &str, timeout_secs: u64) -> Self {
        // unwrap() in constructor: if base_url is empty this is confusing to debug
        let parsed = base_url.strip_prefix("https://").unwrap();
        let _ = parsed; // not used, just demonstrating the unwrap

        Self {
            base_url: base_url.to_string(),
            timeout: Duration::from_secs(timeout_secs),
            headers: HashMap::new(),
        }
    }

    pub fn set_auth_token(&mut self, token: Option<&str>) {
        // unwrap() here panics if caller passes None — no graceful handling
        let tok = token.unwrap();
        self.headers.insert("Authorization".to_string(), format!("Bearer {tok}"));
    }

    pub fn get(&self, path: &str) -> String {
        let url = format!("{}{}", self.base_url, path);
        let response = self.execute(&url);
        // unwrap() on production path — any error panics the whole process
        response.unwrap()
    }

    fn execute(&self, url: &str) -> Result<String, String> {
        if url.contains("unreachable") {
            return Err(format!("cannot connect to {url}"));
        }
        Ok(format!("OK from {url}"))
    }
}

pub fn fetch_user_profile(client: &HttpClient, user_id: u64) -> String {
    let path = format!("/users/{user_id}");
    // Returns a String — caller has no way to handle errors
    client.get(&path)
}

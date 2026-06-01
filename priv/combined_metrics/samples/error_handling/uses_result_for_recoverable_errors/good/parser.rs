use std::num::ParseIntError;
use std::fmt;

#[derive(Debug)]
pub enum ConfigError {
    MissingField(String),
    InvalidValue { field: String, reason: String },
    ParseError(ParseIntError),
}

impl fmt::Display for ConfigError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            ConfigError::MissingField(field) => write!(f, "missing required field: {field}"),
            ConfigError::InvalidValue { field, reason } => {
                write!(f, "invalid value for '{field}': {reason}")
            }
            ConfigError::ParseError(e) => write!(f, "parse error: {e}"),
        }
    }
}

impl From<ParseIntError> for ConfigError {
    fn from(e: ParseIntError) -> Self {
        ConfigError::ParseError(e)
    }
}

pub struct Config {
    pub host: String,
    pub port: u16,
    pub max_connections: usize,
}

pub fn parse_config(raw: &str) -> Result<Config, ConfigError> {
    let mut host = None;
    let mut port = None;
    let mut max_connections = None;

    for line in raw.lines() {
        let line = line.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        let (key, value) = line.split_once('=').ok_or_else(|| {
            ConfigError::InvalidValue {
                field: line.to_string(),
                reason: "expected key=value format".to_string(),
            }
        })?;

        match key.trim() {
            "host" => host = Some(value.trim().to_string()),
            "port" => {
                let p: u16 = value.trim().parse().map_err(|_| ConfigError::InvalidValue {
                    field: "port".to_string(),
                    reason: "must be a number between 1 and 65535".to_string(),
                })?;
                port = Some(p);
            }
            "max_connections" => {
                let n: usize = value.trim().parse()?;
                max_connections = Some(n);
            }
            _ => {}
        }
    }

    Ok(Config {
        host: host.ok_or_else(|| ConfigError::MissingField("host".to_string()))?,
        port: port.ok_or_else(|| ConfigError::MissingField("port".to_string()))?,
        max_connections: max_connections.unwrap_or(10),
    })
}

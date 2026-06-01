pub struct Config {
    pub host: String,
    pub port: u16,
    pub max_connections: usize,
}

pub fn parse_config(raw: &str) -> Config {
    let mut host = String::new();
    let mut port: u16 = 0;
    let mut max_connections: usize = 10;

    for line in raw.lines() {
        let line = line.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }

        // Panics if line has no '=' separator — caller cannot recover
        let parts: Vec<&str> = line.splitn(2, '=').collect();
        if parts.len() != 2 {
            panic!("malformed config line: {line}");
        }

        let key = parts[0].trim();
        let value = parts[1].trim();

        match key {
            "host" => host = value.to_string(),
            "port" => {
                // Panics on invalid port — even a typo in the config file crashes
                port = value.parse().unwrap();
            }
            "max_connections" => {
                max_connections = value.parse().unwrap();
            }
            _ => {}
        }
    }

    if host.is_empty() {
        // Missing config key is recoverable but we panic anyway
        panic!("config missing required field: host");
    }

    if port == 0 {
        panic!("config missing required field: port");
    }

    Config { host, port, max_connections }
}

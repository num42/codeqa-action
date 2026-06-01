// Bad: assert!(result.is_ok()) discards the error — failures show no useful info

fn validate_email(email: &str) -> Result<(), String> {
    if email.contains('@') && email.contains('.') {
        Ok(())
    } else {
        Err(format!("'{email}' is not a valid email address"))
    }
}

fn parse_port(s: &str) -> Result<u16, String> {
    s.parse::<u16>().map_err(|e| format!("invalid port '{s}': {e}"))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn valid_email_passes() {
        // Failure output: "assertion failed" — no indication of what went wrong
        assert!(validate_email("user@example.com").is_ok());
    }

    #[test]
    fn invalid_email_returns_error() {
        // Only checks that it's an Err — cannot see the actual message
        assert!(validate_email("not-an-email").is_err());
    }

    #[test]
    fn valid_port_parses() {
        let result = parse_port("8080");
        // We know it's Ok but cannot verify the actual parsed value
        assert!(result.is_ok());
    }

    #[test]
    fn non_numeric_port_returns_error() {
        // Cannot inspect what error was returned
        assert!(parse_port("abc").is_err());
    }

    #[test]
    fn edge_case_port() {
        // If this fails, we see nothing about what parse_port returned
        assert!(parse_port("65535").is_ok());
        assert!(parse_port("65536").is_err());
    }
}

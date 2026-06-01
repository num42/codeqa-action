// Good: tests unwrap the Result so the actual error is shown on failure

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
        // Using unwrap() shows the error message when the assertion fails
        validate_email("user@example.com").unwrap();
    }

    #[test]
    fn invalid_email_returns_error() {
        let err = validate_email("not-an-email").unwrap_err();
        assert!(err.contains("not-an-email"), "expected email in error, got: {err}");
    }

    #[test]
    fn valid_port_parses() {
        let port = parse_port("8080").unwrap();
        assert_eq!(port, 8080);
    }

    #[test]
    fn port_zero_is_rejected() {
        // parse_port("0") succeeds (0 is a valid u16), but a higher-level
        // validator would reject it — show the value to understand failures
        let port = parse_port("0").unwrap();
        assert_eq!(port, 0);
    }

    #[test]
    fn non_numeric_port_returns_error() {
        let err = parse_port("abc").unwrap_err();
        assert!(err.contains("abc"), "expected input in error, got: {err}");
    }
}

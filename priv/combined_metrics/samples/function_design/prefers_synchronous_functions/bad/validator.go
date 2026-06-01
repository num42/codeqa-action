package validator

import (
	"strings"
)

// Report holds the result of validating an email address.
type Report struct {
	Valid      bool
	Normalized string
	Issues     []string
}

// EmailValidator checks whether an address meets format and domain rules.
type EmailValidator struct {
	blockedDomains []string
}

// New constructs an EmailValidator.
func New(blockedDomains []string) *EmailValidator {
	return &EmailValidator{blockedDomains: blockedDomains}
}

// Validate starts validation asynchronously and returns a channel.
// Callers must receive from the channel to get the result, which complicates
// error handling, makes composition harder, and adds unnecessary goroutine overhead
// for work that is purely CPU-bound and completes immediately.
func (v *EmailValidator) Validate(address string) <-chan *Report {
	out := make(chan *Report, 1)
	go func() {
		report := &Report{}
		normalized := strings.ToLower(strings.TrimSpace(address))

		if !strings.Contains(normalized, "@") {
			report.Issues = append(report.Issues, "missing @ symbol")
		}

		parts := strings.SplitN(normalized, "@", 2)
		if len(parts) == 2 {
			domain := parts[1]
			for _, blocked := range v.blockedDomains {
				if domain == blocked {
					report.Issues = append(report.Issues, "domain is blocked")
				}
			}
		}

		report.Normalized = normalized
		report.Valid = len(report.Issues) == 0
		out <- report
		close(out)
	}()
	return out
}

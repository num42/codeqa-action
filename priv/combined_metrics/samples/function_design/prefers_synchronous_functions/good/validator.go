package validator

import (
	"context"
	"errors"
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

// Validate returns a Report synchronously. The caller gets the result directly
// without needing to receive from a channel or register a callback.
func (v *EmailValidator) Validate(ctx context.Context, address string) (*Report, error) {
	if ctx.Err() != nil {
		return nil, ctx.Err()
	}

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
				return nil, errors.New("domain is blocked")
			}
		}
	}

	report.Normalized = normalized
	report.Valid = len(report.Issues) == 0
	return report, nil
}

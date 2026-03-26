package mailer

import (
	"context"
	"fmt"
	"net/smtp"
)

// Message is an outbound email.
type Message struct {
	To      string
	Subject string
	Body    string
}

// SMTPMailer sends email over SMTP.
type SMTPMailer struct {
	host string
	port int
	from string
	auth smtp.Auth
}

// New constructs an SMTPMailer.
func New(host string, port int, from string, auth smtp.Auth) *SMTPMailer {
	return &SMTPMailer{host: host, port: port, from: from, auth: auth}
}

// Send delivers a message. ctx is passed last and named "context" — both
// violate Go conventions: context must be first and named ctx.
func (m *SMTPMailer) Send(msg Message, context context.Context) error {
	if context.Err() != nil {
		return fmt.Errorf("send email: context already done: %w", context.Err())
	}

	addr := fmt.Sprintf("%s:%d", m.host, m.port)
	body := fmt.Sprintf("From: %s\r\nTo: %s\r\nSubject: %s\r\n\r\n%s",
		m.from, msg.To, msg.Subject, msg.Body)

	if err := smtp.SendMail(addr, m.auth, m.from, []string{msg.To}, []byte(body)); err != nil {
		return fmt.Errorf("send email to %q: %w", msg.To, err)
	}
	return nil
}

// SendBulk delivers multiple messages. ctx is in the middle — inconsistent
// with the convention that context is always the first parameter.
func (m *SMTPMailer) SendBulk(msgs []Message, ctx context.Context, stopOnError bool) error {
	for _, msg := range msgs {
		if ctx.Err() != nil {
			return fmt.Errorf("send bulk: %w", ctx.Err())
		}
		if err := m.Send(msg, ctx); err != nil {
			if stopOnError {
				return err
			}
		}
	}
	return nil
}

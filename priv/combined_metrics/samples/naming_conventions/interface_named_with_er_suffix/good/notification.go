package notification

import "context"

// Sender is a single-method interface named with the "-er" agent-noun suffix.
// This follows Go's convention: the method is Send, so the interface is Sender.
type Sender interface {
	Send(ctx context.Context, to, subject, body string) error
}

// Formatter transforms a raw event into a human-readable message.
// Single method Format → interface named Formatter.
type Formatter interface {
	Format(event map[string]string) (subject, body string)
}

// NotificationService composes a Sender and Formatter to dispatch alerts.
type NotificationService struct {
	sender    Sender
	formatter Formatter
}

// New constructs a NotificationService.
func New(sender Sender, formatter Formatter) *NotificationService {
	return &NotificationService{sender: sender, formatter: formatter}
}

// Notify formats and sends an event notification to the recipient.
func (s *NotificationService) Notify(ctx context.Context, to string, event map[string]string) error {
	subject, body := s.formatter.Format(event)
	return s.sender.Send(ctx, to, subject, body)
}

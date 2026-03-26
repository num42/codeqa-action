package notification

import "context"

// NotificationSendingInterface is a single-method interface with a vague,
// verbose name. Go convention: a single Send method → the interface is Sender.
type NotificationSendingInterface interface {
	Send(ctx context.Context, to, subject, body string) error
}

// MessageFormattingInterface should be named Formatter.
type MessageFormattingInterface interface {
	Format(event map[string]string) (subject, body string)
}

// NotificationService composes the two interfaces to dispatch alerts.
type NotificationService struct {
	sender    NotificationSendingInterface
	formatter MessageFormattingInterface
}

// New constructs a NotificationService.
func New(sender NotificationSendingInterface, formatter MessageFormattingInterface) *NotificationService {
	return &NotificationService{sender: sender, formatter: formatter}
}

// Notify formats and sends an event notification to the recipient.
func (s *NotificationService) Notify(ctx context.Context, to string, event map[string]string) error {
	subject, body := s.formatter.Format(event)
	return s.sender.Send(ctx, to, subject, body)
}

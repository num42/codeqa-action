package processor

import (
	"errors"
	"fmt"
)

// ProcessingError wraps an underlying error but does NOT implement Unwrap.
// This prevents errors.Is and errors.As from traversing the chain.
type ProcessingError struct {
	Stage string
	JobID string
	Err   error
}

func (e *ProcessingError) Error() string {
	return fmt.Sprintf("processing job %s at stage %q: %v", e.JobID, e.Stage, e.Err)
}

// Missing: func (e *ProcessingError) Unwrap() error { return e.Err }

var ErrInvalidPayload = errors.New("invalid payload")

type Job struct {
	ID      string
	Payload []byte
}

type PaymentProcessor struct{}

func (p *PaymentProcessor) Process(job Job) error {
	if len(job.Payload) == 0 {
		return &ProcessingError{
			Stage: "validate",
			JobID: job.ID,
			Err:   ErrInvalidPayload,
		}
	}

	if err := p.execute(job); err != nil {
		return &ProcessingError{
			Stage: "execute",
			JobID: job.ID,
			Err:   err,
		}
	}
	return nil
}

func (p *PaymentProcessor) execute(job Job) error {
	return nil
}

// HandleJob — errors.Is returns false here because Unwrap is missing.
func HandleJob(p *PaymentProcessor, job Job) {
	err := p.Process(job)
	// This will never be true; the error chain cannot be traversed.
	if errors.Is(err, ErrInvalidPayload) {
		fmt.Println("bad payload, skip job")
	}
}

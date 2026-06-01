package processor

import (
	"errors"
	"fmt"
)

// ProcessingError wraps an underlying error and adds the stage at which it occurred.
// It implements Unwrap so errors.Is and errors.As can traverse the chain.
type ProcessingError struct {
	Stage string
	JobID string
	Err   error
}

func (e *ProcessingError) Error() string {
	return fmt.Sprintf("processing job %s at stage %q: %v", e.JobID, e.Stage, e.Err)
}

// Unwrap allows errors.Is and errors.As to inspect the wrapped error.
func (e *ProcessingError) Unwrap() error { return e.Err }

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
	// simulate execution
	return nil
}

// HandleJob demonstrates that errors.Is works through ProcessingError.Unwrap.
func HandleJob(p *PaymentProcessor, job Job) {
	err := p.Process(job)
	if errors.Is(err, ErrInvalidPayload) {
		// reachable because ProcessingError implements Unwrap
		fmt.Println("bad payload, skip job")
	}
}

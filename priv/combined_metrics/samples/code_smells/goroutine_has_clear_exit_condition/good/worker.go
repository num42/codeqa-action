package worker

import (
	"context"
	"log"
	"time"
)

type EmailJob struct {
	To      string
	Subject string
	Body    string
}

type Mailer interface {
	Send(job EmailJob) error
}

// EmailWorker drains jobs from a channel until the context is cancelled.
// The goroutine has a clear exit condition: ctx.Done().
type EmailWorker struct {
	mailer Mailer
	jobs   <-chan EmailJob
	logger *log.Logger
}

func NewEmailWorker(mailer Mailer, jobs <-chan EmailJob, logger *log.Logger) *EmailWorker {
	return &EmailWorker{mailer: mailer, jobs: jobs, logger: logger}
}

// Run starts the worker and blocks until ctx is cancelled or jobs is closed.
func (w *EmailWorker) Run(ctx context.Context) {
	for {
		select {
		case <-ctx.Done():
			// Clear exit: context cancelled — drain stops.
			w.logger.Println("email worker shutting down")
			return
		case job, ok := <-w.jobs:
			if !ok {
				// Clear exit: channel closed — no more work.
				w.logger.Println("jobs channel closed, email worker exiting")
				return
			}
			if err := w.mailer.Send(job); err != nil {
				w.logger.Printf("failed to send email to %s: %v", job.To, err)
			}
		case <-time.After(30 * time.Second):
			w.logger.Println("email worker idle heartbeat")
		}
	}
}

package worker

import (
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

// EmailWorker drains jobs from a channel.
// The goroutine has no exit condition — it leaks forever.
type EmailWorker struct {
	mailer Mailer
	jobs   <-chan EmailJob
	logger *log.Logger
}

func NewEmailWorker(mailer Mailer, jobs <-chan EmailJob, logger *log.Logger) *EmailWorker {
	return &EmailWorker{mailer: mailer, jobs: jobs, logger: logger}
}

// Run starts the worker in a goroutine with no way to stop it.
func (w *EmailWorker) Run() {
	// No context, no stop channel — this goroutine runs forever with no exit path.
	go func() {
		for {
			select {
			case job := <-w.jobs:
				if err := w.mailer.Send(job); err != nil {
					w.logger.Printf("failed to send email to %s: %v", job.To, err)
				}
			default:
				time.Sleep(100 * time.Millisecond)
			}
		}
	}()
}

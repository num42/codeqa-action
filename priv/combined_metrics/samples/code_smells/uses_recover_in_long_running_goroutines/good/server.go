package server

import (
	"context"
	"log"
	"time"
)

type Task struct {
	ID      string
	Payload string
}

type Executor interface {
	Execute(ctx context.Context, task Task) error
}

// TaskServer runs tasks continuously and recovers from panics so the process stays alive.
type TaskServer struct {
	executor Executor
	tasks    <-chan Task
	logger   *log.Logger
}

func New(executor Executor, tasks <-chan Task, logger *log.Logger) *TaskServer {
	return &TaskServer{executor: executor, tasks: tasks, logger: logger}
}

// Run starts the task processing loop. It recovers from panics within each iteration.
func (s *TaskServer) Run(ctx context.Context) {
	for {
		select {
		case <-ctx.Done():
			s.logger.Println("task server shutting down")
			return
		case task, ok := <-s.tasks:
			if !ok {
				return
			}
			s.processWithRecover(ctx, task)
		}
	}
}

// processWithRecover wraps task execution in a deferred recover so a panic in
// Execute cannot crash the entire server process.
func (s *TaskServer) processWithRecover(ctx context.Context, task Task) {
	defer func() {
		if r := recover(); r != nil {
			s.logger.Printf("panic processing task %s: %v — continuing", task.ID, r)
			time.Sleep(100 * time.Millisecond) // brief back-off after panic
		}
	}()

	if err := s.executor.Execute(ctx, task); err != nil {
		s.logger.Printf("task %s failed: %v", task.ID, err)
	}
}

package server

import (
	"context"
	"log"
)

type Task struct {
	ID      string
	Payload string
}

type Executor interface {
	Execute(ctx context.Context, task Task) error
}

// TaskServer runs tasks continuously but does not recover from panics.
// A single panic in Execute will crash the entire process.
type TaskServer struct {
	executor Executor
	tasks    <-chan Task
	logger   *log.Logger
}

func New(executor Executor, tasks <-chan Task, logger *log.Logger) *TaskServer {
	return &TaskServer{executor: executor, tasks: tasks, logger: logger}
}

// Run starts the task processing loop with no panic recovery.
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
			// No recover — a panic inside Execute terminates the process.
			if err := s.executor.Execute(ctx, task); err != nil {
				s.logger.Printf("task %s failed: %v", task.ID, err)
			}
		}
	}
}

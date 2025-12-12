package service

import (
	"context"
	"log"
	"sync"
)

// TaskContext holds context for a running task
type TaskContext struct {
	ProjectID uint
	Cancel    context.CancelFunc
	Done      chan struct{}
	Ctx       context.Context
}

// TaskManager manages background PSD processing tasks
type TaskManager struct {
	mu    sync.RWMutex
	tasks map[uint]*TaskContext
}

// NewTaskManager creates a new task manager
func NewTaskManager() *TaskManager {
	return &TaskManager{
		tasks: make(map[uint]*TaskContext),
	}
}

// StartTask starts a new background task
func (tm *TaskManager) StartTask(projectID uint, taskFunc func(context.Context) error) {
	tm.mu.Lock()
	defer tm.mu.Unlock()

	// Cancel existing task if any
	if existing, ok := tm.tasks[projectID]; ok {
		existing.Cancel()
		<-existing.Done // Wait for it to finish
	}

	// Create new task context
	ctx, cancel := context.WithCancel(context.Background())
	tc := &TaskContext{
		ProjectID: projectID,
		Cancel:    cancel,
		Done:      make(chan struct{}),
		Ctx:       ctx,
	}
	tm.tasks[projectID] = tc

	// Start task in goroutine
	go func() {
		defer close(tc.Done)
		defer func() {
			tm.mu.Lock()
			delete(tm.tasks, projectID)
			tm.mu.Unlock()
		}()

		if err := taskFunc(ctx); err != nil {
			if ctx.Err() == nil { // Only log if not cancelled
				log.Printf("Task failed for project %d: %v\n", projectID, err)
			}
		}
	}()
}

// StopTask stops a running task
func (tm *TaskManager) StopTask(projectID uint) bool {
	tm.mu.Lock()
	tc, exists := tm.tasks[projectID]
	tm.mu.Unlock()

	if !exists {
		return false
	}

	tc.Cancel()
	<-tc.Done // Wait for task to finish
	return true
}

// IsRunning checks if a task is running
func (tm *TaskManager) IsRunning(projectID uint) bool {
	tm.mu.RLock()
	defer tm.mu.RUnlock()
	_, exists := tm.tasks[projectID]
	return exists
}

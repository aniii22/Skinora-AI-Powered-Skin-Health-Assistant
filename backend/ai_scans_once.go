package main

import (
	"context"
	"sync/atomic"
)

var aiScansReady atomic.Bool

// ensureAIScans creates the ai_scans table once; later calls return at once.
func (a *App) ensureAIScans(ctx context.Context) error {
	if aiScansReady.Load() {
		return nil
	}
	err := a.createAIScansTable(ctx)
	if err == nil {
		aiScansReady.Store(true)
	}
	return err
}

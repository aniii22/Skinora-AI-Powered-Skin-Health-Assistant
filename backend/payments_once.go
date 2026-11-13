package main

import (
	"context"
	"sync/atomic"
)

var paymentsReady atomic.Bool

// ensurePaymentsTable creates/alters the payments table once; later calls return at once.
func (a *App) ensurePaymentsTable(ctx context.Context) error {
	if paymentsReady.Load() {
		return nil
	}
	err := a.createPaymentsTable(ctx)
	if err == nil {
		paymentsReady.Store(true)
	}
	return err
}

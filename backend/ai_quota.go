package main

import (
	"context"
	"log"
	"time"
)

// reserveAIScan checks the quota and records the scan slot in one transaction.
// A per-user advisory lock makes the check and the insert atomic, so the limit
// holds even without the in-memory aiInFlight map (restarts, many instances).
// lifetime=true counts all scans ever (free plan); false counts this month.
func (a *App) reserveAIScan(ctx context.Context, uid any, lifetime bool, limit int) (int64, bool, error) {
	tx, err := a.db.Begin(ctx)
	if err != nil {
		return 0, false, err
	}
	defer tx.Rollback(ctx)
	if _, err := tx.Exec(ctx, `SELECT pg_advisory_xact_lock($1)`, uid); err != nil {
		return 0, false, err
	}
	var used int
	if err := tx.QueryRow(ctx,
		`SELECT COUNT(*)::int FROM ai_scans WHERE user_id = $1 AND ($2::bool OR created_at >= date_trunc('month', now()))`,
		uid, lifetime).Scan(&used); err != nil {
		return 0, false, err
	}
	if used >= limit {
		return 0, false, nil
	}
	var id int64
	if err := tx.QueryRow(ctx, `INSERT INTO ai_scans (user_id) VALUES ($1) RETURNING id`, uid).Scan(&id); err != nil {
		return 0, false, err
	}
	if err := tx.Commit(ctx); err != nil {
		return 0, false, err
	}
	return id, true, nil
}

// releaseAIScan gives a reserved slot back when the scan did not complete.
func (a *App) releaseAIScan(id int64) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if _, err := a.db.Exec(ctx, `DELETE FROM ai_scans WHERE id = $1`, id); err != nil {
		log.Printf("could not release ai scan slot: %v", err)
	}
}

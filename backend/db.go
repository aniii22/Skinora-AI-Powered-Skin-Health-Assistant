package main

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type App struct {
	db  *pgxpool.Pool
	cfg Config
	lim *limiter
}

// openDB connects to PostgreSQL. All Skinora tables live in their own
// "skinora" schema so they never collide with other tables.
func openDB(ctx context.Context, url string) (*pgxpool.Pool, error) {
	cfg, err := pgxpool.ParseConfig(url)
	if err != nil {
		return nil, errors.New("DATABASE_URL is not a valid connection string")
	}
	cfg.AfterConnect = func(ctx context.Context, c *pgx.Conn) error {
		if _, err := c.Exec(ctx, "CREATE SCHEMA IF NOT EXISTS skinora"); err != nil {
			return err
		}
		_, err := c.Exec(ctx, "SET search_path TO skinora, public")
		return err
	}
	pool, err := pgxpool.NewWithConfig(ctx, cfg)
	if err != nil {
		return nil, err
	}
	pctx, cancel := context.WithTimeout(ctx, 8*time.Second)
	defer cancel()
	if err := pool.Ping(pctx); err != nil {
		pool.Close()
		return nil, fmt.Errorf("cannot connect to database: %w", err)
	}
	return pool, nil
}

// Every statement is idempotent. Rows created before accounts existed
// (user_id IS NULL) are test data and are removed once.
var schemaStatements = []string{
	`CREATE TABLE IF NOT EXISTS users (
		id BIGSERIAL PRIMARY KEY,
		email TEXT NOT NULL UNIQUE,
		name TEXT NOT NULL,
		password_hash TEXT NOT NULL,
		plan TEXT NOT NULL DEFAULT 'free' CHECK (plan IN ('free','premium')),
		premium_until TIMESTAMPTZ,
		created_at TIMESTAMPTZ NOT NULL DEFAULT now()
	)`,
	`CREATE TABLE IF NOT EXISTS sessions (
		token_hash TEXT PRIMARY KEY,
		user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
		expires_at TIMESTAMPTZ NOT NULL,
		created_at TIMESTAMPTZ NOT NULL DEFAULT now()
	)`,
	`CREATE INDEX IF NOT EXISTS idx_sessions_user ON sessions(user_id)`,
	`CREATE TABLE IF NOT EXISTS user_profiles (
		user_id BIGINT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
		display_name TEXT NOT NULL DEFAULT '',
		skin_type TEXT NOT NULL DEFAULT '',
		concerns TEXT[] NOT NULL DEFAULT '{}',
		sensitive BOOLEAN NOT NULL DEFAULT FALSE,
		updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
	)`,
	`CREATE TABLE IF NOT EXISTS user_settings (
		user_id BIGINT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
		water_goal_ml INT NOT NULL DEFAULT 5000 CHECK (water_goal_ml BETWEEN 500 AND 10000),
		glass_ml INT NOT NULL DEFAULT 250 CHECK (glass_ml BETWEEN 50 AND 1000)
	)`,
	`CREATE TABLE IF NOT EXISTS routine_items (
		id BIGSERIAL PRIMARY KEY,
		period TEXT NOT NULL CHECK (period IN ('morning','evening')),
		title TEXT NOT NULL,
		sort_order INT NOT NULL DEFAULT 0,
		created_at TIMESTAMPTZ NOT NULL DEFAULT now()
	)`,
	`CREATE TABLE IF NOT EXISTS routine_completions (
		item_id BIGINT NOT NULL REFERENCES routine_items(id) ON DELETE CASCADE,
		day DATE NOT NULL,
		PRIMARY KEY (item_id, day)
	)`,
	`CREATE INDEX IF NOT EXISTS idx_routine_completions_day ON routine_completions(day)`,
	`CREATE TABLE IF NOT EXISTS water_logs (
		id BIGSERIAL PRIMARY KEY,
		day DATE NOT NULL,
		amount_ml INT NOT NULL CHECK (amount_ml > 0),
		created_at TIMESTAMPTZ NOT NULL DEFAULT now()
	)`,
	`CREATE TABLE IF NOT EXISTS sleep_logs (
		id BIGSERIAL PRIMARY KEY,
		sleep_start TIMESTAMPTZ NOT NULL,
		wake_time TIMESTAMPTZ NOT NULL,
		created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
		CHECK (wake_time > sleep_start)
	)`,
	`CREATE TABLE IF NOT EXISTS journal_entries (
		id BIGSERIAL PRIMARY KEY,
		day DATE NOT NULL,
		notes TEXT NOT NULL DEFAULT '',
		rating SMALLINT CHECK (rating BETWEEN 1 AND 5),
		photo_file TEXT,
		created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
		updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
	)`,

	`ALTER TABLE routine_items ADD COLUMN IF NOT EXISTS user_id BIGINT REFERENCES users(id) ON DELETE CASCADE`,
	`DELETE FROM routine_items WHERE user_id IS NULL`,
	`ALTER TABLE routine_items ALTER COLUMN user_id SET NOT NULL`,
	`ALTER TABLE water_logs ADD COLUMN IF NOT EXISTS user_id BIGINT REFERENCES users(id) ON DELETE CASCADE`,
	`DELETE FROM water_logs WHERE user_id IS NULL`,
	`ALTER TABLE water_logs ALTER COLUMN user_id SET NOT NULL`,
	`ALTER TABLE sleep_logs ADD COLUMN IF NOT EXISTS user_id BIGINT REFERENCES users(id) ON DELETE CASCADE`,
	`DELETE FROM sleep_logs WHERE user_id IS NULL`,
	`ALTER TABLE sleep_logs ALTER COLUMN user_id SET NOT NULL`,
	`ALTER TABLE journal_entries ADD COLUMN IF NOT EXISTS user_id BIGINT REFERENCES users(id) ON DELETE CASCADE`,
	`DELETE FROM journal_entries WHERE user_id IS NULL`,
	`ALTER TABLE journal_entries ALTER COLUMN user_id SET NOT NULL`,

	`CREATE INDEX IF NOT EXISTS idx_routine_items_user ON routine_items(user_id)`,
	`CREATE INDEX IF NOT EXISTS idx_water_logs_user_day ON water_logs(user_id, day)`,
	`CREATE INDEX IF NOT EXISTS idx_sleep_logs_user_wake ON sleep_logs(user_id, wake_time DESC)`,
	`CREATE INDEX IF NOT EXISTS idx_journal_user_day ON journal_entries(user_id, day DESC)`,

	`ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS photo_file TEXT`,
	`ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS gender TEXT NOT NULL DEFAULT ''`,
	`ALTER TABLE user_settings ALTER COLUMN water_goal_ml SET DEFAULT 5000`,
	`UPDATE user_settings SET water_goal_ml = 5000 WHERE water_goal_ml > 5000`,
	`ALTER TABLE user_settings DROP CONSTRAINT IF EXISTS user_settings_water_goal_ml_check`,
	`ALTER TABLE user_settings DROP CONSTRAINT IF EXISTS user_settings_water_goal_range`,
	`ALTER TABLE user_settings ADD CONSTRAINT user_settings_water_goal_range CHECK (water_goal_ml BETWEEN 500 AND 5000)`,
	`UPDATE user_settings SET water_goal_ml = 5000 WHERE water_goal_ml = 2000`,
	`UPDATE user_settings SET water_goal_ml = 5000 WHERE water_goal_ml > 5000`,
	`DROP TABLE IF EXISTS skin_profile`,
	`DROP TABLE IF EXISTS app_settings`,
}

func migrate(ctx context.Context, pool *pgxpool.Pool) error {
	for _, s := range schemaStatements {
		if _, err := pool.Exec(ctx, s); err != nil {
			return fmt.Errorf("migration failed: %w", err)
		}
	}
	return nil
}

var defaultRoutine = []struct{ period, title string }{
	{"morning", "Gentle cleanser"},
	{"morning", "Moisturizer"},
	{"morning", "Sunscreen"},
	{"evening", "Evening cleanse"},
	{"evening", "Moisturizer"},
}

// seedRoutine gives a new account a starter routine (called once, at sign-up).
func seedRoutine(ctx context.Context, tx pgx.Tx, uid int64) error {
	for i, d := range defaultRoutine {
		if _, err := tx.Exec(ctx,
			`INSERT INTO routine_items (user_id, period, title, sort_order) VALUES ($1, $2, $3, $4)`,
			uid, d.period, d.title, i+1); err != nil {
			return err
		}
	}
	return nil
}

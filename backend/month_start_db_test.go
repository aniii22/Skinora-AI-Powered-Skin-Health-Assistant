package main

import (
	"context"
	"os"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

// Runs monthStartSQL on a real Postgres and compares with Go's own idea of
// "start of this month" in the user's zone. reserveAIScan counts quota with
// this same expression. Skipped unless TEST_DATABASE_URL is set.
func TestMonthStartSQLMatchesGoZones(t *testing.T) {
	url := os.Getenv("TEST_DATABASE_URL")
	if url == "" {
		t.Skip("TEST_DATABASE_URL not set")
	}
	ctx := context.Background()
	pool, err := pgxpool.New(ctx, url)
	if err != nil {
		t.Fatal(err)
	}
	defer pool.Close()

	for _, zone := range []string{"Asia/Kolkata", "Pacific/Auckland", "UTC", "America/Los_Angeles"} {
		loc, err := time.LoadLocation(zone)
		if err != nil {
			t.Fatal(err)
		}
		var got time.Time
		if err := pool.QueryRow(ctx, `SELECT `+monthStartSQL(1), zone).Scan(&got); err != nil {
			t.Fatalf("%s: %v", zone, err)
		}
		n := time.Now().In(loc)
		want := time.Date(n.Year(), n.Month(), 1, 0, 0, 0, 0, loc)
		if !got.Equal(want) {
			t.Errorf("%s: month start = %v, want %v", zone, got, want)
		}
	}

	// Kolkata and Auckland must not share a month start unless both
	// zones are in the same month at the same moment and offsets agree.
	var kol, auc time.Time
	_ = pool.QueryRow(ctx, `SELECT `+monthStartSQL(1), "Asia/Kolkata").Scan(&kol)
	_ = pool.QueryRow(ctx, `SELECT `+monthStartSQL(1), "Pacific/Auckland").Scan(&auc)
	if kol.Equal(auc) {
		t.Errorf("Kolkata and Auckland month starts are identical: %v", kol)
	}
}

package main

import (
	"context"
	"log"
)

// purgeExtraUserData removes notifications, reminders and notification prefs
// for "Delete my data". Best effort: errors are logged, never returned.
// ai_scans is kept on purpose so the free scan quota cannot be reset.
func (a *App) purgeExtraUserData(ctx context.Context, uid int64) {
	for _, s := range []string{
		`DELETE FROM notifications WHERE user_id = $1`,
		`DELETE FROM reminders WHERE user_id = $1`,
		`DELETE FROM notification_prefs WHERE user_id = $1`,
	} {
		if _, err := a.db.Exec(ctx, s, uid); err != nil {
			log.Printf("purge extra data: %v", err)
		}
	}
}

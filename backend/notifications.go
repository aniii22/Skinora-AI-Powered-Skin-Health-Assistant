package main

import (
	"context"
	"log"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
)

type notificationRow struct {
	ID        int64     `json:"id"`
	Category  string    `json:"category"`
	Title     string    `json:"title"`
	Body      string    `json:"body"`
	IsRead    bool      `json:"is_read"`
	CreatedAt time.Time `json:"created_at"`
}

// registerNotificationRoutes creates the table (if needed) and adds the routes.
func registerNotificationRoutes(p *gin.RouterGroup, a *App) {
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	if _, err := a.db.Exec(ctx, `CREATE TABLE IF NOT EXISTS notifications (
        id BIGSERIAL PRIMARY KEY,
        user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        category TEXT NOT NULL DEFAULT 'general' CHECK (category IN ('water','skincare','routine','task','premium','general')),
        title TEXT NOT NULL,
        body TEXT NOT NULL DEFAULT '',
        is_read BOOLEAN NOT NULL DEFAULT FALSE,
        created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )`); err != nil {
		log.Printf("notifications table: %v", err)
	}
	if _, err := a.db.Exec(ctx, `CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id, created_at DESC)`); err != nil {
		log.Printf("notifications index: %v", err)
	}

	p.GET("/notifications", a.listNotifications)
	p.POST("/notifications/read-all", a.readAllNotifications)
	p.PUT("/notifications/:id/read", a.readNotification)
	p.DELETE("/notifications", a.clearNotifications)
}

// addNotification stores a notification for one user (used by reminders later).
func (a *App) addNotification(ctx context.Context, uid int64, category, title, body string) error {
	_, err := a.db.Exec(ctx,
		`INSERT INTO notifications (user_id, category, title, body) VALUES ($1,$2,$3,$4)`,
		uid, category, title, body)
	return err
}

func (a *App) listNotifications(c *gin.Context) {
	uid := curUser(c).ID
	rows, err := a.db.Query(c.Request.Context(),
		`SELECT id, category, title, body, is_read, created_at
         FROM notifications WHERE user_id = $1
         ORDER BY created_at DESC, id DESC LIMIT 100`, uid)
	if err != nil {
		serverError(c, err)
		return
	}
	defer rows.Close()
	items := []notificationRow{}
	for rows.Next() {
		var n notificationRow
		if err := rows.Scan(&n.ID, &n.Category, &n.Title, &n.Body, &n.IsRead, &n.CreatedAt); err != nil {
			serverError(c, err)
			return
		}
		items = append(items, n)
	}
	if err := rows.Err(); err != nil {
		serverError(c, err)
		return
	}
	var unread int
	if err := a.db.QueryRow(c.Request.Context(),
		`SELECT COUNT(*) FROM notifications WHERE user_id = $1 AND NOT is_read`, uid).Scan(&unread); err != nil {
		serverError(c, err)
		return
	}
	respond(c, http.StatusOK, gin.H{"items": items, "unread": unread})
}

func (a *App) readNotification(c *gin.Context) {
	id, ok := idParam(c)
	if !ok {
		return
	}
	tag, err := a.db.Exec(c.Request.Context(),
		`UPDATE notifications SET is_read = TRUE WHERE id = $1 AND user_id = $2`, id, curUser(c).ID)
	if err != nil {
		serverError(c, err)
		return
	}
	if tag.RowsAffected() == 0 {
		fail(c, http.StatusNotFound, "notification not found")
		return
	}
	respond(c, http.StatusOK, gin.H{"ok": true})
}

func (a *App) readAllNotifications(c *gin.Context) {
	if _, err := a.db.Exec(c.Request.Context(),
		`UPDATE notifications SET is_read = TRUE WHERE user_id = $1 AND NOT is_read`, curUser(c).ID); err != nil {
		serverError(c, err)
		return
	}
	respond(c, http.StatusOK, gin.H{"ok": true})
}

func (a *App) clearNotifications(c *gin.Context) {
	if _, err := a.db.Exec(c.Request.Context(),
		`DELETE FROM notifications WHERE user_id = $1`, curUser(c).ID); err != nil {
		serverError(c, err)
		return
	}
	respond(c, http.StatusOK, gin.H{"ok": true})
}

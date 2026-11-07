package main

import (
	"context"
	"errors"
	"fmt"
	"log"
	"net/http"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5"
)

var hhmmRe = regexp.MustCompile(`^([01][0-9]|2[0-3]):[0-5][0-9]$`)
var reminderOnce sync.Once

type reminderRow struct {
	ID      int64  `json:"id"`
	Kind    string `json:"kind"`
	Title   string `json:"title"`
	Time    string `json:"time"`
	Days    int    `json:"days"`
	Enabled bool   `json:"enabled"`
}

type notifPrefs struct {
	AllEnabled   bool   `json:"all_enabled"`
	QuietEnabled bool   `json:"quiet_enabled"`
	QuietStart   string `json:"quiet_start"`
	QuietEnd     string `json:"quiet_end"`
	TzOffsetMin  int    `json:"tz_offset_min"`
}

type reminderIn struct {
	Kind    string `json:"kind"`
	Title   string `json:"title"`
	Time    string `json:"time"`
	Days    int    `json:"days"`
	Enabled *bool  `json:"enabled"`
}

func (in *reminderIn) validate() string {
	in.Kind = strings.TrimSpace(in.Kind)
	in.Title = strings.TrimSpace(in.Title)
	switch in.Kind {
	case "water", "morning", "evening", "custom":
	default:
		return "invalid reminder type"
	}
	if !hhmmRe.MatchString(in.Time) {
		return "time must be in HH:MM format"
	}
	if in.Days < 1 || in.Days > 127 {
		return "select at least one day"
	}
	if in.Kind == "custom" && in.Title == "" {
		return "enter a title for the custom reminder"
	}
	if len([]rune(in.Title)) > 60 {
		return "title must be 60 characters or fewer"
	}
	if in.Kind != "custom" {
		in.Title = ""
	}
	return ""
}

func isDup(err error) bool {
	return err != nil && strings.Contains(err.Error(), "23505")
}

func minutesOf(s string) int {
	if len(s) != 5 {
		return 0
	}
	h, _ := strconv.Atoi(s[:2])
	m, _ := strconv.Atoi(s[3:])
	return h*60 + m
}

func inQuiet(nowMin int, start, end string) bool {
	s, e := minutesOf(start), minutesOf(end)
	if s == e {
		return false
	}
	if s < e {
		return nowMin >= s && nowMin < e
	}
	return nowMin >= s || nowMin < e
}

func registerReminderRoutes(p *gin.RouterGroup, a *App) {
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	stmts := []string{
		`CREATE TABLE IF NOT EXISTS reminders (
            id BIGSERIAL PRIMARY KEY,
            user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            kind TEXT NOT NULL CHECK (kind IN ('water','morning','evening','custom')),
            title TEXT NOT NULL DEFAULT '',
            time_of_day TEXT NOT NULL,
            days INT NOT NULL CHECK (days BETWEEN 1 AND 127),
            enabled BOOLEAN NOT NULL DEFAULT TRUE,
            last_fired_on DATE,
            created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
            UNIQUE (user_id, kind, time_of_day, title)
        )`,
		`CREATE INDEX IF NOT EXISTS idx_reminders_user ON reminders(user_id)`,
		`CREATE TABLE IF NOT EXISTS notification_prefs (
            user_id BIGINT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
            all_enabled BOOLEAN NOT NULL DEFAULT TRUE,
            quiet_enabled BOOLEAN NOT NULL DEFAULT FALSE,
            quiet_start TEXT NOT NULL DEFAULT '22:00',
            quiet_end TEXT NOT NULL DEFAULT '07:00',
            tz_offset_min INT NOT NULL DEFAULT 0
        )`,
	}
	for _, s := range stmts {
		if _, err := a.db.Exec(ctx, s); err != nil {
			log.Printf("reminders setup: %v", err)
		}
	}

	p.GET("/reminders", a.listReminders)
	p.POST("/reminders", a.createReminder)
	p.PUT("/reminders/:id", a.updateReminder)
	p.DELETE("/reminders/:id", a.deleteReminder)
	p.PUT("/notification-prefs", a.putPrefs)
	p.POST("/notifications/test", a.testNotification)

	reminderOnce.Do(func() { go a.reminderLoop() })
}

func (a *App) loadPrefs(ctx context.Context, uid int64) (notifPrefs, error) {
	p := notifPrefs{AllEnabled: true, QuietStart: "22:00", QuietEnd: "07:00"}
	err := a.db.QueryRow(ctx,
		`SELECT all_enabled, quiet_enabled, quiet_start, quiet_end, tz_offset_min FROM notification_prefs WHERE user_id = $1`, uid).
		Scan(&p.AllEnabled, &p.QuietEnabled, &p.QuietStart, &p.QuietEnd, &p.TzOffsetMin)
	if errors.Is(err, pgx.ErrNoRows) {
		return p, nil
	}
	return p, err
}

func (a *App) listReminders(c *gin.Context) {
	uid := curUser(c).ID
	rows, err := a.db.Query(c.Request.Context(),
		`SELECT id, kind, title, time_of_day, days, enabled FROM reminders WHERE user_id = $1 ORDER BY time_of_day, id`, uid)
	if err != nil {
		serverError(c, err)
		return
	}
	defer rows.Close()
	items := []reminderRow{}
	for rows.Next() {
		var r reminderRow
		if err := rows.Scan(&r.ID, &r.Kind, &r.Title, &r.Time, &r.Days, &r.Enabled); err != nil {
			serverError(c, err)
			return
		}
		items = append(items, r)
	}
	if err := rows.Err(); err != nil {
		serverError(c, err)
		return
	}
	prefs, err := a.loadPrefs(c.Request.Context(), uid)
	if err != nil {
		serverError(c, err)
		return
	}
	respond(c, http.StatusOK, gin.H{"items": items, "prefs": prefs})
}

func (a *App) createReminder(c *gin.Context) {
	uid := curUser(c).ID
	var in reminderIn
	if err := c.ShouldBindJSON(&in); err != nil {
		fail(c, http.StatusBadRequest, "invalid request body")
		return
	}
	if msg := in.validate(); msg != "" {
		fail(c, http.StatusBadRequest, msg)
		return
	}
	var count int
	if err := a.db.QueryRow(c.Request.Context(), `SELECT COUNT(*) FROM reminders WHERE user_id = $1`, uid).Scan(&count); err != nil {
		serverError(c, err)
		return
	}
	if count >= 20 {
		fail(c, http.StatusBadRequest, "you can have at most 20 reminders")
		return
	}
	enabled := true
	if in.Enabled != nil {
		enabled = *in.Enabled
	}
	var id int64
	err := a.db.QueryRow(c.Request.Context(),
		`INSERT INTO reminders (user_id, kind, title, time_of_day, days, enabled) VALUES ($1,$2,$3,$4,$5,$6) RETURNING id`,
		uid, in.Kind, in.Title, in.Time, in.Days, enabled).Scan(&id)
	if isDup(err) {
		fail(c, http.StatusConflict, "you already have this reminder")
		return
	}
	if err != nil {
		serverError(c, err)
		return
	}
	respond(c, http.StatusCreated, gin.H{"id": id})
}

func (a *App) updateReminder(c *gin.Context) {
	id, ok := idParam(c)
	if !ok {
		return
	}
	var in reminderIn
	if err := c.ShouldBindJSON(&in); err != nil {
		fail(c, http.StatusBadRequest, "invalid request body")
		return
	}
	if msg := in.validate(); msg != "" {
		fail(c, http.StatusBadRequest, msg)
		return
	}
	enabled := true
	if in.Enabled != nil {
		enabled = *in.Enabled
	}
	tag, err := a.db.Exec(c.Request.Context(),
		`UPDATE reminders SET kind=$1, title=$2, time_of_day=$3, days=$4, enabled=$5, last_fired_on=NULL WHERE id=$6 AND user_id=$7`,
		in.Kind, in.Title, in.Time, in.Days, enabled, id, curUser(c).ID)
	if isDup(err) {
		fail(c, http.StatusConflict, "you already have this reminder")
		return
	}
	if err != nil {
		serverError(c, err)
		return
	}
	if tag.RowsAffected() == 0 {
		fail(c, http.StatusNotFound, "reminder not found")
		return
	}
	respond(c, http.StatusOK, gin.H{"ok": true})
}

func (a *App) deleteReminder(c *gin.Context) {
	id, ok := idParam(c)
	if !ok {
		return
	}
	tag, err := a.db.Exec(c.Request.Context(), `DELETE FROM reminders WHERE id = $1 AND user_id = $2`, id, curUser(c).ID)
	if err != nil {
		serverError(c, err)
		return
	}
	if tag.RowsAffected() == 0 {
		fail(c, http.StatusNotFound, "reminder not found")
		return
	}
	respond(c, http.StatusOK, gin.H{"ok": true})
}

func (a *App) putPrefs(c *gin.Context) {
	var in notifPrefs
	if err := c.ShouldBindJSON(&in); err != nil {
		fail(c, http.StatusBadRequest, "invalid request body")
		return
	}
	if !hhmmRe.MatchString(in.QuietStart) || !hhmmRe.MatchString(in.QuietEnd) {
		fail(c, http.StatusBadRequest, "quiet hours must be in HH:MM format")
		return
	}
	if in.TzOffsetMin < -840 || in.TzOffsetMin > 840 {
		fail(c, http.StatusBadRequest, "invalid time zone offset")
		return
	}
	if _, err := a.db.Exec(c.Request.Context(),
		`INSERT INTO notification_prefs (user_id, all_enabled, quiet_enabled, quiet_start, quiet_end, tz_offset_min)
         VALUES ($1,$2,$3,$4,$5,$6)
         ON CONFLICT (user_id) DO UPDATE SET all_enabled=$2, quiet_enabled=$3, quiet_start=$4, quiet_end=$5, tz_offset_min=$6`,
		curUser(c).ID, in.AllEnabled, in.QuietEnabled, in.QuietStart, in.QuietEnd, in.TzOffsetMin); err != nil {
		serverError(c, err)
		return
	}
	respond(c, http.StatusOK, gin.H{"ok": true})
}

func (a *App) testNotification(c *gin.Context) {
	if err := a.addNotification(c.Request.Context(), curUser(c).ID, "general",
		"Test notification", "If you can see this, your notification list is working."); err != nil {
		serverError(c, err)
		return
	}
	respond(c, http.StatusOK, gin.H{"ok": true})
}

type dueRow struct {
	id, uid int64
	kind    string
	title   string
	tod     string
	days    int
	last    *time.Time
	all     bool
	quietOn bool
	qs, qe  string
	off     int
	glass   int
}

func (a *App) reminderLoop() {
	if a == nil || a.db == nil {
		return
	}
	t := time.NewTicker(30 * time.Second)
	defer t.Stop()
	for range t.C {
		a.fireDueReminders()
	}
}

func (a *App) fireDueReminders() {
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	rows, err := a.db.Query(ctx, `
        SELECT r.id, r.user_id, r.kind, r.title, r.time_of_day, r.days, r.last_fired_on,
               COALESCE(p.all_enabled, TRUE), COALESCE(p.quiet_enabled, FALSE),
               COALESCE(p.quiet_start, '22:00'), COALESCE(p.quiet_end, '07:00'),
               COALESCE(p.tz_offset_min, 0), COALESCE(s.glass_ml, 250)
        FROM reminders r
        LEFT JOIN notification_prefs p ON p.user_id = r.user_id
        LEFT JOIN user_settings s ON s.user_id = r.user_id
        WHERE r.enabled`)
	if err != nil {
		log.Printf("reminder scan: %v", err)
		return
	}
	var list []dueRow
	for rows.Next() {
		var d dueRow
		if err := rows.Scan(&d.id, &d.uid, &d.kind, &d.title, &d.tod, &d.days, &d.last,
			&d.all, &d.quietOn, &d.qs, &d.qe, &d.off, &d.glass); err != nil {
			log.Printf("reminder row: %v", err)
			continue
		}
		list = append(list, d)
	}
	rows.Close()

	now := time.Now().UTC()
	for _, d := range list {
		local := now.Add(time.Duration(d.off) * time.Minute)
		nowMin := local.Hour()*60 + local.Minute()
		rMin := minutesOf(d.tod)
		if nowMin < rMin || nowMin-rMin > 5 {
			continue
		}
		if d.days&(1<<((int(local.Weekday())+6)%7)) == 0 {
			continue
		}
		today := time.Date(local.Year(), local.Month(), local.Day(), 0, 0, 0, 0, time.UTC)
		if d.last != nil && d.last.Format("2006-01-02") == today.Format("2006-01-02") {
			continue
		}
		// Claim today's slot first so the reminder can never fire twice.
		tag, err := a.db.Exec(ctx,
			`UPDATE reminders SET last_fired_on = $1 WHERE id = $2 AND (last_fired_on IS NULL OR last_fired_on < $1)`,
			today, d.id)
		if err != nil || tag.RowsAffected() != 1 {
			continue
		}
		if !d.all || (d.quietOn && inQuiet(nowMin, d.qs, d.qe)) {
			continue
		}
		category, title, body := "general", d.title, "Reminder"
		switch d.kind {
		case "water":
			category, title = "water", "Time to drink water"
			body = fmt.Sprintf("Have a glass (%d ml) to stay on track.", d.glass)
		case "morning":
			category, title, body = "skincare", "Morning skincare routine", "Time for your morning routine."
		case "evening":
			category, title, body = "skincare", "Evening skincare routine", "Time for your evening routine."
		}
		if err := a.addNotification(ctx, d.uid, category, title, body); err != nil {
			log.Printf("reminder notify: %v", err)
		}
	}
}

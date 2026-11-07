package main

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5"
)

const maxPhotoBytes = 5 << 20 // 5 MB

func (a *App) health(c *gin.Context) {
	ctx, cancel := context.WithTimeout(c.Request.Context(), 2*time.Second)
	defer cancel()
	if err := a.db.Ping(ctx); err != nil {
		c.JSON(http.StatusServiceUnavailable, gin.H{"status": "error", "message": "database unavailable"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"status": "ok", "message": "Skinora API is running"})
}

// ---------- skin profile ----------

type profile struct {
	DisplayName string   `json:"display_name"`
	SkinType    string   `json:"skin_type"`
	Concerns    []string `json:"concerns"`
	Sensitive   bool     `json:"sensitive"`
	Gender      string   `json:"gender"`
}

var skinTypeSet = map[string]bool{"normal": true, "oily": true, "dry": true, "combination": true, "not_sure": true}
var concernSet = map[string]bool{
	"acne": true, "dark_spots": true, "dryness": true,
	"oiliness": true, "redness": true, "uneven_tone": true,
	"dullness": true, "dehydrated": true, "large_pores": true,
	"dark_circles": true, "acne_scars": true, "fine_lines": true,
}

func (a *App) loadProfile(ctx context.Context, uid int64) (profile, error) {
	var p profile
	err := a.db.QueryRow(ctx,
		`SELECT display_name, skin_type, concerns, sensitive, gender FROM user_profiles WHERE user_id = $1`, uid,
	).Scan(&p.DisplayName, &p.SkinType, &p.Concerns, &p.Sensitive, &p.Gender)
	if errors.Is(err, pgx.ErrNoRows) {
		return profile{Concerns: []string{}}, nil
	}
	if p.Concerns == nil {
		p.Concerns = []string{}
	}
	return p, err
}

func (a *App) getProfile(c *gin.Context) {
	p, err := a.loadProfile(c.Request.Context(), curUser(c).ID)
	if err != nil {
		serverError(c, err)
		return
	}
	respond(c, http.StatusOK, p)
}

func (a *App) putProfile(c *gin.Context) {
	var in profile
	if err := c.ShouldBindJSON(&in); err != nil {
		fail(c, http.StatusBadRequest, "invalid request body")
		return
	}
	in.DisplayName = strings.TrimSpace(in.DisplayName)
	in.Gender = strings.ToLower(strings.TrimSpace(in.Gender))
	if in.Gender != "" && in.Gender != "male" && in.Gender != "female" {
		fail(c, http.StatusBadRequest, "choose a valid gender")
		return
	}
	if utf8.RuneCountInString(in.DisplayName) > 40 {
		fail(c, http.StatusBadRequest, "display name must be 40 characters or fewer")
		return
	}
	if !skinTypeSet[in.SkinType] {
		fail(c, http.StatusBadRequest, "choose a valid skin type")
		return
	}
	clean := []string{}
	seen := map[string]bool{}
	for _, k := range in.Concerns {
		if !concernSet[k] {
			fail(c, http.StatusBadRequest, "unknown skin concern")
			return
		}
		if !seen[k] {
			seen[k] = true
			clean = append(clean, k)
		}
	}
	_, err := a.db.Exec(c.Request.Context(), `
		INSERT INTO user_profiles (user_id, display_name, skin_type, concerns, sensitive, gender)
		VALUES ($1, $2, $3, $4, $5, $6)
		ON CONFLICT (user_id) DO UPDATE SET
			display_name = EXCLUDED.display_name, skin_type = EXCLUDED.skin_type,
			concerns = EXCLUDED.concerns, sensitive = EXCLUDED.sensitive, gender = EXCLUDED.gender, updated_at = now()`,
		curUser(c).ID, in.DisplayName, in.SkinType, clean, in.Sensitive, in.Gender)
	if err != nil {
		serverError(c, err)
		return
	}
	in.Concerns = clean
	respond(c, http.StatusOK, in)
}

// ---------- settings ----------

type waterSettings struct {
	WaterGoalML int `json:"water_goal_ml"`
	GlassML     int `json:"glass_ml"`
}

func (a *App) getSettings(c *gin.Context) {
	var s waterSettings
	if err := a.db.QueryRow(c.Request.Context(),
		`SELECT water_goal_ml, glass_ml FROM user_settings WHERE user_id = $1`, curUser(c).ID).
		Scan(&s.WaterGoalML, &s.GlassML); err != nil {
		serverError(c, err)
		return
	}
	respond(c, http.StatusOK, s)
}

func (a *App) putSettings(c *gin.Context) {
	var in waterSettings
	if err := c.ShouldBindJSON(&in); err != nil {
		fail(c, http.StatusBadRequest, "invalid request body")
		return
	}
	if in.WaterGoalML < 500 || in.WaterGoalML > 5000 {
		fail(c, http.StatusBadRequest, "daily goal must be between 500 and 5000 ml")
		return
	}
	if in.GlassML < 50 || in.GlassML > 1000 {
		fail(c, http.StatusBadRequest, "glass size must be between 50 and 1000 ml")
		return
	}
	if _, err := a.db.Exec(c.Request.Context(),
		`UPDATE user_settings SET water_goal_ml = $1, glass_ml = $2 WHERE user_id = $3`,
		in.WaterGoalML, in.GlassML, curUser(c).ID); err != nil {
		serverError(c, err)
		return
	}
	respond(c, http.StatusOK, in)
}

// ---------- routine ----------

type routineItem struct {
	ID     int64  `json:"id"`
	Period string `json:"period"`
	Title  string `json:"title"`
	Done   bool   `json:"done"`
}

type routineDay struct {
	Day       string `json:"day"`
	Completed int    `json:"completed"`
	Total     int    `json:"total"`
}

func (a *App) listRoutine(c *gin.Context) {
	day, ok := dateParam(c)
	if !ok {
		return
	}
	rows, err := a.db.Query(c.Request.Context(), `
		SELECT i.id, i.period, i.title, (c.item_id IS NOT NULL) AS done
		FROM routine_items i
		LEFT JOIN routine_completions c ON c.item_id = i.id AND c.day = $1
		WHERE i.user_id = $2
		ORDER BY CASE i.period WHEN 'morning' THEN 0 ELSE 1 END, i.sort_order, i.id`, day, curUser(c).ID)
	if err != nil {
		serverError(c, err)
		return
	}
	defer rows.Close()
	items := []routineItem{}
	for rows.Next() {
		var it routineItem
		if err := rows.Scan(&it.ID, &it.Period, &it.Title, &it.Done); err != nil {
			serverError(c, err)
			return
		}
		items = append(items, it)
	}
	if err := rows.Err(); err != nil {
		serverError(c, err)
		return
	}
	respond(c, http.StatusOK, items)
}

type routineInput struct {
	Period string `json:"period"`
	Title  string `json:"title"`
}

func (in *routineInput) validate() string {
	in.Title = strings.TrimSpace(in.Title)
	if in.Period != "morning" && in.Period != "evening" {
		return "period must be morning or evening"
	}
	if in.Title == "" {
		return "step name is required"
	}
	if utf8.RuneCountInString(in.Title) > 60 {
		return "step name must be 60 characters or fewer"
	}
	return ""
}

func (a *App) createRoutineItem(c *gin.Context) {
	var in routineInput
	if err := c.ShouldBindJSON(&in); err != nil {
		fail(c, http.StatusBadRequest, "invalid request body")
		return
	}
	if msg := in.validate(); msg != "" {
		fail(c, http.StatusBadRequest, msg)
		return
	}
	u := curUser(c)
	ctx := c.Request.Context()
	if !u.premium() {
		var n int
		if err := a.db.QueryRow(ctx, `SELECT COUNT(*)::int FROM routine_items WHERE user_id = $1`, u.ID).Scan(&n); err != nil {
			serverError(c, err)
			return
		}
		if n >= freeRoutineLimit {
			premiumRequired(c, "the free plan allows up to 3 routine steps. Upgrade for unlimited steps.")
			return
		}
	}
	var it routineItem
	err := a.db.QueryRow(ctx, `
		INSERT INTO routine_items (user_id, period, title, sort_order)
		VALUES ($1, $2, $3, (SELECT COALESCE(MAX(sort_order), 0) + 1 FROM routine_items WHERE user_id = $1))
		RETURNING id, period, title`, u.ID, in.Period, in.Title).Scan(&it.ID, &it.Period, &it.Title)
	if err != nil {
		serverError(c, err)
		return
	}
	respond(c, http.StatusCreated, it)
}

func (a *App) updateRoutineItem(c *gin.Context) {
	id, ok := idParam(c)
	if !ok {
		return
	}
	var in routineInput
	if err := c.ShouldBindJSON(&in); err != nil {
		fail(c, http.StatusBadRequest, "invalid request body")
		return
	}
	if msg := in.validate(); msg != "" {
		fail(c, http.StatusBadRequest, msg)
		return
	}
	tag, err := a.db.Exec(c.Request.Context(),
		`UPDATE routine_items SET title = $1, period = $2 WHERE id = $3 AND user_id = $4`,
		in.Title, in.Period, id, curUser(c).ID)
	if err != nil {
		serverError(c, err)
		return
	}
	if tag.RowsAffected() == 0 {
		fail(c, http.StatusNotFound, "routine step not found")
		return
	}
	respond(c, http.StatusOK, routineItem{ID: id, Period: in.Period, Title: in.Title})
}

func (a *App) deleteRoutineItem(c *gin.Context) {
	id, ok := idParam(c)
	if !ok {
		return
	}
	tag, err := a.db.Exec(c.Request.Context(),
		`DELETE FROM routine_items WHERE id = $1 AND user_id = $2`, id, curUser(c).ID)
	if err != nil {
		serverError(c, err)
		return
	}
	if tag.RowsAffected() == 0 {
		fail(c, http.StatusNotFound, "routine step not found")
		return
	}
	c.Status(http.StatusNoContent)
}

func (a *App) setCompletion(c *gin.Context) {
	id, ok := idParam(c)
	if !ok {
		return
	}
	day, ok := dateParam(c)
	if !ok {
		return
	}
	var in struct {
		Done bool `json:"done"`
	}
	if err := c.ShouldBindJSON(&in); err != nil {
		fail(c, http.StatusBadRequest, "invalid request body")
		return
	}
	ctx := c.Request.Context()
	var exists bool
	if err := a.db.QueryRow(ctx,
		`SELECT EXISTS (SELECT 1 FROM routine_items WHERE id = $1 AND user_id = $2)`, id, curUser(c).ID).Scan(&exists); err != nil {
		serverError(c, err)
		return
	}
	if !exists {
		fail(c, http.StatusNotFound, "routine step not found")
		return
	}
	var err error
	if in.Done {
		_, err = a.db.Exec(ctx, `INSERT INTO routine_completions (item_id, day) VALUES ($1, $2) ON CONFLICT DO NOTHING`, id, day)
	} else {
		_, err = a.db.Exec(ctx, `DELETE FROM routine_completions WHERE item_id = $1 AND day = $2`, id, day)
	}
	if err != nil {
		serverError(c, err)
		return
	}
	respond(c, http.StatusOK, gin.H{"id": id, "done": in.Done})
}

func (a *App) resetCompletions(c *gin.Context) {
	day, ok := dateParam(c)
	if !ok {
		return
	}
	if _, err := a.db.Exec(c.Request.Context(), `
		DELETE FROM routine_completions
		WHERE day = $1 AND item_id IN (SELECT id FROM routine_items WHERE user_id = $2)`,
		day, curUser(c).ID); err != nil {
		serverError(c, err)
		return
	}
	c.Status(http.StatusNoContent)
}

func (a *App) routineHistory(ctx context.Context, uid int64, from, to time.Time) ([]routineDay, error) {
	rows, err := a.db.Query(ctx, `
		SELECT d::date, COALESCE(c.n, 0)::int, (SELECT COUNT(*) FROM routine_items WHERE user_id = $3)::int
		FROM generate_series($1::timestamp, $2::timestamp, interval '1 day') AS d
		LEFT JOIN (
			SELECT rc.day, COUNT(*) AS n
			FROM routine_completions rc JOIN routine_items ri ON ri.id = rc.item_id
			WHERE ri.user_id = $3 GROUP BY rc.day
		) c ON c.day = d::date
		ORDER BY d`, from, to, uid)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []routineDay{}
	for rows.Next() {
		var d time.Time
		var r routineDay
		if err := rows.Scan(&d, &r.Completed, &r.Total); err != nil {
			return nil, err
		}
		r.Day = fmtDay(d)
		out = append(out, r)
	}
	return out, rows.Err()
}

func rangeParams(c *gin.Context, defDays int) (time.Time, time.Time, int, bool) {
	to, ok := dateParam(c)
	if !ok {
		return to, to, 0, false
	}
	days := intQuery(c, "days", defDays, 1, 90)
	return to.AddDate(0, 0, -(days - 1)), to, days, true
}

func (a *App) routineHistoryHandler(c *gin.Context) {
	from, to, _, ok := rangeParams(c, 7)
	if !ok {
		return
	}
	h, err := a.routineHistory(c.Request.Context(), curUser(c).ID, from, to)
	if err != nil {
		serverError(c, err)
		return
	}
	respond(c, http.StatusOK, h)
}

// ---------- water ----------

type waterEntry struct {
	ID        int64     `json:"id"`
	AmountML  int       `json:"amount_ml"`
	CreatedAt time.Time `json:"created_at"`
}

type waterSummary struct {
	Date    string       `json:"date"`
	TotalML int          `json:"total_ml"`
	GoalML  int          `json:"goal_ml"`
	GlassML int          `json:"glass_ml"`
	Entries []waterEntry `json:"entries"`
}

type waterDay struct {
	Day     string `json:"day"`
	TotalML int    `json:"total_ml"`
}

func (a *App) buildWaterSummary(ctx context.Context, uid int64, day time.Time) (waterSummary, error) {
	s := waterSummary{Date: fmtDay(day), Entries: []waterEntry{}}
	if err := a.db.QueryRow(ctx, `SELECT water_goal_ml, glass_ml FROM user_settings WHERE user_id = $1`, uid).
		Scan(&s.GoalML, &s.GlassML); err != nil {
		return s, err
	}
	rows, err := a.db.Query(ctx,
		`SELECT id, amount_ml, created_at FROM water_logs WHERE user_id = $1 AND day = $2 ORDER BY id`, uid, day)
	if err != nil {
		return s, err
	}
	defer rows.Close()
	for rows.Next() {
		var e waterEntry
		if err := rows.Scan(&e.ID, &e.AmountML, &e.CreatedAt); err != nil {
			return s, err
		}
		s.Entries = append(s.Entries, e)
		s.TotalML += e.AmountML
	}
	return s, rows.Err()
}

func (a *App) getWater(c *gin.Context) {
	day, ok := dateParam(c)
	if !ok {
		return
	}
	s, err := a.buildWaterSummary(c.Request.Context(), curUser(c).ID, day)
	if err != nil {
		serverError(c, err)
		return
	}
	respond(c, http.StatusOK, s)
}

func (a *App) addWater(c *gin.Context) {
	day, ok := dateParam(c)
	if !ok {
		return
	}
	var in struct {
		AmountML int `json:"amount_ml"`
	}
	if err := c.ShouldBindJSON(&in); err != nil {
		fail(c, http.StatusBadRequest, "invalid request body")
		return
	}
	if in.AmountML < 1 || in.AmountML > 1000 {
		fail(c, http.StatusBadRequest, "amount must be between 1 and 1000 ml")
		return
	}
	uid := curUser(c).ID
	ctx := c.Request.Context()
	var total int
	if err := a.db.QueryRow(ctx,
		`SELECT COALESCE(SUM(amount_ml), 0)::int FROM water_logs WHERE user_id = $1 AND day = $2`, uid, day).Scan(&total); err != nil {
		serverError(c, err)
		return
	}
	if total+in.AmountML > 5000 {
		fail(c, http.StatusBadRequest, "Daily limit reached (5000 ml)")
		return
	}
	if _, err := a.db.Exec(ctx,
		`INSERT INTO water_logs (user_id, day, amount_ml) VALUES ($1, $2, $3)`, uid, day, in.AmountML); err != nil {
		serverError(c, err)
		return
	}
	s, err := a.buildWaterSummary(ctx, uid, day)
	if err != nil {
		serverError(c, err)
		return
	}
	respond(c, http.StatusCreated, s)
}

func (a *App) removeLastWater(c *gin.Context) {
	day, ok := dateParam(c)
	if !ok {
		return
	}
	uid := curUser(c).ID
	ctx := c.Request.Context()
	tag, err := a.db.Exec(ctx, `
		DELETE FROM water_logs WHERE id = (
			SELECT id FROM water_logs WHERE user_id = $1 AND day = $2 ORDER BY id DESC LIMIT 1)`, uid, day)
	if err != nil {
		serverError(c, err)
		return
	}
	if tag.RowsAffected() == 0 {
		fail(c, http.StatusNotFound, "there is no entry to remove for this day")
		return
	}
	s, err := a.buildWaterSummary(ctx, uid, day)
	if err != nil {
		serverError(c, err)
		return
	}
	respond(c, http.StatusOK, s)
}

func (a *App) waterHistory(ctx context.Context, uid int64, from, to time.Time) ([]waterDay, error) {
	rows, err := a.db.Query(ctx, `
		SELECT d::date, COALESCE(SUM(w.amount_ml), 0)::int
		FROM generate_series($1::timestamp, $2::timestamp, interval '1 day') AS d
		LEFT JOIN water_logs w ON w.day = d::date AND w.user_id = $3
		GROUP BY d ORDER BY d`, from, to, uid)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []waterDay{}
	for rows.Next() {
		var d time.Time
		var w waterDay
		if err := rows.Scan(&d, &w.TotalML); err != nil {
			return nil, err
		}
		w.Day = fmtDay(d)
		out = append(out, w)
	}
	return out, rows.Err()
}

func (a *App) waterHistoryHandler(c *gin.Context) {
	from, to, _, ok := rangeParams(c, 7)
	if !ok {
		return
	}
	h, err := a.waterHistory(c.Request.Context(), curUser(c).ID, from, to)
	if err != nil {
		serverError(c, err)
		return
	}
	respond(c, http.StatusOK, h)
}

// ---------- sleep ----------

type sleepLog struct {
	ID          int64     `json:"id"`
	SleepStart  time.Time `json:"sleep_start"`
	WakeTime    time.Time `json:"wake_time"`
	DurationMin int       `json:"duration_min"`
}

type sleepInput struct {
	SleepStart time.Time `json:"sleep_start"`
	WakeTime   time.Time `json:"wake_time"`
}

const sleepCols = `id, sleep_start, wake_time, (EXTRACT(EPOCH FROM (wake_time - sleep_start)) / 60)::int`

func scanSleep(r pgx.Row) (sleepLog, error) {
	var s sleepLog
	err := r.Scan(&s.ID, &s.SleepStart, &s.WakeTime, &s.DurationMin)
	return s, err
}

func (in sleepInput) validate() string {
	switch {
	case in.SleepStart.IsZero() || in.WakeTime.IsZero():
		return "bedtime and wake-up time are required"
	case in.SleepStart.Year() < 2000:
		return "date is out of range"
	case !in.WakeTime.After(in.SleepStart):
		return "wake-up time must be after bedtime"
	case in.WakeTime.Sub(in.SleepStart) > 24*time.Hour:
		return "a sleep entry cannot be longer than 24 hours"
	case in.WakeTime.After(time.Now().Add(5 * time.Minute)):
		return "wake-up time cannot be in the future"
	}
	return ""
}

func (a *App) listSleep(c *gin.Context) {
	limit := intQuery(c, "limit", 50, 1, 200)
	offset := intQuery(c, "offset", 0, 0, 100000)
	rows, err := a.db.Query(c.Request.Context(),
		`SELECT `+sleepCols+` FROM sleep_logs WHERE user_id = $1 ORDER BY wake_time DESC LIMIT $2 OFFSET $3`,
		curUser(c).ID, limit, offset)
	if err != nil {
		serverError(c, err)
		return
	}
	defer rows.Close()
	out := []sleepLog{}
	for rows.Next() {
		s, err := scanSleep(rows)
		if err != nil {
			serverError(c, err)
			return
		}
		out = append(out, s)
	}
	if err := rows.Err(); err != nil {
		serverError(c, err)
		return
	}
	respond(c, http.StatusOK, out)
}

func (a *App) createSleep(c *gin.Context) {
	var in sleepInput
	if err := c.ShouldBindJSON(&in); err != nil {
		fail(c, http.StatusBadRequest, "invalid request body (use RFC 3339 timestamps)")
		return
	}
	if msg := in.validate(); msg != "" {
		fail(c, http.StatusBadRequest, msg)
		return
	}
	var dup bool
    if err := a.db.QueryRow(c.Request.Context(),
        `SELECT EXISTS (SELECT 1 FROM sleep_logs WHERE user_id = $1 AND wake_time::date = $2::timestamptz::date)`,
        curUser(c).ID, in.WakeTime).Scan(&dup); err != nil {
        serverError(c, err)
        return
    }
    if dup {
        fail(c, http.StatusConflict, "You already logged sleep for this day. Edit it instead.")
        return
    }
    s, err := scanSleep(a.db.QueryRow(c.Request.Context(),
		`INSERT INTO sleep_logs (user_id, sleep_start, wake_time) VALUES ($1, $2, $3) RETURNING `+sleepCols,
		curUser(c).ID, in.SleepStart, in.WakeTime))
	if err != nil {
		serverError(c, err)
		return
	}
	respond(c, http.StatusCreated, s)
}

func (a *App) updateSleep(c *gin.Context) {
	id, ok := idParam(c)
	if !ok {
		return
	}
	var in sleepInput
	if err := c.ShouldBindJSON(&in); err != nil {
		fail(c, http.StatusBadRequest, "invalid request body (use RFC 3339 timestamps)")
		return
	}
	if msg := in.validate(); msg != "" {
		fail(c, http.StatusBadRequest, msg)
		return
	}
	var dup bool
    if err := a.db.QueryRow(c.Request.Context(),
        `SELECT EXISTS (SELECT 1 FROM sleep_logs WHERE user_id = $1 AND id <> $3 AND wake_time::date = $2::timestamptz::date)`,
        curUser(c).ID, in.WakeTime, id).Scan(&dup); err != nil {
        serverError(c, err)
        return
    }
    if dup {
        fail(c, http.StatusConflict, "You already logged sleep for this day. Edit it instead.")
        return
    }
    s, err := scanSleep(a.db.QueryRow(c.Request.Context(),
		`UPDATE sleep_logs SET sleep_start = $1, wake_time = $2 WHERE id = $3 AND user_id = $4 RETURNING `+sleepCols,
		in.SleepStart, in.WakeTime, id, curUser(c).ID))
	if errors.Is(err, pgx.ErrNoRows) {
		fail(c, http.StatusNotFound, "sleep entry not found")
		return
	}
	if err != nil {
		serverError(c, err)
		return
	}
	respond(c, http.StatusOK, s)
}

func (a *App) deleteSleep(c *gin.Context) {
	id, ok := idParam(c)
	if !ok {
		return
	}
	tag, err := a.db.Exec(c.Request.Context(),
		`DELETE FROM sleep_logs WHERE id = $1 AND user_id = $2`, id, curUser(c).ID)
	if err != nil {
		serverError(c, err)
		return
	}
	if tag.RowsAffected() == 0 {
		fail(c, http.StatusNotFound, "sleep entry not found")
		return
	}
	c.Status(http.StatusNoContent)
}

// ---------- journal ----------

type journalEntry struct {
	ID        int64     `json:"id"`
	Day       string    `json:"day"`
	Notes     string    `json:"notes"`
	Rating    *int      `json:"rating"`
	HasPhoto  bool      `json:"has_photo"`
	PhotoV    int64     `json:"photo_v"`
	CreatedAt time.Time `json:"created_at"`
}

type journalInput struct {
	Day    string `json:"day"`
	Notes  string `json:"notes"`
	Rating *int   `json:"rating"`
}

const journalCols = `id, day, notes, rating, photo_file IS NOT NULL, created_at, updated_at`

func scanJournal(r pgx.Row) (journalEntry, error) {
	var e journalEntry
	var day, upd time.Time
	if err := r.Scan(&e.ID, &day, &e.Notes, &e.Rating, &e.HasPhoto, &e.CreatedAt, &upd); err != nil {
		return e, err
	}
	e.Day = fmtDay(day)
	e.PhotoV = upd.Unix()
	return e, nil
}

func (in *journalInput) validate() (time.Time, string) {
	day, err := parseDate(in.Day)
	if err != nil {
		return day, err.Error()
	}
	in.Notes = strings.TrimSpace(in.Notes)
	if utf8.RuneCountInString(in.Notes) > 2000 {
		return day, "notes must be 2000 characters or fewer"
	}
	if in.Rating != nil && (*in.Rating < 1 || *in.Rating > 5) {
		return day, "rating must be between 1 and 5"
	}
	if in.Notes == "" && in.Rating == nil {
		return day, "add a note or a rating"
	}
	return day, ""
}

func (a *App) listJournal(c *gin.Context) {
	limit := intQuery(c, "limit", 50, 1, 200)
	offset := intQuery(c, "offset", 0, 0, 100000)
	rows, err := a.db.Query(c.Request.Context(),
		`SELECT `+journalCols+` FROM journal_entries WHERE user_id = $1 AND ($4::bool OR day >= current_date - 1) ORDER BY day DESC, id DESC LIMIT $2 OFFSET $3`,
		curUser(c).ID, limit, offset, curUser(c).premium())
	if err != nil {
		serverError(c, err)
		return
	}
	defer rows.Close()
	out := []journalEntry{}
	for rows.Next() {
		e, err := scanJournal(rows)
		if err != nil {
			serverError(c, err)
			return
		}
		out = append(out, e)
	}
	if err := rows.Err(); err != nil {
		serverError(c, err)
		return
	}
	respond(c, http.StatusOK, out)
}

func (a *App) createJournal(c *gin.Context) {
	var in journalInput
	if err := c.ShouldBindJSON(&in); err != nil {
		fail(c, http.StatusBadRequest, "invalid request body")
		return
	}
	day, msg := in.validate()
	if msg != "" {
		fail(c, http.StatusBadRequest, msg)
		return
	}
	e, err := scanJournal(a.db.QueryRow(c.Request.Context(),
		`INSERT INTO journal_entries (user_id, day, notes, rating) VALUES ($1, $2, $3, $4) RETURNING `+journalCols,
		curUser(c).ID, day, in.Notes, in.Rating))
	if err != nil {
		serverError(c, err)
		return
	}
	respond(c, http.StatusCreated, e)
}

func (a *App) updateJournal(c *gin.Context) {
	id, ok := idParam(c)
	if !ok {
		return
	}
	var in journalInput
	if err := c.ShouldBindJSON(&in); err != nil {
		fail(c, http.StatusBadRequest, "invalid request body")
		return
	}
	day, msg := in.validate()
	if msg != "" {
		fail(c, http.StatusBadRequest, msg)
		return
	}
	e, err := scanJournal(a.db.QueryRow(c.Request.Context(),
		`UPDATE journal_entries SET day = $1, notes = $2, rating = $3, updated_at = now()
		 WHERE id = $4 AND user_id = $5 RETURNING `+journalCols,
		day, in.Notes, in.Rating, id, curUser(c).ID))
	if errors.Is(err, pgx.ErrNoRows) {
		fail(c, http.StatusNotFound, "journal entry not found")
		return
	}
	if err != nil {
		serverError(c, err)
		return
	}
	respond(c, http.StatusOK, e)
}

func (a *App) photoPath(name string) string {
	return filepath.Join(a.cfg.UploadDir, filepath.Base(name))
}

func (a *App) removePhotoFile(name string) {
	if name == "" {
		return
	}
	if err := os.Remove(a.photoPath(name)); err != nil && !os.IsNotExist(err) {
		log.Printf("could not remove photo file: %v", err)
	}
}

func (a *App) deleteJournal(c *gin.Context) {
	id, ok := idParam(c)
	if !ok {
		return
	}
	var photo *string
	err := a.db.QueryRow(c.Request.Context(),
		`DELETE FROM journal_entries WHERE id = $1 AND user_id = $2 RETURNING photo_file`, id, curUser(c).ID).Scan(&photo)
	if errors.Is(err, pgx.ErrNoRows) {
		fail(c, http.StatusNotFound, "journal entry not found")
		return
	}
	if err != nil {
		serverError(c, err)
		return
	}
	if photo != nil {
		a.removePhotoFile(*photo)
	}
	c.Status(http.StatusNoContent)
}

func (a *App) uploadPhoto(c *gin.Context) {
	u := curUser(c)
	if !u.premium() {
		premiumRequired(c, "progress photos are part of Premium.")
		return
	}
	id, ok := idParam(c)
	if !ok {
		return
	}
	ctx := c.Request.Context()

	var old *string
	err := a.db.QueryRow(ctx, `SELECT photo_file FROM journal_entries WHERE id = $1 AND user_id = $2`, id, u.ID).Scan(&old)
	if errors.Is(err, pgx.ErrNoRows) {
		fail(c, http.StatusNotFound, "journal entry not found")
		return
	}
	if err != nil {
		serverError(c, err)
		return
	}

	fh, err := c.FormFile("photo")
	if err != nil {
		fail(c, http.StatusBadRequest, "a photo file is required (max 5 MB)")
		return
	}
	if fh.Size > maxPhotoBytes {
		fail(c, http.StatusRequestEntityTooLarge, "photo must be 5 MB or smaller")
		return
	}
	f, err := fh.Open()
	if err != nil {
		serverError(c, err)
		return
	}
	defer f.Close()

	head := make([]byte, 512)
	n, _ := io.ReadFull(f, head)
	ext := map[string]string{"image/jpeg": ".jpg", "image/png": ".png", "image/webp": ".webp"}[http.DetectContentType(head[:n])]
	if ext == "" {
		fail(c, http.StatusBadRequest, "only JPEG, PNG or WebP images are allowed")
		return
	}
	if _, err := f.Seek(0, io.SeekStart); err != nil {
		serverError(c, err)
		return
	}

	buf := make([]byte, 16)
	if _, err := rand.Read(buf); err != nil {
		serverError(c, err)
		return
	}
	name := hex.EncodeToString(buf) + ext
	if err := os.MkdirAll(a.cfg.UploadDir, 0o750); err != nil {
		serverError(c, err)
		return
	}
	dst, err := os.OpenFile(a.photoPath(name), os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0o640)
	if err != nil {
		serverError(c, err)
		return
	}
	if _, err := io.Copy(dst, f); err != nil {
		dst.Close()
		a.removePhotoFile(name)
		serverError(c, err)
		return
	}
	if err := dst.Close(); err != nil {
		a.removePhotoFile(name)
		serverError(c, err)
		return
	}

	e, err := scanJournal(a.db.QueryRow(ctx,
		`UPDATE journal_entries SET photo_file = $1, updated_at = now() WHERE id = $2 AND user_id = $3 RETURNING `+journalCols,
		name, id, u.ID))
	if err != nil {
		a.removePhotoFile(name)
		serverError(c, err)
		return
	}
	if old != nil {
		a.removePhotoFile(*old)
	}
	respond(c, http.StatusOK, e)
}

func (a *App) getPhoto(c *gin.Context) {
	id, ok := idParam(c)
	if !ok {
		return
	}
	var name *string
	err := a.db.QueryRow(c.Request.Context(),
		`SELECT photo_file FROM journal_entries WHERE id = $1 AND user_id = $2`, id, curUser(c).ID).Scan(&name)
	if errors.Is(err, pgx.ErrNoRows) || (err == nil && name == nil) {
		fail(c, http.StatusNotFound, "photo not found")
		return
	}
	if err != nil {
		serverError(c, err)
		return
	}
	c.Header("X-Content-Type-Options", "nosniff")
	c.Header("Cache-Control", "private, max-age=300")
	c.File(a.photoPath(*name))
}

func (a *App) deletePhoto(c *gin.Context) {
	id, ok := idParam(c)
	if !ok {
		return
	}
	uid := curUser(c).ID
	ctx := c.Request.Context()
	var old *string
	err := a.db.QueryRow(ctx, `SELECT photo_file FROM journal_entries WHERE id = $1 AND user_id = $2`, id, uid).Scan(&old)
	if errors.Is(err, pgx.ErrNoRows) {
		fail(c, http.StatusNotFound, "journal entry not found")
		return
	}
	if err != nil {
		serverError(c, err)
		return
	}
	if _, err := a.db.Exec(ctx,
		`UPDATE journal_entries SET photo_file = NULL, updated_at = now() WHERE id = $1 AND user_id = $2`, id, uid); err != nil {
		serverError(c, err)
		return
	}
	if old != nil {
		a.removePhotoFile(*old)
	}
	c.Status(http.StatusNoContent)
}

// ---------- insights ----------

func (a *App) insights(c *gin.Context) {
	from, to, days, ok := rangeParams(c, 2)
	if !ok {
		return
	}
	u := curUser(c)
	if days > 2 && !u.premium() {
		premiumRequired(c, "7, 14 and 30 day insights are part of Premium.")
		return
	}
	ctx := c.Request.Context()

	routine, err := a.routineHistory(ctx, u.ID, from, to)
	if err != nil {
		serverError(c, err)
		return
	}
	water, err := a.waterHistory(ctx, u.ID, from, to)
	if err != nil {
		serverError(c, err)
		return
	}
	var goal int
	if err := a.db.QueryRow(ctx, `SELECT water_goal_ml FROM user_settings WHERE user_id = $1`, u.ID).Scan(&goal); err != nil {
		serverError(c, err)
		return
	}
	var sleepCount int
	var sleepAvg float64
	if err := a.db.QueryRow(ctx, `
		SELECT COUNT(*)::int, COALESCE(AVG(EXTRACT(EPOCH FROM (wake_time - sleep_start)) / 60), 0)::float8
		FROM sleep_logs WHERE user_id = $3 AND wake_time::date BETWEEN $1::date AND $2::date`,
		from, to, u.ID).Scan(&sleepCount, &sleepAvg); err != nil {
		serverError(c, err)
		return
	}
	var journalCount int
	var journalAvg *float64
	if err := a.db.QueryRow(ctx, `
		SELECT COUNT(*)::int, AVG(rating)::float8
		FROM journal_entries WHERE user_id = $3 AND day BETWEEN $1::date AND $2::date`,
		from, to, u.ID).Scan(&journalCount, &journalAvg); err != nil {
		serverError(c, err)
		return
	}
	respond(c, http.StatusOK, gin.H{
		"days":          days,
		"routine":       routine,
		"water":         water,
		"water_goal_ml": goal,
		"sleep":         gin.H{"count": sleepCount, "avg_minutes": sleepAvg},
		"journal":       gin.H{"count": journalCount, "avg_rating": journalAvg},
	})
}

// ---------- delete my data (account stays) ----------

func (a *App) clearData(c *gin.Context) {
	if c.Query("confirm") != "delete-all" {
		fail(c, http.StatusBadRequest, "confirmation required")
		return
	}
	uid := curUser(c).ID
	ctx := c.Request.Context()

	files, err := a.userPhotoFiles(ctx, uid)
	if err != nil {
		serverError(c, err)
		return
	}
	tx, err := a.db.Begin(ctx)
	if err != nil {
		serverError(c, err)
		return
	}
	defer tx.Rollback(ctx)
	stmts := []string{
		`DELETE FROM routine_items WHERE user_id = $1`,
		`DELETE FROM water_logs WHERE user_id = $1`,
		`DELETE FROM sleep_logs WHERE user_id = $1`,
		`DELETE FROM journal_entries WHERE user_id = $1`,
		`DELETE FROM user_profiles WHERE user_id = $1`,
		`UPDATE user_settings SET water_goal_ml = 5000, glass_ml = 250 WHERE user_id = $1`,
	}
	for _, s := range stmts {
		if _, err := tx.Exec(ctx, s, uid); err != nil {
			serverError(c, err)
			return
		}
	}
	if err := tx.Commit(ctx); err != nil {
		serverError(c, err)
		return
	}
	for _, f := range files {
		a.removePhotoFile(f)
	}
	c.Status(http.StatusNoContent)
}

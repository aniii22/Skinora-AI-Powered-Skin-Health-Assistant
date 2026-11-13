package main

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"net/http"
	"net/mail"
	"strings"
	"sync"
	"time"
	"unicode/utf8"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"golang.org/x/crypto/bcrypt"
)

const (
	freeRoutineLimit = 6
	bcryptCost       = 12
	sessionDays      = 30
)

type authUser struct {
	ID           int64
	Name         string
	Email        string
	Plan         string
	PremiumUntil *time.Time
}

func (u authUser) premium() bool {
	return u.Plan == "premium" && u.PremiumUntil != nil && u.PremiumUntil.After(time.Now())
}

func (u authUser) public() gin.H {
	p := u.premium()
	var until *time.Time
	plan := "free"
	if p {
		until = u.PremiumUntil
		plan = "premium"
	}
	return gin.H{
		"id": u.ID, "name": u.Name, "email": u.Email,
		"plan": plan, "is_premium": p, "premium_until": until,
		"free_routine_limit": freeRoutineLimit,
	}
}

func curUser(c *gin.Context) authUser { return c.MustGet("user").(authUser) }

func premiumRequired(c *gin.Context, msg string) {
	fail(c, http.StatusPaymentRequired, "Premium: "+msg)
}

// ---------- tiny in-memory rate limiter ----------

type limiter struct {
	mu   sync.Mutex
	hits map[string][]time.Time
}

func newLimiter() *limiter {
	l := &limiter{hits: map[string][]time.Time{}}
	go l.sweepLoop()
	return l
}

func (l *limiter) prune(key string, window time.Duration) {
	cutoff := time.Now().Add(-window)
	h := l.hits[key]
	i := 0
	for i < len(h) && h[i].Before(cutoff) {
		i++
	}
	if i == len(h) {
		delete(l.hits, key)
	} else {
		l.hits[key] = h[i:]
	}
}

func (l *limiter) blocked(key string, max int, window time.Duration) bool {
	l.mu.Lock()
	defer l.mu.Unlock()
	l.prune(key, window)
	return len(l.hits[key]) >= max
}

func (l *limiter) add(key string, window time.Duration) {
	l.mu.Lock()
	defer l.mu.Unlock()
	l.prune(key, window)
	l.hits[key] = append(l.hits[key], time.Now())
}

func (l *limiter) clear(key string) {
	l.mu.Lock()
	defer l.mu.Unlock()
	delete(l.hits, key)
}

// ---------- tokens & middleware ----------

func hashToken(raw string) string {
	s := sha256.Sum256([]byte(raw))
	return hex.EncodeToString(s[:])
}

func (a *App) createSession(ctx context.Context, uid int64) (string, error) {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	raw := hex.EncodeToString(b)
	if _, err := a.db.Exec(ctx,
		`INSERT INTO sessions (token_hash, user_id, expires_at) VALUES ($1, $2, now() + make_interval(days => $3))`,
		hashToken(raw), uid, sessionDays); err != nil {
		return "", err
	}
	_, _ = a.db.Exec(ctx, `DELETE FROM sessions WHERE expires_at < now()`)
	return raw, nil
}

func (a *App) requireAuth() gin.HandlerFunc {
	return func(c *gin.Context) {
		h := c.GetHeader("Authorization")
		if !strings.HasPrefix(h, "Bearer ") {
			fail(c, http.StatusUnauthorized, "Please sign in to continue.")
			return
		}
		th := hashToken(strings.TrimSpace(h[7:]))
		var u authUser
		err := a.db.QueryRow(c.Request.Context(), `
			SELECT u.id, u.name, u.email, u.plan, u.premium_until
			FROM sessions s JOIN users u ON u.id = s.user_id
			WHERE s.token_hash = $1 AND s.expires_at > now()`, th).
			Scan(&u.ID, &u.Name, &u.Email, &u.Plan, &u.PremiumUntil)
		if errors.Is(err, pgx.ErrNoRows) {
			fail(c, http.StatusUnauthorized, "Your session expired. Please sign in again.")
			return
		}
		if err != nil {
			serverError(c, err)
			return
		}
		c.Set("user", u)
		c.Set("tokenHash", th)
		c.Next()
	}
}

func validEmail(e string) bool {
	if e == "" || len(e) > 254 {
		return false
	}
	addr, err := mail.ParseAddress(e)
	if err != nil || addr.Address != e {
		return false
	}
	at := strings.LastIndex(e, "@")
	return at > 0 && strings.Contains(e[at:], ".")
}

// Unknown emails take as long as known ones (no account enumeration by timing).
var dummyHash, _ = bcrypt.GenerateFromPassword([]byte("not-a-real-password"), bcryptCost)

func (a *App) register(c *gin.Context) {
	var in struct {
		Name     string `json:"name"`
		Email    string `json:"email"`
		Password string `json:"password"`
	}
	if err := c.ShouldBindJSON(&in); err != nil {
		fail(c, http.StatusBadRequest, "invalid request body")
		return
	}
	name := strings.TrimSpace(in.Name)
	email := strings.ToLower(strings.TrimSpace(in.Email))
	switch {
	case name == "" || utf8.RuneCountInString(name) > 40:
		fail(c, http.StatusBadRequest, "Enter your name (up to 40 characters).")
		return
	case !validEmail(email):
		fail(c, http.StatusBadRequest, "Enter a valid email address.")
		return
	case len(in.Password) < 8:
		fail(c, http.StatusBadRequest, "Password must be at least 8 characters.")
		return
	case len(in.Password) > 72:
		fail(c, http.StatusBadRequest, "Password must be 72 characters or fewer.")
		return
	}
	key := "reg|" + c.ClientIP()
	if a.lim.blocked(key, 10, time.Hour) {
		fail(c, http.StatusTooManyRequests, "Too many sign-ups from this device. Try again later.")
		return
	}
	a.lim.add(key, time.Hour)

	hash, err := bcrypt.GenerateFromPassword([]byte(in.Password), bcryptCost)
	if err != nil {
		serverError(c, err)
		return
	}
	ctx := c.Request.Context()
	tx, err := a.db.Begin(ctx)
	if err != nil {
		serverError(c, err)
		return
	}
	defer tx.Rollback(ctx)

	var u authUser
	err = tx.QueryRow(ctx, `
		INSERT INTO users (email, name, password_hash) VALUES ($1, $2, $3)
		RETURNING id, name, email, plan, premium_until`, email, name, string(hash)).
		Scan(&u.ID, &u.Name, &u.Email, &u.Plan, &u.PremiumUntil)
	var pg *pgconn.PgError
	if errors.As(err, &pg) && pg.Code == "23505" {
		fail(c, http.StatusConflict, "An account with this email already exists. Try signing in.")
		return
	}
	if err != nil {
		serverError(c, err)
		return
	}
	if _, err := tx.Exec(ctx, `INSERT INTO user_settings (user_id) VALUES ($1)`, u.ID); err != nil {
		serverError(c, err)
		return
	}
	if err := seedRoutine(ctx, tx, u.ID); err != nil {
		serverError(c, err)
		return
	}
	if err := tx.Commit(ctx); err != nil {
		serverError(c, err)
		return
	}
	token, err := a.createSession(ctx, u.ID)
	if err != nil {
		serverError(c, err)
		return
	}
	respond(c, http.StatusCreated, gin.H{"token": token, "user": u.public()})
}

func (a *App) login(c *gin.Context) {
	var in struct {
		Email    string `json:"email"`
		Password string `json:"password"`
	}
	if err := c.ShouldBindJSON(&in); err != nil {
		fail(c, http.StatusBadRequest, "invalid request body")
		return
	}
	email := strings.ToLower(strings.TrimSpace(in.Email))
	key := "login|" + c.ClientIP() + "|" + email
	emailKey := "loginemail|" + email
	ipKey := "loginip|" + c.ClientIP()
	const window = 15 * time.Minute
	if a.lim.blocked(key, 5, window) || a.lim.blocked(emailKey, 10, window) || a.lim.blocked(ipKey, 30, window) {
		fail(c, http.StatusTooManyRequests, "Too many failed attempts. Please try again in a few minutes.")
		return
	}
	ctx := c.Request.Context()
	var u authUser
	var hash string
	err := a.db.QueryRow(ctx,
		`SELECT id, name, email, plan, premium_until, password_hash FROM users WHERE email = $1`, email).
		Scan(&u.ID, &u.Name, &u.Email, &u.Plan, &u.PremiumUntil, &hash)
	if errors.Is(err, pgx.ErrNoRows) {
		_ = bcrypt.CompareHashAndPassword(dummyHash, []byte(in.Password))
		a.lim.add(key, window)
		a.lim.add(emailKey, window)
		a.lim.add(ipKey, window)
		fail(c, http.StatusUnauthorized, "Incorrect email or password.")
		return
	}
	if err != nil {
		serverError(c, err)
		return
	}
	if bcrypt.CompareHashAndPassword([]byte(hash), []byte(in.Password)) != nil {
		a.lim.add(key, window)
		a.lim.add(emailKey, window)
		a.lim.add(ipKey, window)
		fail(c, http.StatusUnauthorized, "Incorrect email or password.")
		return
	}
	a.lim.clear(key)
	token, err := a.createSession(ctx, u.ID)
	if err != nil {
		serverError(c, err)
		return
	}
	respond(c, http.StatusOK, gin.H{"token": token, "user": u.public()})
}

func (a *App) logout(c *gin.Context) {
	if _, err := a.db.Exec(c.Request.Context(), `DELETE FROM sessions WHERE token_hash = $1`, c.GetString("tokenHash")); err != nil {
		serverError(c, err)
		return
	}
	c.Status(http.StatusNoContent)
}

func (a *App) me(c *gin.Context) { respond(c, http.StatusOK, curUser(c).public()) }

func (a *App) userPhotoFiles(ctx context.Context, uid int64) ([]string, error) {
	rows, err := a.db.Query(ctx, `SELECT photo_file FROM journal_entries WHERE user_id = $1 AND photo_file IS NOT NULL UNION ALL SELECT photo_file FROM user_profiles WHERE user_id = $1 AND photo_file IS NOT NULL`, uid)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var files []string
	for rows.Next() {
		var f string
		if err := rows.Scan(&f); err != nil {
			return nil, err
		}
		files = append(files, f)
	}
	return files, rows.Err()
}

func (a *App) deleteAccount(c *gin.Context) {
	var in struct {
		Password string `json:"password"`
	}
	if err := c.ShouldBindJSON(&in); err != nil {
		fail(c, http.StatusBadRequest, "invalid request body")
		return
	}
	u := curUser(c)
	ctx := c.Request.Context()
	var hash string
	if err := a.db.QueryRow(ctx, `SELECT password_hash FROM users WHERE id = $1`, u.ID).Scan(&hash); err != nil {
		serverError(c, err)
		return
	}
	delKey := "delacct|" + u.Email
	if a.lim.blocked(delKey, 5, 15*time.Minute) {
		fail(c, http.StatusTooManyRequests, "Too many wrong passwords. Try again in a few minutes.")
		return
	}
	// 403 (not 401) so the app does not mistake a typo for an expired session.
	if bcrypt.CompareHashAndPassword([]byte(hash), []byte(in.Password)) != nil {
		a.lim.add(delKey, 15*time.Minute)
		fail(c, http.StatusForbidden, "Incorrect password.")
		return
	}
	files, err := a.userPhotoFiles(ctx, u.ID)
	if err != nil {
		serverError(c, err)
		return
	}
	if _, err := a.db.Exec(ctx, `DELETE FROM users WHERE id = $1`, u.ID); err != nil {
		serverError(c, err)
		return
	}
	for _, f := range files {
		a.removePhotoFile(f)
	}
	c.Status(http.StatusNoContent)
}

// ---------- premium (demo activation only; no real payment) ----------

func (a *App) activatePremium(c *gin.Context) {
	if !a.cfg.PremiumDemo {
		fail(c, http.StatusNotImplemented, "Payments are not set up on this server yet.")
		return
	}
	var in struct {
		Plan string `json:"plan"`
	}
	if err := c.ShouldBindJSON(&in); err != nil {
		fail(c, http.StatusBadRequest, "invalid request body")
		return
	}
	days := map[string]int{"monthly": 30, "yearly": 365}[in.Plan]
	if days == 0 {
		fail(c, http.StatusBadRequest, "plan must be monthly or yearly")
		return
	}
	u := curUser(c)
	err := a.db.QueryRow(c.Request.Context(), `
		UPDATE users SET plan = 'premium',
			premium_until = GREATEST(COALESCE(premium_until, now()), now()) + make_interval(days => $2)
		WHERE id = $1 RETURNING plan, premium_until`, u.ID, days).Scan(&u.Plan, &u.PremiumUntil)
	if err != nil {
		serverError(c, err)
		return
	}
	respond(c, http.StatusOK, u.public())
}

func (a *App) cancelPremium(c *gin.Context) {
	u := curUser(c)
	if _, err := a.db.Exec(c.Request.Context(),
		`UPDATE users SET plan = 'free', premium_until = NULL WHERE id = $1`, u.ID); err != nil {
		serverError(c, err)
		return
	}
	u.Plan, u.PremiumUntil = "free", nil
	respond(c, http.StatusOK, u.public())
}

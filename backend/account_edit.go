package main

import (
    "errors"
    "fmt"
    "net/http"
    "strings"
    "time"
    "unicode/utf8"

    "github.com/gin-gonic/gin"
    "github.com/jackc/pgx/v5/pgconn"
    "golang.org/x/crypto/bcrypt"
)

// updateMe lets a signed-in user change their name and email.
// Changing the email needs the current password.
func (a *App) updateMe(c *gin.Context) {
    var in struct {
        Name            string `json:"name"`
        Email           string `json:"email"`
        CurrentPassword string `json:"current_password"`
    }
    if err := c.ShouldBindJSON(&in); err != nil {
        fail(c, http.StatusBadRequest, "invalid request body")
        return
    }
    name := strings.TrimSpace(in.Name)
    email := strings.ToLower(strings.TrimSpace(in.Email))
    n := utf8.RuneCountInString(name)
    switch {
    case n < 2 || n > 40:
        fail(c, http.StatusBadRequest, "Name must be 2 to 40 characters.")
        return
    case !validEmail(email):
        fail(c, http.StatusBadRequest, "Enter a valid email address.")
        return
    }
    u := curUser(c)
    ctx := c.Request.Context()
    if email != strings.ToLower(u.Email) {
        key := fmt.Sprintf("chg|%d", u.ID)
        const window = 15 * time.Minute
        if a.lim.blocked(key, 5, window) {
            fail(c, http.StatusTooManyRequests, "Too many attempts. Please try again in a few minutes.")
            return
        }
        var hash string
        if err := a.db.QueryRow(ctx, `SELECT password_hash FROM users WHERE id = $1`, u.ID).Scan(&hash); err != nil {
            serverError(c, err)
            return
        }
        // 403 (not 401) so the app does not mistake a typo for an expired session.
        if bcrypt.CompareHashAndPassword([]byte(hash), []byte(in.CurrentPassword)) != nil {
            a.lim.add(key, window)
            fail(c, http.StatusForbidden, "Incorrect password.")
            return
        }
        a.lim.clear(key)
    }
    var out authUser
    err := a.db.QueryRow(ctx,
        `UPDATE users SET name = $1, email = $2 WHERE id = $3
         RETURNING id, name, email, plan, premium_until`, name, email, u.ID).
        Scan(&out.ID, &out.Name, &out.Email, &out.Plan, &out.PremiumUntil)
    var pg *pgconn.PgError
    if errors.As(err, &pg) && pg.Code == "23505" {
        fail(c, http.StatusConflict, "That email is already used by another account.")
        return
    }
    if err != nil {
        serverError(c, err)
        return
    }
    respond(c, http.StatusOK, out.public())
}
package main

import (
	"bytes"
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"math"
	"net/http"
	"net/url"
	"os"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5"
)

type premiumPlanDef struct {
	ID    string
	Name  string
	Days  int
	Paise int
}

func envPaise(key string, def int) int {
	n, err := strconv.Atoi(strings.TrimSpace(os.Getenv(key)))
	if err != nil || n < 100 {
		return def
	}
	return n
}

func premiumPlanList() []premiumPlanDef {
	return []premiumPlanDef{
		{"monthly", "Skinora Premium - 30 Days", 30, envPaise("PRICE_MONTHLY_PAISE", 12900)},
		{"quarterly", "Skinora Premium - 90 Days", 90, envPaise("PRICE_QUARTERLY_PAISE", 29900)},
		{"yearly", "Skinora Premium - 365 Days", 365, envPaise("PRICE_YEARLY_PAISE", 99900)},
	}
}

func premiumPlanByID(id string) (premiumPlanDef, bool) {
	for _, p := range premiumPlanList() {
		if p.ID == id {
			return p, true
		}
	}
	return premiumPlanDef{}, false
}

var errNoOrder = errors.New("order not found")
var orderIDPattern = regexp.MustCompile(`^[A-Za-z0-9_-]{1,50}$`)
var cashfreeHTTP = &http.Client{Timeout: 20 * time.Second}

func cashfreeConfigured() bool {
	return strings.TrimSpace(os.Getenv("CASHFREE_APP_ID")) != "" && strings.TrimSpace(os.Getenv("CASHFREE_SECRET_KEY")) != ""
}

func cashfreeMode() string {
	if strings.EqualFold(strings.TrimSpace(os.Getenv("CASHFREE_ENV")), "production") {
		return "production"
	}
	return "sandbox"
}

func cashfreeBase() string {
	if cashfreeMode() == "production" {
		return "https://api.cashfree.com/pg"
	}
	return "https://sandbox.cashfree.com/pg"
}

// cashfreeCall talks to the Cashfree PG API. Keys never leave the server.
func cashfreeCall(ctx context.Context, method, path string, payload any) (int, []byte, error) {
	var rd io.Reader
	if payload != nil {
		b, err := json.Marshal(payload)
		if err != nil {
			return 0, nil, err
		}
		rd = bytes.NewReader(b)
	}
	req, err := http.NewRequestWithContext(ctx, method, cashfreeBase()+path, rd)
	if err != nil {
		return 0, nil, err
	}
	req.Header.Set("x-client-id", strings.TrimSpace(os.Getenv("CASHFREE_APP_ID")))
	req.Header.Set("x-client-secret", strings.TrimSpace(os.Getenv("CASHFREE_SECRET_KEY")))
	req.Header.Set("x-api-version", "2023-08-01")
	req.Header.Set("Content-Type", "application/json")
	res, err := cashfreeHTTP.Do(req)
	if err != nil {
		return 0, nil, err
	}
	defer res.Body.Close()
	body, _ := io.ReadAll(io.LimitReader(res.Body, 1<<20))
	return res.StatusCode, body, nil
}

func (a *App) ensurePaymentsTable(ctx context.Context) error {
	stmts := []string{
		`CREATE TABLE IF NOT EXISTS payments (
order_id TEXT PRIMARY KEY,
user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
plan TEXT NOT NULL,
amount_paise INT NOT NULL,
status TEXT NOT NULL DEFAULT 'created',
payment_id TEXT,
created_at TIMESTAMPTZ NOT NULL DEFAULT now())`,
		`ALTER TABLE payments ADD COLUMN IF NOT EXISTS provider TEXT NOT NULL DEFAULT 'razorpay'`,
		`ALTER TABLE payments ADD COLUMN IF NOT EXISTS method TEXT NOT NULL DEFAULT ''`,
	}
	for _, s := range stmts {
		if _, err := a.db.Exec(ctx, s); err != nil {
			return err
		}
	}
	return nil
}

func newOrderID() string {
	b := make([]byte, 8)
	_, _ = rand.Read(b)
	return "SKN-" + strings.ToUpper(hex.EncodeToString(b))
}

// GET /api/premium/plans
func (a *App) premiumPlansList(c *gin.Context) {
	out := make([]gin.H, 0)
	for _, p := range premiumPlanList() {
		out = append(out, gin.H{"id": p.ID, "name": p.Name, "days": p.Days, "amount_paise": p.Paise})
	}
	respond(c, http.StatusOK, gin.H{"enabled": cashfreeConfigured(), "mode": cashfreeMode(), "plans": out})
}

// POST /api/premium/order {"plan":"monthly"|"quarterly"|"yearly"}
func (a *App) createPremiumOrder(c *gin.Context) {
	if !cashfreeConfigured() {
		fail(c, http.StatusServiceUnavailable, "Payments are not set up on this server.")
		return
	}
	var in struct {
		Plan string `json:"plan"`
	}
	if err := c.ShouldBindJSON(&in); err != nil {
		fail(c, http.StatusBadRequest, "invalid request body")
		return
	}
	p, ok := premiumPlanByID(in.Plan)
	if !ok {
		fail(c, http.StatusBadRequest, "unknown plan")
		return
	}
	u := curUser(c)
	key := fmt.Sprintf("ord|%d", u.ID)
	if a.lim.blocked(key, 10, time.Hour) {
		fail(c, http.StatusTooManyRequests, "Too many payment attempts. Please try again later.")
		return
	}
	a.lim.add(key, time.Hour)
	ctx := c.Request.Context()
	if err := a.ensurePaymentsTable(ctx); err != nil {
		serverError(c, err)
		return
	}
	phone := strings.TrimSpace(os.Getenv("CASHFREE_CUSTOMER_PHONE"))
	if phone == "" {
		phone = "9999999999" // sandbox placeholder: collect a real number before going live
	}
	orderID := newOrderID()
	code, body, err := cashfreeCall(ctx, http.MethodPost, "/orders", map[string]any{
		"order_id":       orderID,
		"order_amount":   float64(p.Paise) / 100,
		"order_currency": "INR",
		"order_note":     p.Name,
		"customer_details": map[string]any{
			"customer_id":    fmt.Sprintf("u%d", u.ID),
			"customer_email": u.Email,
			"customer_phone": phone,
		},
	})
	if err != nil {
		log.Printf("cashfree order request failed: %v", err)
		fail(c, http.StatusBadGateway, "Could not start the payment. Please try again.")
		return
	}
	if code/100 != 2 {
		log.Printf("cashfree order failed: %d %s", code, string(body))
		fail(c, http.StatusBadGateway, "Could not start the payment. Please try again.")
		return
	}
	var out struct {
		SessionID string `json:"payment_session_id"`
	}
	if err := json.Unmarshal(body, &out); err != nil || out.SessionID == "" {
		fail(c, http.StatusBadGateway, "Could not start the payment. Please try again.")
		return
	}
	if _, err := a.db.Exec(ctx,
		`INSERT INTO payments (order_id, user_id, plan, amount_paise, status, provider) VALUES ($1, $2, $3, $4, 'created', 'cashfree')`,
		orderID, u.ID, p.ID, p.Paise); err != nil {
		serverError(c, err)
		return
	}
	respond(c, http.StatusOK, gin.H{
		"order_id":           orderID,
		"payment_session_id": out.SessionID,
		"mode":               cashfreeMode(),
		"amount_paise":       p.Paise,
		"plan":               p.ID,
	})
}

// settleOrder asks Cashfree for the order status. Only a PAID order with the
// right amount extends Premium, and only once. Returns (paid, error).
func (a *App) settleOrder(ctx context.Context, uid int64, orderID string) (bool, error) {
	var status, planID string
	var paise int
	err := a.db.QueryRow(ctx,
		`SELECT status, plan, amount_paise FROM payments WHERE order_id = $1 AND user_id = $2 AND provider = 'cashfree'`,
		orderID, uid).Scan(&status, &planID, &paise)
	if errors.Is(err, pgx.ErrNoRows) {
		return false, errNoOrder
	}
	if err != nil {
		return false, err
	}
	if status == "paid" {
		return true, nil
	}
	code, body, err := cashfreeCall(ctx, http.MethodGet, "/orders/"+url.PathEscape(orderID), nil)
	if err != nil {
		return false, err
	}
	if code != http.StatusOK {
		log.Printf("cashfree order lookup failed: %d %s", code, string(body))
		return false, fmt.Errorf("cashfree order lookup returned %d", code)
	}
	var o struct {
		OrderStatus string          `json:"order_status"`
		OrderAmount float64         `json:"order_amount"`
		CFOrderID   json.RawMessage `json:"cf_order_id"`
	}
	if err := json.Unmarshal(body, &o); err != nil {
		return false, err
	}
	switch strings.ToUpper(o.OrderStatus) {
	case "PAID":
	case "EXPIRED", "TERMINATED", "TERMINATION_REQUESTED":
		_, _ = a.db.Exec(ctx, `UPDATE payments SET status = 'failed' WHERE order_id = $1 AND status = 'created'`, orderID)
		return false, nil
	default:
		return false, nil
	}
	if int(math.Round(o.OrderAmount*100)) != paise {
		log.Printf("cashfree amount mismatch for order %s", orderID)
		return false, errors.New("amount mismatch")
	}
	days := 30
	if p, ok := premiumPlanByID(planID); ok {
		days = p.Days
	}
	tx, err := a.db.Begin(ctx)
	if err != nil {
		return false, err
	}
	defer tx.Rollback(ctx)
	cfID := strings.Trim(string(o.CFOrderID), `"`)
	tag, err := tx.Exec(ctx,
		`UPDATE payments SET status = 'paid', payment_id = $1 WHERE order_id = $2 AND user_id = $3 AND status = 'created'`,
		cfID, orderID, uid)
	if err != nil {
		return false, err
	}
	if tag.RowsAffected() == 0 {
		return true, nil // another request already settled it
	}
	if _, err := tx.Exec(ctx, `UPDATE users SET plan = 'premium',
premium_until = GREATEST(COALESCE(premium_until, now()), now()) + make_interval(days => $1::int)
WHERE id = $2`, days, uid); err != nil {
		return false, err
	}
	if err := tx.Commit(ctx); err != nil {
		return false, err
	}
	return true, nil
}

// POST /api/premium/verify {"order_id":"SKN-..."}
func (a *App) verifyPremium(c *gin.Context) {
	if !cashfreeConfigured() {
		fail(c, http.StatusServiceUnavailable, "Payments are not set up on this server.")
		return
	}
	var in struct {
		OrderID string `json:"order_id"`
	}
	if err := c.ShouldBindJSON(&in); err != nil || !orderIDPattern.MatchString(strings.TrimSpace(in.OrderID)) {
		fail(c, http.StatusBadRequest, "invalid request body")
		return
	}
	u := curUser(c)
	ctx := c.Request.Context()
	if err := a.ensurePaymentsTable(ctx); err != nil {
		serverError(c, err)
		return
	}
	paid, err := a.settleOrder(ctx, u.ID, strings.TrimSpace(in.OrderID))
	if errors.Is(err, errNoOrder) {
		fail(c, http.StatusNotFound, "Payment not found.")
		return
	}
	if err != nil {
		log.Printf("verify premium: %v", err)
		fail(c, http.StatusBadGateway, "Could not confirm the payment right now. Please check again in a minute.")
		return
	}
	if !paid {
		fail(c, http.StatusConflict, "Payment was not completed.")
		return
	}
	var out authUser
	if err := a.db.QueryRow(ctx,
		`SELECT id, name, email, plan, premium_until FROM users WHERE id = $1`, u.ID).
		Scan(&out.ID, &out.Name, &out.Email, &out.Plan, &out.PremiumUntil); err != nil {
		serverError(c, err)
		return
	}
	respond(c, http.StatusOK, out.public())
}

// reconcileOrders settles recent unfinished orders, so a payment is not lost
// if the user closed the app before it was verified.
func (a *App) reconcileOrders(ctx context.Context, uid int64) {
	rows, err := a.db.Query(ctx,
		`SELECT order_id FROM payments WHERE user_id = $1 AND provider = 'cashfree' AND status = 'created'
AND created_at > now() - interval '2 days' ORDER BY created_at DESC LIMIT 5`, uid)
	if err != nil {
		return
	}
	var ids []string
	for rows.Next() {
		var id string
		if rows.Scan(&id) == nil {
			ids = append(ids, id)
		}
	}
	rows.Close()
	for _, id := range ids {
		_, _ = a.settleOrder(ctx, uid, id)
	}
}

// GET /api/premium/payments
func (a *App) premiumPaymentHistory(c *gin.Context) {
	u := curUser(c)
	ctx := c.Request.Context()
	if err := a.ensurePaymentsTable(ctx); err != nil {
		serverError(c, err)
		return
	}
	if cashfreeConfigured() {
		a.reconcileOrders(ctx, u.ID)
	}
	rows, err := a.db.Query(ctx, `SELECT order_id, plan, amount_paise, method, status, created_at
FROM payments WHERE user_id = $1 AND provider = 'cashfree' AND status IN ('paid','failed')
ORDER BY created_at DESC LIMIT 50`, u.ID)
	if err != nil {
		serverError(c, err)
		return
	}
	defer rows.Close()
	out := make([]gin.H, 0)
	for rows.Next() {
		var orderID, planID, method, status string
		var paise int
		var created time.Time
		if err := rows.Scan(&orderID, &planID, &paise, &method, &status, &created); err != nil {
			serverError(c, err)
			return
		}
		name := planID
		if p, ok := premiumPlanByID(planID); ok {
			name = p.Name
		}
		st := "failed"
		if status == "paid" {
			st = "success"
		}
		out = append(out, gin.H{
			"txn_id": orderID, "plan_name": name, "amount_paise": paise,
			"method": method, "status": st, "is_demo": false, "created_at": created,
		})
	}
	respond(c, http.StatusOK, out)
}

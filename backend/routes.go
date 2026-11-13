package main

import (
	"context"
	"errors"
	"log"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
)

// originAllowed checks whether the request origin is allowed.
func (a *App) originAllowed(origin string) bool {
	if origin == "" {
		return false
	}

	if len(a.cfg.AllowedOrigins) == 0 {
		return origin == "http://localhost" ||
			strings.HasPrefix(origin, "http://localhost:") ||
			strings.HasPrefix(origin, "http://127.0.0.1:")
	}

	for _, allowedOrigin := range a.cfg.AllowedOrigins {
		if allowedOrigin == origin {
			return true
		}
	}

	return false
}

// requestLimits applies request timeouts and body size limits.
func requestLimits(timeout time.Duration) gin.HandlerFunc {
	return func(c *gin.Context) {
		path := c.Request.URL.Path

		isAI := c.Request.Method == http.MethodPost &&
			strings.HasSuffix(path, "/skin-analysis")

		requestTimeout := timeout
		if isAI {
			requestTimeout = 100 * time.Second
		}

		ctx, cancel := context.WithTimeout(
			c.Request.Context(),
			requestTimeout,
		)
		defer cancel()

		c.Request = c.Request.WithContext(ctx)

		// Default request body limit: 1 MiB.
		limit := int64(1 << 20)

		// Allow additional space for uploaded photos.
		if c.Request.Method == http.MethodPost &&
			strings.HasSuffix(path, "/photo") {
			limit = maxPhotoBytes + (1 << 20)
		}

		// AI analysis may contain an image and multipart metadata.
		if isAI {
			limit = int64(aiMaxTotalBytes) + (1 << 20)
		}

		c.Request.Body = http.MaxBytesReader(
			c.Writer,
			c.Request.Body,
			limit,
		)

		c.Next()
	}
}

// router registers middleware and application routes.
func (a *App) router() *gin.Engine {
	r := gin.New()
	if err := r.SetTrustedProxies([]string{"127.0.0.1", "10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"}); err != nil {
		log.Fatal(err)
	}

	r.Use(
		gin.Logger(),
		gin.Recovery(),
	)

	r.Use(cors.New(cors.Config{
		AllowOriginFunc: a.originAllowed,
		AllowMethods: []string{
			http.MethodGet,
			http.MethodPost,
			http.MethodPut,
			http.MethodDelete,
			http.MethodOptions,
		},
		AllowHeaders: []string{
			"Content-Type",
			"Authorization",
		},
		MaxAge: 12 * time.Hour,
	}))

	r.Use(requestLimits(20 * time.Second))

	api := r.Group("/api")

	// Public routes.
	api.GET("/health", a.health)
	api.POST("/auth/register", validateRegister(), a.register)
	api.POST("/auth/login", validateLogin(), a.login)

	// Protected routes.
	p := api.Group("")
	p.Use(a.requireAuth())

	// AI skin analysis.
	registerAIRoutes(p, a)

	// Authentication.
	p.GET("/auth/me", a.me)
	p.PUT("/auth/me", a.updateMe)
	p.POST("/auth/logout", a.logout)
	p.DELETE("/auth/account", a.deleteAccount)

	// Premium.
	p.POST("/premium/order", a.createPremiumOrder)
	p.POST("/premium/verify", a.verifyPremium)
	p.GET("/premium/plans", a.premiumPlansList)
	p.GET("/premium/payments", a.premiumPaymentHistory)

	// Profile.
	p.GET("/profile", a.getProfile)
	p.PUT("/profile", a.putProfile)
	p.POST("/profile/photo", a.uploadProfilePhoto)
	p.GET("/profile/photo", a.getProfilePhoto)
	p.DELETE("/profile/photo", a.deleteProfilePhoto)

	// Settings.
	p.GET("/settings", a.getSettings)
	p.PUT("/settings", validateSettings(), a.putSettings)

	// Routine.
	p.GET("/routine", a.listRoutine)
	p.GET("/routine/history", a.routineHistoryHandler)
	p.POST("/routine/items", a.createRoutineItem)
	p.PUT("/routine/items/:id", a.updateRoutineItem)
	p.DELETE("/routine/items/:id", a.deleteRoutineItem)
	p.PUT("/routine/items/:id/completion", a.setCompletion)
	p.DELETE("/routine/completions", a.resetCompletions)

	// Water.
	p.GET("/water", a.getWater)
	p.POST("/water", a.addWater)
	p.DELETE("/water/last", a.removeLastWater)
	p.GET("/water/history", a.waterHistoryHandler)

	// Sleep.
	p.GET("/sleep", a.listSleep)
	p.POST("/sleep", a.createSleep)
	p.PUT("/sleep/:id", a.updateSleep)
	p.DELETE("/sleep/:id", a.deleteSleep)

	// Journal.
	p.GET("/journal", a.listJournal)
	p.POST(
		"/journal",
		a.journalLimit(),
		a.createJournal,
	)
	p.PUT("/journal/:id", a.updateJournal)
	p.DELETE("/journal/:id", a.deleteJournal)
	p.POST("/journal/:id/photo", a.uploadPhoto)
	p.GET("/journal/:id/photo", a.getPhoto)
	p.DELETE("/journal/:id/photo", a.deletePhoto)

	// Insights.
	p.GET("/insights", a.insights)
	p.GET("/insights/deep", a.deepInsights)

	// Notifications.
	registerNotificationRoutes(p, a)
	registerReminderRoutes(p, a)

	// User data.
	p.DELETE("/data", a.clearData)

	return r
}

// respond sends a successful or custom-status JSON response.
func respond(c *gin.Context, status int, data any) {
	c.JSON(status, gin.H{
		"data": data,
	})
}

// fail sends an error response and aborts the request.
func fail(c *gin.Context, status int, msg string) {
	c.AbortWithStatusJSON(status, gin.H{
		"error": msg,
	})
}

// serverError logs the internal error but returns a generic message.
func serverError(c *gin.Context, err error) {
	log.Printf(
		"ERROR %s %s: %v",
		c.Request.Method,
		c.Request.URL.Path,
		err,
	)

	fail(
		c,
		http.StatusInternalServerError,
		"internal server error",
	)
}

// fmtDay formats a date as YYYY-MM-DD.
func fmtDay(t time.Time) string {
	return t.Format("2006-01-02")
}

// parseDate validates and parses a date in YYYY-MM-DD format.
func parseDate(s string) (time.Time, error) {
	t, err := time.Parse("2006-01-02", s)
	if err != nil {
		return time.Time{}, errors.New(
			"date must be in YYYY-MM-DD format",
		)
	}

	if t.Year() < 2000 || t.Year() > 2100 {
		return time.Time{}, errors.New(
			"date is out of range",
		)
	}

	return t, nil
}

// dateParam reads and validates the date query parameter.
func dateParam(c *gin.Context) (time.Time, bool) {
	t, err := parseDate(c.Query("date"))
	if err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return time.Time{}, false
	}

	return t, true
}

// idParam reads and validates a positive integer route parameter.
func idParam(c *gin.Context) (int64, bool) {
	id, err := strconv.ParseInt(
		c.Param("id"),
		10,
		64,
	)

	if err != nil || id <= 0 {
		fail(c, http.StatusBadRequest, "invalid id")
		return 0, false
	}

	return id, true
}

// intQuery returns a bounded integer query parameter.
func intQuery(
	c *gin.Context,
	key string,
	def int,
	lo int,
	hi int,
) int {
	v, err := strconv.Atoi(c.Query(key))
	if err != nil {
		return def
	}

	if v < lo {
		return lo
	}

	if v > hi {
		return hi
	}

	return v
}

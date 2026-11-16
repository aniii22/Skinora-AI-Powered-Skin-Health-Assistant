package main

import (
	"fmt"
	"strings"
	"time"
	_ "time/tzdata"

	"github.com/gin-gonic/gin"
)

// reqTZ returns the client's IANA time zone from the X-Timezone header.
// It returns "" when the header is missing or invalid; SQL then falls back to
// the database session time zone, which is the old behaviour.
func reqTZ(c *gin.Context) string {
	n := strings.TrimSpace(c.GetHeader("X-Timezone"))
	if n == "" || len(n) > 64 || strings.EqualFold(n, "Local") {
		return ""
	}
	if _, err := time.LoadLocation(n); err != nil {
		return ""
	}
	return n
}

// monthStartSQL returns SQL for "start of this month in the client's time zone".
// n is the placeholder number holding reqTZ(c). Use it for EVERY per-user month
// boundary. Never write a month-start date_trunc without a time zone.
func monthStartSQL(n int) string {
	return fmt.Sprintf(
		"date_trunc('month', now() AT TIME ZONE COALESCE(NULLIF($%[1]d::text,''), current_setting('TimeZone'))) AT TIME ZONE COALESCE(NULLIF($%[1]d::text,''), current_setting('TimeZone'))",
		n)
}

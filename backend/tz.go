package main

import (
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

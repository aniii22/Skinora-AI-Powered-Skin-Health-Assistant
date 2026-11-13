package main

import (
	"fmt"

	"github.com/gin-gonic/gin"
)

// Free plan: at most this many journal entries per calendar month.
const freeJournalPerMonth = 10

// journalLimit runs before createJournal and blocks free users over the limit.
func (a *App) journalLimit() gin.HandlerFunc {
	return func(c *gin.Context) {
		u := curUser(c)
		if u.premium() {
			c.Next()
			return
		}
		var n int
		err := a.db.QueryRow(c.Request.Context(),
			`SELECT COUNT(*)::int FROM journal_entries
 WHERE user_id = $1 AND created_at >= date_trunc('month', now() AT TIME ZONE COALESCE(NULLIF($2::text,''), current_setting('TimeZone'))) AT TIME ZONE COALESCE(NULLIF($2::text,''), current_setting('TimeZone'))`, u.ID, reqTZ(c)).Scan(&n)
		if err != nil {
			serverError(c, err)
			c.Abort()
			return
		}
		if n >= freeJournalPerMonth {
			premiumRequired(c, fmt.Sprintf(
				"the free plan allows %d journal entries per month. Upgrade for unlimited entries.",
				freeJournalPerMonth))
			c.Abort()
			return
		}
		c.Next()
	}
}

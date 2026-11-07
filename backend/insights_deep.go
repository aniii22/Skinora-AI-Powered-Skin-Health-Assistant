package main

import (
	"fmt"
	"time"

	"github.com/gin-gonic/gin"
)

type avgGroup struct {
	sum float64
	n   int
}

func (g *avgGroup) add(v float64) {
	g.sum += v
	g.n++
}

func (g avgGroup) avg() float64 {
	if g.n == 0 {
		return 0
	}
	return g.sum / float64(g.n)
}

func compareText(cond string, hi, lo avgGroup) (string, bool) {
	if hi.n < 3 || lo.n < 3 {
		return "", false
	}
	return fmt.Sprintf(
		"On days when %s, your skin rating averaged %.1f, versus %.1f on other days (%d vs %d days).",
		cond, hi.avg(), lo.avg(), hi.n, lo.n), true
}

// deepInsights is Premium only: rule-based links between habits and skin rating.
func (a *App) deepInsights(c *gin.Context) {
	u := curUser(c)
	if !u.premium() {
		premiumRequired(c, "deep insights are part of Premium.")
		return
	}
	from, to, days, ok := rangeParams(c, 30)
	if !ok {
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

	sleepMin := map[string]int{}
	srows, err := a.db.Query(ctx, `
SELECT wake_time::date, AVG(EXTRACT(EPOCH FROM (wake_time - sleep_start)) / 60)::int
FROM sleep_logs
WHERE user_id = $3 AND wake_time::date BETWEEN $1::date AND $2::date
GROUP BY 1`, from, to, u.ID)
	if err != nil {
		serverError(c, err)
		return
	}
	for srows.Next() {
		var d time.Time
		var m int
		if err := srows.Scan(&d, &m); err != nil {
			srows.Close()
			serverError(c, err)
			return
		}
		sleepMin[fmtDay(d)] = m
	}
	srows.Close()
	if err := srows.Err(); err != nil {
		serverError(c, err)
		return
	}

	ratings := map[string]float64{}
	jrows, err := a.db.Query(ctx, `
SELECT day, AVG(rating)::float8
FROM journal_entries
WHERE user_id = $3 AND rating IS NOT NULL AND day BETWEEN $1::date AND $2::date
GROUP BY day`, from, to, u.ID)
	if err != nil {
		serverError(c, err)
		return
	}
	for jrows.Next() {
		var d time.Time
		var r float64
		if err := jrows.Scan(&d, &r); err != nil {
			jrows.Close()
			serverError(c, err)
			return
		}
		ratings[fmtDay(d)] = r
	}
	jrows.Close()
	if err := jrows.Err(); err != nil {
		serverError(c, err)
		return
	}

	routineByDay := map[string]routineDay{}
	for _, r := range routine {
		routineByDay[r.Day] = r
	}

	var waterHi, waterLo, sleepHi, sleepLo, routHi, routLo avgGroup
	goalDays := 0
	for _, w := range water {
		if w.TotalML >= goal {
			goalDays++
		}
		rating, hasRating := ratings[w.Day]
		if !hasRating {
			continue
		}
		if w.TotalML >= goal {
			waterHi.add(rating)
		} else {
			waterLo.add(rating)
		}
		if sm, hasSleep := sleepMin[w.Day]; hasSleep {
			if sm >= 420 {
				sleepHi.add(rating)
			} else {
				sleepLo.add(rating)
			}
		}
		if rd := routineByDay[w.Day]; rd.Total > 0 {
			if rd.Completed*100 >= rd.Total*80 {
				routHi.add(rating)
			} else {
				routLo.add(rating)
			}
		}
	}

	insights := []string{}
	if s, ok := compareText("you hit your water goal", waterHi, waterLo); ok {
		insights = append(insights, s)
	}
	if s, ok := compareText("you slept 7+ hours", sleepHi, sleepLo); ok {
		insights = append(insights, s)
	}
	if s, ok := compareText("you finished 80%+ of your routine", routHi, routLo); ok {
		insights = append(insights, s)
	}
	if len(insights) == 0 {
		insights = append(insights,
			"Add a journal rating on a few days, along with water, sleep and routine, to unlock personal patterns.")
	}

	streak := 0
	for i := len(routine) - 1; i >= 0; i-- {
		if routine[i].Total > 0 && routine[i].Completed >= routine[i].Total {
			streak++
		} else {
			break
		}
	}

	respond(c, 200, gin.H{
		"days":            days,
		"routine_streak":  streak,
		"water_goal_days": goalDays,
		"rated_days":      len(ratings),
		"insights":        insights,
	})
}

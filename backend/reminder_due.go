package main

// dueWindow reports whether a reminder at minute-of-day rMin is due at nowMin.
// A reminder is due for 5 minutes after its time. The difference wraps at
// midnight, so a 23:58 reminder is still due at 00:01. prevDay is true when
// the reminder belongs to the previous calendar day.
func dueWindow(nowMin, rMin int) (due, prevDay bool) {
	diff := nowMin - rMin
	if diff < 0 {
		diff += 1440
		prevDay = true
	}
	return diff <= 5, prevDay
}

package main

import (
"fmt"
"strings"
"testing"
)

// Guards the single source of truth for per-user month boundaries.
// If someone edits monthStartSQL and drops the time zone, this fails.
func TestMonthStartSQLShape(t *testing.T) {
for _, n := range []int{1, 2, 3, 7} {
s := monthStartSQL(n)
param := fmt.Sprintf("$%d::text", n)

if got := strings.Count(s, param); got != 2 {
t.Errorf("monthStartSQL(%d): %q used %d times, want 2", n, param, got)
}
if got := strings.Count(s, "AT TIME ZONE"); got != 2 {
t.Errorf("monthStartSQL(%d): AT TIME ZONE appears %d times, want 2", n, got)
}
if got := strings.Count(s, "current_setting('TimeZone')"); got != 2 {
t.Errorf("monthStartSQL(%d): server-zone fallback appears %d times, want 2", n, got)
}
if !strings.HasPrefix(s, "date_trunc('month', now() AT TIME ZONE") {
t.Errorf("monthStartSQL(%d): must truncate in the user's zone, got %q", n, s)
}
}
}
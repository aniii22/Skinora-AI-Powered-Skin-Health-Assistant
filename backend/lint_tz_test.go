package main

import (
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"testing"
)

// Fails if any non-test .go file uses a time-zone-naive month/day boundary.
func TestNoNaiveDateTrunc(t *testing.T) {
	re := regexp.MustCompile(`(?i)date_trunc\(\s*'(month|day)'\s*,\s*now\(\)\s*\)`)
	files, _ := filepath.Glob("*.go")
	for _, f := range files {
		if strings.HasSuffix(f, "_test.go") {
			continue
		}
		b, err := os.ReadFile(f)
		if err != nil {
			t.Fatal(err)
		}
		if re.Match(b) {
			t.Errorf("%s: naive date_trunc(..., now()). Use monthStartSQL() from tz.go", f)
		}
	}
}

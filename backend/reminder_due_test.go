package main

import "testing"

func TestDueWindow(t *testing.T) {
	cases := []struct {
		now, r       int
		due, prevDay bool
	}{
		{600, 600, true, false},
		{605, 600, true, false},
		{606, 600, false, false},
		{599, 600, false, true},
		{1438, 1438, true, false},
		{1439, 1438, true, false},
		{0, 1438, true, true},
		{3, 1438, true, true},
		{4, 1438, false, true},
		{1, 1439, true, true},
		{7, 1439, false, true},
	}
	for _, c := range cases {
		due, prev := dueWindow(c.now, c.r)
		if due != c.due || prev != c.prevDay {
			t.Fatalf("dueWindow(%d,%d) = %v,%v want %v,%v", c.now, c.r, due, prev, c.due, c.prevDay)
		}
	}
}

package main

import "time"

// sweepLoop periodically drops old rate-limit entries so memory cannot grow forever.
func (l *limiter) sweepLoop() {
	t := time.NewTicker(10 * time.Minute)
	defer t.Stop()
	for range t.C {
		l.sweep(48 * time.Hour)
	}
}

func (l *limiter) sweep(maxAge time.Duration) {
	l.mu.Lock()
	defer l.mu.Unlock()
	if len(l.hits) > 200000 {
		l.hits = map[string][]time.Time{}
		return
	}
	for k := range l.hits {
		l.prune(k, maxAge)
	}
}

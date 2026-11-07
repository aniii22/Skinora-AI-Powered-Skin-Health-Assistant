package main

import (
	"bytes"
	"context"
	"errors"
	"io"
	"log"
	"net/http"
	"os"
	"strings"
	"sync"
	"sync/atomic"
	"time"
)

// Groq key rotation: GROQ_API_KEY plus GROQ_API_KEY_2..4 from the environment.
var (
	groqNext   uint32
	groqCool   sync.Map // key -> time.Time (skip this key until then)
	groqClient = &http.Client{Timeout: 100 * time.Second}
)

func groqKeys() []string {
	var keys []string
	seen := map[string]bool{}
	for _, name := range []string{"GROQ_API_KEY", "GROQ_API_KEY_2", "GROQ_API_KEY_3", "GROQ_API_KEY_4"} {
		k := strings.TrimSpace(os.Getenv(name))
		if k != "" && !seen[k] {
			seen[k] = true
			keys = append(keys, k)
		}
	}
	return keys
}

func groqCooling(key string) bool {
	if v, ok := groqCool.Load(key); ok {
		if until, ok := v.(time.Time); ok && time.Now().Before(until) {
			return true
		}
	}
	return false
}

// groqPost sends the payload, rotating to the next key on 429, 401/403,
// 5xx or network errors. It never logs a key.
func groqPost(ctx context.Context, payload []byte) (int, []byte, error) {
	keys := groqKeys()
	if len(keys) == 0 {
		return 0, nil, errors.New("no Groq API key configured")
	}
	start := int(atomic.AddUint32(&groqNext, 1)-1) % len(keys)
	var order []string
	for i := range keys {
		k := keys[(start+i)%len(keys)]
		if !groqCooling(k) {
			order = append(order, k)
		}
	}
	if len(order) == 0 {
		for i := range keys {
			order = append(order, keys[(start+i)%len(keys)])
		}
	}
	var lastStatus int
	var lastBody []byte
	var lastErr error
	for n, key := range order {
		if err := ctx.Err(); err != nil {
			return 0, nil, err
		}
		req, err := http.NewRequestWithContext(ctx, http.MethodPost, groqURL, bytes.NewReader(payload))
		if err != nil {
			return 0, nil, err
		}
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Authorization", "Bearer "+key)
		resp, err := groqClient.Do(req)
		if err != nil {
			lastErr = err
			log.Printf("groq: key %d/%d request failed: %v", n+1, len(order), err)
			continue
		}
		body, _ := io.ReadAll(io.LimitReader(resp.Body, 4<<20))
		resp.Body.Close()
		switch {
		case resp.StatusCode == http.StatusTooManyRequests:
			groqCool.Store(key, time.Now().Add(60*time.Second))
		case resp.StatusCode == http.StatusUnauthorized || resp.StatusCode == http.StatusForbidden:
			groqCool.Store(key, time.Now().Add(10*time.Minute))
		case resp.StatusCode >= 500:
		default:
			return resp.StatusCode, body, nil
		}
		lastStatus, lastBody = resp.StatusCode, body
		log.Printf("groq: key %d/%d returned %d, trying the next key", n+1, len(order), resp.StatusCode)
	}
	if lastStatus != 0 {
		return lastStatus, lastBody, nil
	}
	return 0, nil, lastErr
}

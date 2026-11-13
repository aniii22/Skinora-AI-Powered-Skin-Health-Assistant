package main

import (
	"context"
	"errors"
	"log"
	"net/http"
	"os"
	"time"
)

func main() {
	cfg := loadConfig()
	if cfg.DatabaseURL == "" {
		log.Fatal("DATABASE_URL is not set (check backend/.env)")
	}

	ctx := context.Background()
	pool, err := openDB(ctx, cfg.DatabaseURL)
	if err != nil {
		log.Fatal(err)
	}
	defer pool.Close()

	mctx, cancel := context.WithTimeout(ctx, 60*time.Second)
	defer cancel()
	if err := migrate(mctx, pool); err != nil {
		log.Fatal(err)
	}
	if err := os.MkdirAll(cfg.UploadDir, 0o750); err != nil {
		log.Fatal(err)
	}

	app := &App{db: pool, cfg: cfg, lim: newLimiter()}
	srv := &http.Server{
		Addr:              ":" + cfg.Port,
		Handler:           app.router(),
		ReadHeaderTimeout: 10 * time.Second,
		ReadTimeout:       60 * time.Second,
		WriteTimeout:      120 * time.Second,
		IdleTimeout:       120 * time.Second,
	}
	log.Printf("Skinora API listening on :%s (premium demo: %v)", cfg.Port, cfg.PremiumDemo)
	if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		log.Fatal(err)
	}
}

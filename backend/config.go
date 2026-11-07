package main

import (
	"bufio"
	"os"
	"strings"
)

type Config struct {
	Port           string
	DatabaseURL    string
	AllowedOrigins []string
	UploadDir      string
	PremiumDemo    bool
}

func loadDotEnv(path string) {
	f, err := os.Open(path)
	if err != nil {
		return
	}
	defer f.Close()
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		line := strings.TrimSpace(sc.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		k, v, ok := strings.Cut(line, "=")
		if !ok {
			continue
		}
		k = strings.TrimSpace(k)
		v = strings.Trim(strings.TrimSpace(v), `"'`)
		if os.Getenv(k) == "" {
			_ = os.Setenv(k, v)
		}
	}
}

func getenv(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func loadConfig() Config {
	loadDotEnv(".env")
	var origins []string
	for _, o := range strings.Split(os.Getenv("ALLOWED_ORIGINS"), ",") {
		if o = strings.TrimSpace(o); o != "" {
			origins = append(origins, o)
		}
	}
	return Config{
		Port:           getenv("PORT", "8080"),
		DatabaseURL:    os.Getenv("DATABASE_URL"),
		AllowedOrigins: origins,
		UploadDir:      getenv("UPLOAD_DIR", "uploads"),
		PremiumDemo:    os.Getenv("PREMIUM_DEMO") == "true",
	}
}

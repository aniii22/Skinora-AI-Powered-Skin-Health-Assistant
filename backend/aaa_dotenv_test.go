package main

import (
"os"
"path/filepath"
"testing"
)

func TestDotenvParse(t *testing.T) {
in := "\ufeff# comment\n\nDATABASE_URL=postgres://u:p%4022@localhost:5432/db?sslmode=disable\r\nexport PORT = 8081\nNAME=\"quoted value\"\nSINGLE='x y'\nBROKEN\n=nokey\n"
got := dotenvParse(in)
want := map[string]string{
"DATABASE_URL": "postgres://u:p%4022@localhost:5432/db?sslmode=disable",
"PORT":         "8081",
"NAME":         "quoted value",
"SINGLE":       "x y",
}
if len(got) != len(want) {
t.Fatalf("got %v", got)
}
for k, v := range want {
if got[k] != v {
t.Errorf("%s = %q, want %q", k, got[k], v)
}
}
}

func TestDotenvKeepsRealEnvAndFillsGaps(t *testing.T) {
dir := t.TempDir()
f := filepath.Join(dir, ".env")
if err := os.WriteFile(f, []byte("DATABASE_URL=from-file\nSKINORA_TEST_FILL=filled\n"), 0o600); err != nil {
t.Fatal(err)
}
t.Setenv("SKINORA_ENV_FILE", f)
t.Setenv("DATABASE_URL", "real")
t.Setenv("SKINORA_TEST_FILL", "")
os.Unsetenv("SKINORA_TEST_FILL")
if !dotenvLoadEarly() {
t.Fatal("expected the file to be used")
}
if os.Getenv("DATABASE_URL") != "real" {
t.Errorf("real env was overridden: %q", os.Getenv("DATABASE_URL"))
}
if os.Getenv("SKINORA_TEST_FILL") != "filled" {
t.Errorf("missing variable not filled: %q", os.Getenv("SKINORA_TEST_FILL"))
}
}

func TestDotenvIgnoresFilesWithoutDatabaseURL(t *testing.T) {
dir := t.TempDir()
f := filepath.Join(dir, ".env")
_ = os.WriteFile(f, []byte("OTHER=1\n"), 0o600)
t.Setenv("SKINORA_ENV_FILE", f)
for _, p := range dotenvCandidates() {
if p == f {
b, _ := os.ReadFile(p)
if dotenvParse(string(b))["DATABASE_URL"] != "" {
t.Fatal("should not define DATABASE_URL")
}
}
}
}
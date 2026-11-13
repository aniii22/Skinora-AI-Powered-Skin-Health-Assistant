package main

import (
"bufio"
"os"
"path/filepath"
"strings"
)

// The API loads its .env file before anything else runs, so it works no matter
// where it is started from: go run, backend.exe, another folder, an IDE or a
// test tool. Real environment variables always win over the file.
// Set SKINORA_ENV_FILE to point at a specific file.
var _ = dotenvLoadEarly()

func dotenvCandidates() []string {
var out []string
seen := map[string]bool{}
add := func(p string) {
if p != "" && !seen[p] {
seen[p] = true
out = append(out, p)
}
}
add(strings.TrimSpace(os.Getenv("SKINORA_ENV_FILE")))
var dirs []string
if exe, err := os.Executable(); err == nil {
if real, err := filepath.EvalSymlinks(exe); err == nil {
exe = real
}
dirs = append(dirs, filepath.Dir(exe))
}
if wd, err := os.Getwd(); err == nil {
dirs = append(dirs, wd)
}
for _, d := range dirs {
cur := d
for i := 0; i < 4; i++ {
add(filepath.Join(cur, ".env"))
add(filepath.Join(cur, "backend", ".env"))
parent := filepath.Dir(cur)
if parent == cur {
break
}
cur = parent
}
}
return out
}

func dotenvParse(data string) map[string]string {
out := map[string]string{}
data = strings.TrimPrefix(data, "\ufeff")
sc := bufio.NewScanner(strings.NewReader(data))
sc.Buffer(make([]byte, 0, 64*1024), 1<<20)
for sc.Scan() {
line := strings.TrimSpace(sc.Text())
if line == "" || strings.HasPrefix(line, "#") {
continue
}
line = strings.TrimPrefix(line, "export ")
i := strings.IndexByte(line, '=')
if i <= 0 {
continue
}
key := strings.TrimSpace(line[:i])
val := strings.TrimSpace(line[i+1:])
if len(val) >= 2 && ((val[0] == '"' && val[len(val)-1] == '"') || (val[0] == '\'' && val[len(val)-1] == '\'')) {
val = val[1 : len(val)-1]
}
out[key] = val
}
return out
}

// dotenvLoadEarly reads the first .env that defines DATABASE_URL and fills in
// every variable that is not already set. It reports whether a file was used.
func dotenvLoadEarly() bool {
for _, p := range dotenvCandidates() {
b, err := os.ReadFile(p)
if err != nil {
continue
}
vals := dotenvParse(string(b))
if vals["DATABASE_URL"] == "" {
continue
}
for k, v := range vals {
if os.Getenv(k) == "" {
_ = os.Setenv(k, v)
}
}
return true
}
return false
}
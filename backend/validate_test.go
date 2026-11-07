package main

import (
    "encoding/json"
    "net/http"
    "net/http/httptest"
    "strings"
    "testing"

    "github.com/gin-gonic/gin"
)

func TestValidationEmail(t *testing.T) {
    good := []string{"aniket123@gmail.com", "a.b+tag@sub.example.co.in", " user@example.com "}
    bad := []string{"", "   ", "plain", "a@b", "a@b.", "@gmail.com", "a b@gmail.com", "a@@gmail.com",
        "a..b@gmail.com", ".a@gmail.com", "a.@gmail.com", "user@gmail", "user@-.com", "<a@b.com>", "a@b.c",
        "John <a@b.com>", strings.Repeat("a", 250) + "@x.com"}
    for _, e := range good {
        if m := validateEmail(e); m != "" {
            t.Errorf("email %q should be valid, got %q", e, m)
        }
    }
    for _, e := range bad {
        if m := validateEmail(e); m == "" {
            t.Errorf("email %q should be rejected", e)
        }
    }
}

func TestValidationPassword(t *testing.T) {
    good := []string{"Abcdef1!", "Aniket@2211", "Zz9#zzzz", strings.Repeat("Aa1!", 18)}
    bad := []string{"", "Abc1!", "abcdefg1!", "ABCDEFG1!", "Abcdefgh!", "Abcdefg12", "Abcdef 1", strings.Repeat("Aa1!", 19)}
    for _, p := range good {
        if m := validatePassword(p); m != "" {
            t.Errorf("password %q should pass, got %q", p, m)
        }
    }
    for _, p := range bad {
        if m := validatePassword(p); m == "" {
            t.Errorf("password %q should fail", p)
        }
    }
    if m := validatePassword("abc"); !strings.Contains(m, "uppercase") || !strings.Contains(m, "special") {
        t.Errorf("message should list unmet rules, got %q", m)
    }
}

func TestValidationWholeNumbers(t *testing.T) {
    cases := map[string]string{
        `2500`: "", `"2500"`: "", `0500`: "", `-5`: "x", `12.5`: "x", `1e3`: "x", `"abc"`: "x",
        `""`: "x", `null`: "x", `"12a"`: "x", `true`: "x", `[1]`: "x",
    }
    for in, want := range cases {
        _, msg := parseWholeNumber(json.RawMessage(in))
        if (want == "") != (msg == "") {
            t.Errorf("parseWholeNumber(%s) msg=%q", in, msg)
        }
    }
}

func TestValidationWaterSettings(t *testing.T) {
    type tc struct {
        goal, glass string
        hasG, hasL  bool
        wantGoal    string
        wantGlass   string
    }
    rng1 := "Enter a value between 500 and 5000 ml."
    rng2 := "Enter a value between 50 and 1000 ml."
    cases := []tc{
        {"2500", "250", true, true, "", ""},
        {"500", "50", true, true, "", ""},
        {"5000", "1000", true, true, "", ""},
        {"499", "250", true, true, rng1, ""},
        {"5001", "250", true, true, rng1, ""},
        {"2500", "49", true, true, "", rng2},
        {"2500", "1001", true, true, "", rng2},
        {"-500", "250", true, true, "Enter a whole number.", ""},
        {"2500.5", "250", true, true, "Enter a whole number.", ""},
        {`"abc"`, "250", true, true, "Enter a whole number.", ""},
        {"99999999999999999999", "250", true, true, rng1, ""},
        {"2500", "99999999999999999999", true, true, "", rng2},
        {"500", "600", true, true, "", "One glass amount cannot exceed your daily goal."},
        {"null", "250", true, true, "This field is required.", ""},
        {`""`, "250", true, true, "This field is required.", ""},
        {"", "250", false, true, "", ""},
        {"2500", "", true, false, "", ""},
    }
    for i, c := range cases {
        f := validateWaterSettings(json.RawMessage(c.goal), json.RawMessage(c.glass), c.hasG, c.hasL)
        if f["goal"] != c.wantGoal || f["glass"] != c.wantGlass {
            t.Errorf("case %d (%s/%s): got %v", i, c.goal, c.glass, f)
        }
    }
}

func runMW(mw gin.HandlerFunc, body string) *httptest.ResponseRecorder {
    gin.SetMode(gin.TestMode)
    r := gin.New()
    r.POST("/x", mw, func(c *gin.Context) { c.JSON(http.StatusOK, gin.H{"ok": true}) })
    req := httptest.NewRequest(http.MethodPost, "/x", strings.NewReader(body))
    req.Header.Set("Content-Type", "application/json")
    w := httptest.NewRecorder()
    r.ServeHTTP(w, req)
    return w
}

func TestValidationRegisterMiddleware(t *testing.T) {
    good := `{"name":"Aniket","email":"aniket123@gmail.com","password":"Aniket@2211"}`
    if w := runMW(validateRegister(), good); w.Code != 200 {
        t.Fatalf("valid register rejected: %d %s", w.Code, w.Body.String())
    }
    bad := []string{
        ``, `not json`, `[]`, `{}`,
        `{"email":"","password":""}`,
        `{"email":"bad","password":"Aniket@2211"}`,
        `{"email":"a@b.com","password":"weak"}`,
        `{"email":"a@b.com","password":"alllowercase1!"}`,
        `{"email":"a@b.com","password":"Aniket@2211","confirmPassword":"Different1!"}`,
    }
    for _, b := range bad {
        w := runMW(validateRegister(), b)
        if w.Code != 400 {
            t.Errorf("register %q should be 400, got %d", b, w.Code)
        }
    }
    okConfirm := `{"email":"a@b.com","password":"Aniket@2211","confirmPassword":"Aniket@2211"}`
    if w := runMW(validateRegister(), okConfirm); w.Code != 200 {
        t.Errorf("matching confirm rejected: %d", w.Code)
    }
    w := runMW(validateRegister(), `{"email":"bad","password":"x"}`)
    var out map[string]any
    if err := json.Unmarshal(w.Body.Bytes(), &out); err != nil || out["error"] == nil || out["fields"] == nil {
        t.Errorf("error body shape wrong: %s", w.Body.String())
    }
}

func TestValidationLoginMiddleware(t *testing.T) {
    if w := runMW(validateLogin(), `{"email":"a@b.com","password":"anything"}`); w.Code != 200 {
        t.Errorf("valid login rejected: %d", w.Code)
    }
    for _, b := range []string{``, `{}`, `{"email":"","password":"x"}`, `{"email":"nope","password":"x"}`, `{"email":"a@b.com","password":""}`} {
        if w := runMW(validateLogin(), b); w.Code != 400 {
            t.Errorf("login %q should be 400, got %d", b, w.Code)
        }
    }
}

func TestValidationSettingsMiddleware(t *testing.T) {
    saveGoal, saveGlass := settingsGoalKeys, settingsGlassKeys
    defer func() { settingsGoalKeys, settingsGlassKeys = saveGoal, saveGlass }()
    goalKey, glassKey := "water_goal_ml", "glass_ml"
    if len(settingsGoalKeys) > 0 {
        goalKey = settingsGoalKeys[0]
    }
    if len(settingsGlassKeys) > 0 {
        glassKey = settingsGlassKeys[0]
    }
    mk := func(g, gl string) string {
        return `{"` + goalKey + `":` + g + `,"` + glassKey + `":` + gl + `}`
    }
    if w := runMW(validateSettings(), mk("2500", "250")); w.Code != 200 {
        t.Errorf("valid settings rejected: %d %s", w.Code, w.Body.String())
    }
    if w := runMW(validateSettings(), `{"something_else":1}`); w.Code != 200 {
        t.Errorf("non-water update should pass through: %d", w.Code)
    }
    for _, b := range []string{
        mk("499", "250"), mk("5001", "250"), mk("2500", "49"), mk("2500", "1001"),
        mk("-1", "250"), mk("2500.5", "250"), mk(`"abc"`, "250"), mk("999999999999999999999", "250"),
        mk("500", "600"), mk("null", "250"), ``, `[]`,
    } {
        if w := runMW(validateSettings(), b); w.Code != 400 {
            t.Errorf("settings %q should be 400, got %d", b, w.Code)
        }
    }
}
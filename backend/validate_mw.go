package main

import (
    "bytes"
    "encoding/json"
    "io"
    "net/http"
    "strings"

    "github.com/gin-gonic/gin"
)

// Request validation middleware. It never trusts the app: every register,
// login and water-settings request is checked here before the handler runs.
// Errors are 400 with {"error","message","fields"} and never reveal whether
// an account exists.

const maxValidatedBody = 1 << 20 // 1 MB

// JSON keys of the water settings request, detected from the existing structs.
// Empty means: fall back to matching any key containing "goal" / "glass".
var (
    settingsGoalKeys  = []string{"goal_ml", "water_goal_ml"}
    settingsGlassKeys = []string{"glass_ml"}
)

func rejectValidation(c *gin.Context, fields map[string]string, order ...string) {
    msg := "Invalid request."
    for _, k := range order {
        if m, ok := fields[k]; ok && m != "" {
            msg = m
            break
        }
    }
    c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{
        "error":   msg,
        "message": msg,
        "fields":  fields,
    })
}

func readJSONObject(c *gin.Context) (map[string]json.RawMessage, bool) {
    c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, maxValidatedBody)
    raw, err := io.ReadAll(c.Request.Body)
    if err != nil {
        rejectValidation(c, map[string]string{}, "")
        return nil, false
    }
    c.Request.Body = io.NopCloser(bytes.NewReader(raw))
    var m map[string]json.RawMessage
    if err := json.Unmarshal(raw, &m); err != nil || m == nil {
        rejectValidation(c, map[string]string{"body": "Request body must be a JSON object."}, "body")
        return nil, false
    }
    return m, true
}

func lookupKey(m map[string]json.RawMessage, names ...string) (json.RawMessage, bool) {
    for k, v := range m {
        lk := strings.ToLower(k)
        for _, n := range names {
            if lk == n {
                return v, true
            }
        }
    }
    return nil, false
}

func stringField(m map[string]json.RawMessage, names ...string) string {
    raw, ok := lookupKey(m, names...)
    if !ok {
        return ""
    }
    var s string
    if json.Unmarshal(raw, &s) != nil {
        return ""
    }
    return s
}

func findSettingKey(m map[string]json.RawMessage, exact []string, contains, exclude string) (json.RawMessage, bool) {
    if len(exact) > 0 {
        return lookupKey(m, exact...)
    }
    for k, v := range m {
        lk := strings.ToLower(k)
        if strings.Contains(lk, contains) && (exclude == "" || !strings.Contains(lk, exclude)) {
            return v, true
        }
    }
    return nil, false
}

func validateRegister() gin.HandlerFunc {
    return func(c *gin.Context) {
        m, ok := readJSONObject(c)
        if !ok {
            return
        }
        fields := map[string]string{}
        if msg := validateEmail(stringField(m, "email")); msg != "" {
            fields["email"] = msg
        }
        pw := stringField(m, "password")
        if msg := validatePassword(pw); msg != "" {
            fields["password"] = msg
        }
        if raw, has := lookupKey(m, "confirmpassword", "confirm_password", "passwordconfirmation", "password_confirmation"); has {
            var confirm string
            if json.Unmarshal(raw, &confirm) != nil || confirm != pw {
                fields["confirmPassword"] = "Passwords do not match."
            }
        }
        if len(fields) > 0 {
            rejectValidation(c, fields, "email", "password", "confirmPassword")
        }
    }
}

func validateLogin() gin.HandlerFunc {
    return func(c *gin.Context) {
        m, ok := readJSONObject(c)
        if !ok {
            return
        }
        fields := map[string]string{}
        if msg := validateEmail(stringField(m, "email")); msg != "" {
            fields["email"] = msg
        }
        if msg := validateLoginPassword(stringField(m, "password")); msg != "" {
            fields["password"] = msg
        }
        if len(fields) > 0 {
            rejectValidation(c, fields, "email", "password")
        }
    }
}

func validateSettings() gin.HandlerFunc {
    return func(c *gin.Context) {
        m, ok := readJSONObject(c)
        if !ok {
            return
        }
        goal, hasGoal := findSettingKey(m, settingsGoalKeys, "goal", "sleep")
        glass, hasGlass := findSettingKey(m, settingsGlassKeys, "glass", "")
        if !hasGoal && !hasGlass {
            return // not a water update: leave it to the handler
        }
        if fields := validateWaterSettings(goal, glass, hasGoal, hasGlass); len(fields) > 0 {
            rejectValidation(c, fields, "goal", "glass")
        }
    }
}
package main

import (
    "encoding/json"
    "math"
    "net/mail"
    "regexp"
    "strconv"
    "strings"
    "unicode"
    "unicode/utf8"
)

// Validation rules shared by the register, login and settings endpoints.
// Kept free of gin so it can be unit tested on its own.

const (
    waterGoalMin     = 500
    waterGoalMax     = 5000
    waterGlassMin    = 50
    waterGlassMax    = 1000
    passwordMinChars = 8
    passwordMaxBytes = 72 // bcrypt only uses the first 72 bytes
    loginPasswordCap = 1024
)

var (
    emailPattern  = regexp.MustCompile(`^[A-Za-z0-9._%+\-]+@[A-Za-z0-9\-]+(\.[A-Za-z0-9\-]+)*\.[A-Za-z]{2,}$`)
    digitsPattern = regexp.MustCompile(`^[0-9]+$`)
)

// validateEmail returns "" when the address is acceptable.
func validateEmail(raw string) string {
    email := strings.TrimSpace(raw)
    if email == "" {
        return "Email is required."
    }
    if len(email) > 254 ||
        strings.ContainsAny(email, " \t\r\n") ||
        !emailPattern.MatchString(email) ||
        strings.Contains(email, "..") ||
        strings.HasPrefix(email, ".") ||
        strings.Contains(email, ".@") {
        return "Enter a valid email address."
    }
    domain := email[strings.LastIndex(email, "@")+1:]
    for _, label := range strings.Split(domain, ".") {
        if label == "" || strings.HasPrefix(label, "-") || strings.HasSuffix(label, "-") {
            return "Enter a valid email address."
        }
    }
    if addr, err := mail.ParseAddress(email); err != nil || addr.Address != email {
        return "Enter a valid email address."
    }
    return ""
}

func isASCIISpecial(r rune) bool {
    return (r >= 0x21 && r <= 0x2F) || (r >= 0x3A && r <= 0x40) ||
        (r >= 0x5B && r <= 0x60) || (r >= 0x7B && r <= 0x7E)
}

// passwordProblems lists the unmet password rules.
func passwordProblems(pw string) []string {
    var upper, lower, digit, special bool
    for _, r := range pw {
        switch {
        case unicode.IsUpper(r):
            upper = true
        case unicode.IsLower(r):
            lower = true
        case r >= '0' && r <= '9':
            digit = true
        case isASCIISpecial(r):
            special = true
        }
    }
    var p []string
    if utf8.RuneCountInString(pw) < passwordMinChars {
        p = append(p, "at least 8 characters")
    }
    if !upper {
        p = append(p, "an uppercase letter")
    }
    if !lower {
        p = append(p, "a lowercase letter")
    }
    if !digit {
        p = append(p, "a number")
    }
    if !special {
        p = append(p, "a special character")
    }
    return p
}

func joinNatural(items []string) string {
    switch len(items) {
    case 0:
        return ""
    case 1:
        return items[0]
    }
    return strings.Join(items[:len(items)-1], ", ") + " and " + items[len(items)-1]
}

// validatePassword is the registration rule set.
func validatePassword(pw string) string {
    if pw == "" {
        return "Password is required."
    }
    if len(pw) > passwordMaxBytes {
        return "Password is too long (maximum 72 characters)."
    }
    if p := passwordProblems(pw); len(p) > 0 {
        return "Password must contain " + joinNatural(p) + "."
    }
    return ""
}

// validateLoginPassword only checks presence: existing accounts keep working.
func validateLoginPassword(pw string) string {
    if pw == "" {
        return "Password is required."
    }
    if len(pw) > loginPasswordCap {
        return "Password is too long."
    }
    return ""
}

// parseWholeNumber accepts a JSON number or a digits-only string.
// Negatives, decimals, exponents, letters and symbols are rejected.
func parseWholeNumber(raw json.RawMessage) (int64, string) {
    s := strings.TrimSpace(string(raw))
    if s == "" || s == "null" {
        return 0, "This field is required."
    }
    if strings.HasPrefix(s, `"`) {
        var str string
        if json.Unmarshal(raw, &str) != nil {
            return 0, "Enter a whole number."
        }
        s = strings.TrimSpace(str)
        if s == "" {
            return 0, "This field is required."
        }
    }
    if !digitsPattern.MatchString(s) {
        return 0, "Enter a whole number."
    }
    if len(s) > 9 { // absurdly large: let the range check reject it
        return math.MaxInt32, ""
    }
    n, err := strconv.ParseInt(s, 10, 64)
    if err != nil {
        return 0, "Enter a whole number."
    }
    return n, ""
}

func validateGoalValue(v int64) string {
    if v < waterGoalMin || v > waterGoalMax {
        return "Enter a value between 500 and 5000 ml."
    }
    return ""
}

func validateGlassValue(v int64) string {
    if v < waterGlassMin || v > waterGlassMax {
        return "Enter a value between 50 and 1000 ml."
    }
    return ""
}

// validateWaterSettings checks whichever of goal / glass were sent.
// Returned map keys: "goal", "glass".
func validateWaterSettings(goal, glass json.RawMessage, hasGoal, hasGlass bool) map[string]string {
    fields := map[string]string{}
    var g, gl int64
    goalOK, glassOK := false, false
    if hasGoal {
        v, msg := parseWholeNumber(goal)
        if msg == "" {
            msg = validateGoalValue(v)
        }
        if msg != "" {
            fields["goal"] = msg
        } else {
            g, goalOK = v, true
        }
    }
    if hasGlass {
        v, msg := parseWholeNumber(glass)
        if msg == "" {
            msg = validateGlassValue(v)
        }
        if msg != "" {
            fields["glass"] = msg
        } else {
            gl, glassOK = v, true
        }
    }
    if goalOK && glassOK && gl > g {
        fields["glass"] = "One glass amount cannot exceed your daily goal."
    }
    return fields
}
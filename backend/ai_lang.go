package main

import "strings"

// aiBaseLang turns "hi-IN" or "HI" into "hi".
func aiBaseLang(code string) string {
c := strings.ToLower(strings.TrimSpace(code))
if i := strings.IndexAny(c, "-_"); i > 0 {
c = c[:i]
}
return c
}

// aiLanguage returns the language name for the app language code.
func aiLanguage(code string) string {
c := aiBaseLang(code)
if c == "" || c == "en" {
return "English"
}
names := map[string]string{
"hi": "Hindi (Devanagari script)", "mr": "Marathi (Devanagari script)",
"gu": "Gujarati", "bn": "Bengali", "ta": "Tamil", "te": "Telugu",
"kn": "Kannada", "ml": "Malayalam", "pa": "Punjabi (Gurmukhi script)",
"ur": "Urdu", "or": "Odia", "as": "Assamese", "ne": "Nepali",
"es": "Spanish", "fr": "French", "de": "German", "pt": "Portuguese",
"ar": "Arabic", "id": "Indonesian", "ru": "Russian", "ja": "Japanese",
"zh": "Chinese",
}
if n, ok := names[c]; ok {
return n
}
return "the language with ISO code " + c
}

// aiLanguageTop goes first in the system prompt.
func aiLanguageTop(name string) string {
if name == "English" {
return ""
}
return "LANGUAGE RULE (highest priority): the user reads " + name + ". Write EVERY text value of your JSON answer in " + name + ", never in English. This includes observations, summary, concerns, possible_causes (also translate the word Cause), recommendations, routines, lifestyle, products (type, why, usage, key_ingredients), avoid, see_doctor_reason and disclaimer. Keep the JSON keys and the confidence value (low, medium or high) in English. The instructions below are in English only for you.\n\n"
}

// aiLanguageRule repeats the rule at the end of the system prompt.
func aiLanguageRule(name string) string {
if name == "English" {
return ""
}
return "\n\nREMINDER: the whole answer must be in " + name + ". Do not write English sentences."
}

// aiLanguageUser repeats the rule in the user message.
func aiLanguageUser(name string) string {
if name == "English" {
return ""
}
return " Answer fully in " + name + "."
}
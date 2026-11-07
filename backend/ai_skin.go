package main

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"mime/multipart"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
)

const (
	aiMaxFrames       = 3
	aiMaxFrameBytes   = 2 << 20  // 2 MB per photo
	aiMaxVideoBytes   = 25 << 20 // 25 MB per video
	aiMaxTotalBytes   = 2800000  // Groq accepts about 4 MB of base64 per request
	aiFreeScansTotal  = 3
	aiPremiumScansMon = 30
	groqURL           = "https://api.groq.com/openai/v1/chat/completions"
)

var aiImageTypes = map[string]bool{"image/jpeg": true, "image/png": true, "image/webp": true}

type aiProduct struct {
	Type           string   `json:"type"`
	KeyIngredients []string `json:"key_ingredients"`
	Why            string   `json:"why"`
	Usage          string   `json:"usage"`
}

type aiAnalysis struct {
	Observations    []string    `json:"observations"`
	Confidence      string      `json:"confidence"`
	Summary         string      `json:"summary"`
	Concerns        []string    `json:"concerns"`
	PossibleCauses  []string    `json:"possible_causes"`
	Recommendations []string    `json:"recommendations"`
	Products        []aiProduct `json:"products"`
	Avoid           []string    `json:"avoid"`
	SeeDoctor       bool        `json:"see_doctor"`
	SeeDoctorReason string      `json:"see_doctor_reason"`
	Disclaimer      string      `json:"disclaimer"`
	RoutineMorning  []string    `json:"routine_morning"`
	RoutineEvening  []string    `json:"routine_evening"`
	Lifestyle       []string    `json:"lifestyle"`
}

const aiSystemPrompt = `You are a skincare assistant in a wellness app. Look at the photos of one person's skin and give general, non-diagnostic guidance.
Rules:
- Describe only what is visible. Never diagnose; say "looks like" or "may be".
- If the images are not clear skin photos, say so in "summary" and leave all lists empty.
- Suggest product TYPES with key ingredients only. No brand names, prices or cure claims.
- Set "see_doctor" to true for anything possibly serious (bleeding or changing moles, spreading rash, painful or infected lesions, severe cystic acne) or if unsure.
- Keep advice simple and safe for sensitive skin. Short sentences, one idea per item.
- "observations": 3 to 5 specific visible things with their place on the face, e.g. "small red bumps on the chin". Nothing generic.
- Every item must link to an observation, the given skin type, the given concerns or the user note. Fit THIS skin; never use a default list.
- If several images are given, they show the same person. Use all of them.
- If the user note lists product types from an earlier scan, suggest different relevant ones and explain in "why".
- "confidence" is low, medium or high, from photo clarity and lighting. If low, say in "summary" how to improve the photo.
- "summary": 2 short sentences (what you see, then the main focus). "concerns": up to 4 items, 2 to 6 words. "possible_causes": up to 4, like "Cause: reason". "recommendations": 4 to 6 steps, each starting with a verb. "routine_morning" and "routine_evening": 3 to 4 steps each. "lifestyle": 3 to 4 tips. "products": 2 to 4, each with type, key_ingredients, why, usage. "avoid": 3 to 4 items.
Respond with ONLY a JSON object, no markdown, in exactly this shape:
{"observations":[""],"confidence":"medium","summary":"","concerns":[""],"possible_causes":[""],"recommendations":[""],"routine_morning":[""],"routine_evening":[""],"lifestyle":[""],"products":[{"type":"","key_ingredients":[""],"why":"","usage":""}],"avoid":[""],"see_doctor":false,"see_doctor_reason":"","disclaimer":"General skincare guidance, not a medical diagnosis."}`

func (a *App) ensureAIScans(ctx context.Context) error {
	_, err := a.db.Exec(ctx, `CREATE TABLE IF NOT EXISTS ai_scans (
id BIGSERIAL PRIMARY KEY,
user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
created_at TIMESTAMPTZ NOT NULL DEFAULT now())`)
	return err
}

func aiTrim(s string, n int) string {
	r := []rune(strings.TrimSpace(s))
	if len(r) > n {
		return string(r[:n])
	}
	return string(r)
}

// videoFrames pulls up to n evenly spaced JPEG frames out of an uploaded video.
// It needs ffmpeg (and ideally ffprobe) on the server PATH.
func videoFrames(ctx context.Context, fh *multipart.FileHeader, n int) ([][]byte, error) {
	if fh.Size > aiMaxVideoBytes {
		return nil, fmt.Errorf("the video must be 25 MB or smaller")
	}
	if _, err := exec.LookPath("ffmpeg"); err != nil {
		return nil, fmt.Errorf("video scan is not set up on this server (ffmpeg is missing)")
	}
	ext := strings.ToLower(filepath.Ext(fh.Filename))
	switch ext {
	case ".mp4", ".mov", ".webm", ".m4v", ".3gp":
	default:
		ext = ".mp4"
	}
	dir, err := os.MkdirTemp("", "skinora-video-")
	if err != nil {
		return nil, err
	}
	defer os.RemoveAll(dir)

	in := filepath.Join(dir, "in"+ext)
	src, err := fh.Open()
	if err != nil {
		return nil, fmt.Errorf("could not read the video")
	}
	dst, err := os.Create(in)
	if err != nil {
		src.Close()
		return nil, err
	}
	_, err = io.Copy(dst, io.LimitReader(src, aiMaxVideoBytes+1))
	src.Close()
	dst.Close()
	if err != nil {
		return nil, fmt.Errorf("could not read the video")
	}

	ctx, cancel := context.WithTimeout(ctx, 40*time.Second)
	defer cancel()

	dur := 0.0
	if _, err := exec.LookPath("ffprobe"); err == nil {
		outb, err := exec.CommandContext(ctx, "ffprobe", "-v", "error",
			"-show_entries", "format=duration",
			"-of", "default=noprint_wrappers=1:nokey=1", in).Output()
		if err == nil {
			dur, _ = strconv.ParseFloat(strings.TrimSpace(string(outb)), 64)
		}
	}

	var times []float64
	if dur > 0 {
		for i := 0; i < n; i++ {
			times = append(times, dur*(float64(i)+1)/(float64(n)+1))
		}
	} else {
		times = []float64{0.3, 1, 2}
		if len(times) > n {
			times = times[:n]
		}
	}

	var frames [][]byte
	for i, t := range times {
		out := filepath.Join(dir, fmt.Sprintf("f%d.jpg", i))
		cmd := exec.CommandContext(ctx, "ffmpeg", "-y", "-loglevel", "error",
			"-ss", strconv.FormatFloat(t, 'f', 2, 64), "-i", in,
			"-frames:v", "1", "-vf", "scale='min(1024,iw)':-2", "-q:v", "4", out)
		if err := cmd.Run(); err != nil {
			continue
		}
		b, err := os.ReadFile(out)
		if err == nil && len(b) > 0 {
			frames = append(frames, b)
		}
	}
	if len(frames) == 0 {
		return nil, fmt.Errorf("could not read frames from this video. Try a short MP4 recorded on your phone")
	}
	return frames, nil
}

// POST /api/ai/skin-analysis
// multipart: frames x1..3 (photos) OR video x1, plus skin_type and note (optional)
func (a *App) skinAnalysis(c *gin.Context) {
	if len(groqKeys()) == 0 {
		fail(c, http.StatusServiceUnavailable, "AI scan is not set up on this server.")
		return
	}
	u := curUser(c)
	ctx := c.Request.Context()
	if err := a.ensureAIScans(ctx); err != nil {
		serverError(c, err)
		return
	}

	limit := aiFreeScansTotal
	if u.premium() {
		limit = aiPremiumScansMon
	}
	var used int
	if err := a.db.QueryRow(ctx,
		`SELECT COUNT(*)::int FROM ai_scans WHERE user_id = $1 AND ($2::bool OR created_at >= date_trunc('month', now()))`,
		u.ID, !u.premium()).Scan(&used); err != nil {
		serverError(c, err)
		return
	}
	if used >= limit {
		if u.premium() {
			fail(c, http.StatusTooManyRequests, "You have used all AI scans for this month.")
		} else {
			premiumRequired(c, "you have used your 3 free AI skin scans. Upgrade for 30 scans every month.")
		}
		return
	}

	form, err := c.MultipartForm()
	if err != nil {
		fail(c, http.StatusBadRequest, "invalid or too large upload")
		return
	}
	files := form.File["frames"]
	videos := form.File["video"]
	if len(files) == 0 && len(videos) == 0 {
		fail(c, http.StatusBadRequest, "add at least one photo or a short video")
		return
	}
	if len(videos) > 1 || (len(videos) == 1 && len(files) > 0) {
		fail(c, http.StatusBadRequest, "send either photos or one video, not both")
		return
	}
	if len(files) > aiMaxFrames {
		fail(c, http.StatusBadRequest, fmt.Sprintf("you can send up to %d photos", aiMaxFrames))
		return
	}

	// Collect the images: either the photos, or frames cut from the video.
	var images [][]byte
	fromVideo := len(videos) == 1
	if fromVideo {
		imgs, err := videoFrames(ctx, videos[0], aiMaxFrames)
		if err != nil {
			fail(c, http.StatusBadRequest, err.Error())
			return
		}
		images = imgs
	} else {
		for _, fh := range files {
			if fh.Size > aiMaxFrameBytes {
				fail(c, http.StatusBadRequest, "each photo must be 2 MB or smaller")
				return
			}
			f, err := fh.Open()
			if err != nil {
				fail(c, http.StatusBadRequest, "could not read a photo")
				return
			}
			data, err := io.ReadAll(io.LimitReader(f, aiMaxFrameBytes+1))
			f.Close()
			if err != nil || len(data) > aiMaxFrameBytes {
				fail(c, http.StatusBadRequest, "could not read a photo")
				return
			}
			images = append(images, data)
		}
	}

	langName := aiLanguage(c.PostForm("lang"))
	log.Printf("ai scan: app language code=%q -> %s", c.PostForm("lang"), langName)
	text := "Analyze this skin."
	if fromVideo {
		text += fmt.Sprintf(" These %d images are frames from one short video of the same person. Look at them together.", len(images))
	} else if len(images) > 1 {
		text += " These photos show the same person. Look at them together."
	}
	if p, err := a.loadProfile(ctx, u.ID); err == nil {
		if p.SkinType != "" && p.SkinType != "not_sure" {
			text += " Self-reported skin type: " + p.SkinType + "."
		}
		if len(p.Concerns) > 0 {
			text += " Self-reported concerns: " + strings.Join(p.Concerns, ", ") + "."
		}
		if p.Sensitive {
			text += " The user has sensitive skin."
		}
	}
	if st := aiTrim(c.PostForm("skin_type"), 40); st != "" {
		text += " Skin type chosen for this scan: " + st + "."
	}
	if note := aiTrim(c.PostForm("note"), 500); note != "" {
		text += " User note: " + note
	}

	text += aiLanguageUser(langName)
	content := []map[string]any{{"type": "text", "text": text}}
	total := 0
	for _, data := range images {
		total += len(data)
		if total > aiMaxTotalBytes {
			fail(c, http.StatusBadRequest, "photos are too large together. Use smaller photos.")
			return
		}
		mt := http.DetectContentType(data)
		if !aiImageTypes[mt] {
			fail(c, http.StatusBadRequest, "only JPEG, PNG or WebP photos are allowed")
			return
		}
		content = append(content, map[string]any{
			"type":      "image_url",
			"image_url": map[string]any{"url": "data:" + mt + ";base64," + base64.StdEncoding.EncodeToString(data)},
		})
	}

	model := os.Getenv("GROQ_MODEL")
	if model == "" {
		model = "meta-llama/llama-4-scout-17b-16e-instruct"
	}
	payload, _ := json.Marshal(map[string]any{
		"model":            model,
		"temperature":      0.5,
		"reasoning_effort": "none",
		"max_tokens":       2600,
		"messages": []map[string]any{
			{"role": "system", "content": aiLanguageTop(langName) + aiSystemPrompt + aiLanguageRule(langName)},
			{"role": "user", "content": content},
		},
	})
	statusCode, body, err := groqPost(ctx, payload)
	if err != nil {
		log.Printf("ai request failed: %v", err)
		fail(c, http.StatusBadGateway, "The AI service could not be reached. Please try again.")
		return
	}
	if statusCode == http.StatusTooManyRequests {
		fail(c, http.StatusTooManyRequests, "The AI service is busy right now. Please try again in a minute.")
		return
	}
	if statusCode != http.StatusOK {
		log.Printf("groq error %d: %s", statusCode, string(body))
		fail(c, http.StatusBadGateway, "The AI service returned an error. Please try again.")
		return
	}

	var out struct {
		Choices []struct {
			Message struct {
				Content string `json:"content"`
			} `json:"message"`
		} `json:"choices"`
	}
	if err := json.Unmarshal(body, &out); err != nil || len(out.Choices) == 0 {
		fail(c, http.StatusBadGateway, "Unexpected AI response.")
		return
	}
	raw := out.Choices[0].Message.Content
	s, e := strings.Index(raw, "{"), strings.LastIndex(raw, "}")
	if s < 0 || e <= s {
		fail(c, http.StatusBadGateway, "The AI answer could not be read. Please try again.")
		return
	}
	var an aiAnalysis
	if err := json.Unmarshal([]byte(raw[s:e+1]), &an); err != nil {
		fail(c, http.StatusBadGateway, "The AI answer could not be read. Please try again.")
		return
	}
	if an.Disclaimer == "" {
		an.Disclaimer = "General skincare guidance, not a medical diagnosis."
	}

	if _, err := a.db.Exec(ctx, `INSERT INTO ai_scans (user_id) VALUES ($1)`, u.ID); err != nil {
		log.Printf("could not record ai scan: %v", err)
	}
	respond(c, http.StatusOK, gin.H{
		"analysis":   an,
		"scans_left": limit - used - 1,
	})
}

// Register AI routes.
// IMPORTANT: This function must be outside skinAnalysis().
func registerAIRoutes(p *gin.RouterGroup, a *App) {
	p.POST("/ai/skin-analysis", a.skinAnalysis)
}

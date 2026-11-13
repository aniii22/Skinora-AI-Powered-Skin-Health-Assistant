package main

import (
	"crypto/rand"
	"encoding/hex"
	"errors"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5"
)

func (a *App) uploadProfilePhoto(c *gin.Context) {
	upKey := "photoup|" + curUser(c).Email
	if a.lim.blocked(upKey, 20, time.Hour) {
		fail(c, http.StatusTooManyRequests, "Too many photo uploads. Try again later.")
		return
	}
	a.lim.add(upKey, time.Hour)
	file, header, err := c.Request.FormFile("photo")
	if err != nil {
		fail(c, http.StatusBadRequest, "Select a photo to upload")
		return
	}
	defer file.Close()

	if header.Size > maxPhotoBytes {
		fail(c, http.StatusRequestEntityTooLarge, "Photo must be 5 MB or smaller")
		return
	}

	data, err := io.ReadAll(io.LimitReader(file, maxPhotoBytes+1))
	if err != nil || len(data) == 0 {
		fail(c, http.StatusBadRequest, "Could not read photo")
		return
	}
	if len(data) > maxPhotoBytes {
		fail(c, http.StatusRequestEntityTooLarge, "Photo must be 5 MB or smaller")
		return
	}

	contentType := http.DetectContentType(data)
	ext := ""
	switch contentType {
	case "image/jpeg":
		ext = ".jpg"
	case "image/png":
		ext = ".png"
	case "image/webp":
		ext = ".webp"
	case "image/gif":
		ext = ".gif"
	default:
		fail(c, http.StatusBadRequest, "Only JPEG, PNG, WebP and GIF images are supported")
		return
	}

	// Generate a random filename; never trust the supplied filename.
	random := make([]byte, 16)
	if _, err := rand.Read(random); err != nil {
		fail(c, http.StatusInternalServerError, "Could not create photo filename")
		return
	}

	filename := "profile_" + hex.EncodeToString(random) + ext
	relativePath := filepath.Join(a.cfg.UploadDir, filename)

	if err := os.MkdirAll(a.cfg.UploadDir, 0750); err != nil {
		fail(c, http.StatusInternalServerError, "Photo storage unavailable")
		return
	}

	if err := os.WriteFile(relativePath, data, 0600); err != nil {
		fail(c, http.StatusInternalServerError, "Could not save photo")
		return
	}

	uid := curUser(c).ID
	var oldPath string

	err = a.db.QueryRow(c.Request.Context(),
		`SELECT COALESCE(photo_file, '') FROM user_profiles WHERE user_id = $1`,
		uid,
	).Scan(&oldPath)

	if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		_ = os.Remove(relativePath)
		fail(c, http.StatusInternalServerError, "Could not read existing profile photo")
		return
	}

	_, err = a.db.Exec(c.Request.Context(), `
		INSERT INTO user_profiles
			(user_id, display_name, skin_type, concerns, sensitive, photo_file)
		VALUES ($1, '', 'normal', '{}', false, $2)
		ON CONFLICT (user_id)
		DO UPDATE SET photo_file = EXCLUDED.photo_file
	`, uid, filename)

	if err != nil {
		_ = os.Remove(relativePath)
		fail(c, http.StatusInternalServerError, "Could not update profile photo")
		return
	}

	if oldPath != "" && oldPath != filename {
		safeOld := filepath.Base(oldPath)
		if strings.HasPrefix(safeOld, "profile_") {
			_ = os.Remove(filepath.Join(a.cfg.UploadDir, safeOld))
		}
	}

	c.JSON(http.StatusOK, gin.H{"message": "Profile photo uploaded"})
}

func (a *App) getProfilePhoto(c *gin.Context) {
	var storedPath string

	err := a.db.QueryRow(c.Request.Context(),
		`SELECT COALESCE(photo_file, '') FROM user_profiles WHERE user_id = $1`,
		curUser(c).ID,
	).Scan(&storedPath)

	if errors.Is(err, pgx.ErrNoRows) || storedPath == "" {
		c.Status(http.StatusNoContent)
		return
	}
	if err != nil {
		fail(c, http.StatusInternalServerError, "Could not load profile photo")
		return
	}

	name := filepath.Base(storedPath)
	if !strings.HasPrefix(name, "profile_") {
		fail(c, http.StatusNotFound, "Profile photo not found")
		return
	}

	data, err := os.ReadFile(filepath.Join(a.cfg.UploadDir, name))
	if err != nil {
		fail(c, http.StatusNotFound, "Profile photo not found")
		return
	}

	c.Header("Cache-Control", "private, no-store")
	c.Data(http.StatusOK, http.DetectContentType(data), data)
}

func (a *App) deleteProfilePhoto(c *gin.Context) {
	uid := curUser(c).ID
	var storedPath string

	err := a.db.QueryRow(c.Request.Context(),
		`SELECT COALESCE(photo_file, '') FROM user_profiles WHERE user_id = $1`,
		uid,
	).Scan(&storedPath)

	if errors.Is(err, pgx.ErrNoRows) {
		c.Status(http.StatusNoContent)
		return
	}
	if err != nil {
		fail(c, http.StatusInternalServerError, "Could not find profile photo")
		return
	}

	_, err = a.db.Exec(c.Request.Context(),
		`UPDATE user_profiles SET photo_file = NULL WHERE user_id = $1`, uid,
	)
	if err != nil {
		fail(c, http.StatusInternalServerError, "Could not delete profile photo")
		return
	}

	name := filepath.Base(storedPath)
	if strings.HasPrefix(name, "profile_") {
		_ = os.Remove(filepath.Join(a.cfg.UploadDir, name))
	}

	c.Status(http.StatusNoContent)
}

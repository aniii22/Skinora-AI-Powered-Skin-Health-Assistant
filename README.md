# Skinora update

1. Backup: `git switch -c feature/full-app` and copy your old `backend/` somewhere safe.
2. Database: `psql -U postgres -c "CREATE DATABASE skinora;"`
3. Backend: put `backend/*.go` in your Go folder (all files are `package main`; move other old .go files out).
   `copy .env.example .env` and set DATABASE_URL, then:
   `go get github.com/gin-gonic/gin github.com/gin-contrib/cors github.com/jackc/pgx/v5`
   `go mod tidy` then `go run .`
   Check: `curl.exe http://localhost:8080/api/health`
4. Flutter: replace `lib/` contents with this `lib/` (old api_service.dart and skin_profile_page.dart become unused, you may delete them).
   `flutter pub add http image_picker google_fonts`
   `flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080`
5. Check: `flutter analyze`, `go vet ./...`

Limits: no login/auth (localhost only), notifications not implemented, not compiled by the author.

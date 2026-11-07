# Skinora - AI Powered Skin Health Assistant

Skinora is a skin wellness app that helps users build healthy habits. It tracks a daily skincare routine, water intake, sleep and a skin journal, and it includes an AI skin scan and a Premium subscription.

Built with **Flutter** (Android and web), a **Go (Gin)** backend and **PostgreSQL**.

## Features

- **Personal glow plan**: daily routine based on skin type and concerns, with tick-off and a congratulation popup
- **Water tracker**: daily goal, add or remove glasses, 7 day history
- **Sleep tracker**: bedtime and wake-up log, weekly chart, streak, one entry per day
- **Skin journal**: notes, mood rating and progress photos (Premium)
- **AI skin scan**: photo analysis powered by the Groq API
- **Smart notifications**: local phone reminders (for example "you have not had water for 2 hours"), cancelled once the task is done
- **Premium subscription**: payments through Cashfree, verified on the server
- **Multi-language**: English, Hindi and Marathi
- **Insights**: trends for routine, water, sleep and journal

## Tech stack

| Layer | Technology |
|-------|------------|
| App | Flutter, Dart, `flutter_local_notifications`, `image_picker` |
| Backend | Go, Gin |
| Database | PostgreSQL |
| AI | Groq API |
| Payments | Cashfree (sandbox) |

## Project structure

## Setup

### 1. Backend

Requirements: Go and PostgreSQL.

```bash
cd backend
cp .env.example .env     # then fill in your own values
go run .
```

The API starts on `http://localhost:8081`. Check `http://localhost:8081/api/health`.

### 2. App (web)

```bash
cd mobile
flutter pub get
flutter run -d chrome --web-port 5000 --dart-define=API_BASE_URL=http://localhost:8081
```

### 3. App (Android APK)

```bash
cd mobile
flutter build apk --release --dart-define=API_BASE_URL=http://<YOUR_PC_IP>:8081
```

The phone and the PC must be on the same WiFi network.

## Environment variables

Create `backend/.env` (never commit this file):

| Variable | Description |
|----------|-------------|
| `DATABASE_URL` | PostgreSQL connection string |
| `PORT` | API port (8081) |
| `ALLOWED_ORIGINS` | Comma separated origins, empty in development |
| `UPLOAD_DIR` | Folder for uploaded photos |
| `GROQ_API_KEY` | Groq API key for the AI skin scan |
| `GROQ_MODEL` | Groq model name |
| `CASHFREE_APP_ID` | Cashfree app id |
| `CASHFREE_SECRET_KEY` | Cashfree secret key |
| `CASHFREE_ENV` | `sandbox` or `production` |
| `CASHFREE_CUSTOMER_PHONE` | Customer phone sent with orders |
| `PREMIUM_DEMO` | `true` gives Premium without payment (testing only) |

## Security notes

- API keys stay on the server and never ship in the app.
- Premium is activated only after the server verifies the order with Cashfree and checks the amount.
- Uploaded photos are checked by content type and size, and saved with random file names.

## Known limitations

- Cashfree checkout currently works on web only. Android checkout is not finished.
- Photos are stored on the server disk. A cloud storage service (for example S3) is better for production.

## Author

Aniket Kadam

# Voice Ledger — Mobile App

Flutter client for a voice-enabled personal financial ledger backed by a
Raspberry Pi. This folder contains **only** the mobile front end; the
`rpi_server/` backend is a separate deliverable.

## What it does

- Captures a spoken sentence on the phone using Android's speech recogniser.
- Shows the live transcript, lets you edit it, and only proceeds when you press
  **Confirm**.
- Interprets the confirmed text locally with a deterministic, rule-based Dart
  parser (no LLM, no network call).
- Shows a structured review screen, then sends the entry over HTTPS to the
  Raspberry Pi, which is authoritative for balances and currency conversion.

Audio never leaves the phone. Only the text you confirm is transmitted.

## Tech stack

Flutter + Dart, Material 3, Riverpod, `go_router`, Dio,
`flutter_secure_storage`, `speech_to_text` (Android SpeechRecognizer), `intl`.

## Run it

```bash
cd mobile_app
flutter pub get

# Point the app at your Raspberry Pi (default is https://raspberrypi.local/api/v1)
flutter run \
  --dart-define=API_BASE_URL=https://192.168.1.42/api/v1 \
  --dart-define=APP_ENV=development
```

Run on a **real Android device** and grant microphone permission. On Android
physical devices it is best to use the Pi's LAN IP, since `.local` (mDNS) is not
always reachable.

## Tests

```bash
flutter analyze
flutter test                                   # unit + widget tests
flutter test integration_test -d <device-id>   # on-device smoke test
```

- `test/inr_formatter_test.dart` — INR formatting/parsing.
- `test/nlp_parsers_test.dart` — amount, date and intent parsing.
- `test/voice_entry_controller_test.dart` — partial transcript, final transcript,
  editing, confirmation and empty-transcript guard.
- `test/voice_review_flow_test.dart` — review screen saves a confirmed command
  against a fake repository.

## Build

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://ledger.example.com/api/v1
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

The release build is signed with the APK release key when
`android/key.properties` exists; otherwise it falls back to debug signing for
local testing. See `android/key.properties.example` and the Pi deployment guide.

## Architecture

```
lib/
  config/            compile-time AppConfig (API URL, timeouts)
  core/
    errors/          typed AppException + friendly messages
    theme/           Material 3 theme + FinanceColors extension
    utils/           INR/date formatters, validators, request ids
    widgets/         shared UI building blocks
  models/            immutable data models with fromJson
  features/
    auth/            splash, login, create account
    voice/           speech UI + on-device NLP engine
    dashboard/       balance, metrics, category split, recent activity
    calendar/        month grid + per-day activity
    transactions/    searchable, paged history
    ledger/          expenses, income, savings, lending, borrowing, repayments
    persons/         people directory
    categories/      category management
    profile/         account overview
    settings/        theme, privacy, voice, reminders
    admin/           whitelisted maintenance actions
    shared/          shell with bottom navigation + voice button
  providers/         Riverpod providers (infra, auth, settings, ledger)
  repositories/      API access (auth, ledger, directory, admin)
  router/            go_router configuration
  services/          Dio client, secure token storage, speech wrapper
```

State flows one way: widgets watch providers, providers call repositories,
repositories call the API through Dio.

## API expectations

The client expects JSON envelope responses. Endpoints used:

- `POST /auth/login`, `POST /auth/register`, `GET /auth/me`
- `GET /dashboard/summary`, `GET /calendar?month=YYYY-MM`
- `GET /transactions`, `GET /transactions/{id}`
- `POST /commands` for every confirmed voice/manual entry
- `GET /loans?kind=lent|borrowed`
- `GET /repayments`, `GET /persons`, `GET /categories`
- `POST /admin/actions`

`POST /commands` accepts the canonical intent payload and an `Idempotency-Key`
header (the same `request_id` is reused across retries so the server can replay
safely). The response may include `amount_inr`, `exchange_rate_to_inr`,
`available_balance` and `idempotent_replay`.

## Key assumptions

- Rupee (INR) is the canonical currency; other currencies are converted by the
  server, never on the device.
- Balances, totals and loan outstanding are **always** server-authoritative.
  The app only displays what the Pi confirms.
- The backend exposes a fixed set of admin commands (`AdminAction`); the app can
  never send raw SQL.
- Speech recognition quality depends on the phone; English (India) is preferred
  and the transcript is always editable before anything is sent.
- No secrets are stored in the app; the API URL is supplied via `--dart-define`
  and tokens live in the platform keystore.
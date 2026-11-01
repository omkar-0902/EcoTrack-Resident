# EcoConnect (resident app)

Resident-facing Flutter app of the EcoTrack waste collection system. Residents
register, schedule a pickup (date + current location), track it, confirm the
outcome and see their EcoPoints. The collector app (EcoDispatch) is a separate
project; both talk to the same backend.

## Run

```bash
flutter pub get
flutter run                                          # default backend
flutter run --dart-define-from-file=config/dev.json  # per-environment settings
```

Copy `config/dev.example.json` / `config/prod.example.json` to `config/dev.json`
/ `config/prod.json` (git-ignored) and fill in the values.

| Define | Purpose |
|---|---|
| `API_BASE_URL` | Backend base URL |
| `APP_ENV` | `dev` / `prod` (informational) |
| `PICKUP_MAX_ACCURACY_M` | Optional: refuse pickup locations less precise than this (meters). Unset = no limit; agree the value with the backend team |

## Test

```bash
flutter analyze
flutter test                                      # app tests
cd ../packages/geofence_contract && dart test     # shared geofencing package
```

## Layout

```
lib/
  core/            theme, haptics, session (sign-out), config (API, location)
  models/          request/response + local models
  services/        HTTP client, auth/session, user profile, location
  repositories/    PickupRepository (interface + HTTP implementation)
  features/        screens + state per feature (auth, dashboard, schedule,
                   tracking, rewards, profile, onboarding, main shell)
  shared/widgets/  reusable widgets
../packages/geofence_contract/   shared pure-Dart geofencing contract
```

Backend contract, pickup lifecycle and geofencing integration:
[`../docs/BACKEND_INTEGRATION.md`](../docs/BACKEND_INTEGRATION.md).

# EcoConnect — Backend Integration & Geofencing Handover

For the backend developer connecting **EcoConnect** (resident app, `app/`) and,
later, **EcoDispatch** (collector app, separate project) to the shared backend.

Every endpoint marked **Verified** is taken from the current app code and its
behaviour against the live server. Everything marked **Prepared** exists in the
app as an interface but has **no backend contract yet**: it sends no request and
returns "not supported". Nothing here is an invented schema; items marked
**❓ Needs decision** must be agreed with you.

---

## 1. Application architecture

```
app/lib/
  core/config/api_config.dart        base URL, environment, timeout, poll interval, endpoint paths
  core/config/location_config.dart   location thresholds (from build config, no defaults)
  core/session.dart                  sign-out (clears token + in-memory state)
  services/api_service.dart          HTTP client: headers, Bearer token, timeout, network errors
  services/api_result.dart           ApiResult<T>: success | failure | notSupported
  services/auth_service.dart         register, login, JWT storage, local pickup record
  services/user_service.dart         GET /users/profile
  services/location_service.dart     foreground location (permission, services, one fix, accuracy)
  repositories/pickup_repository.dart PickupRepository interface + HttpPickupRepository + PickupCapabilities
  models/                            request/response + local models
  features/tracking/                 PickupTrackingController (single pickup state machine),
                                     timeline mapping, tracking screen
packages/geofence_contract/          shared pure-Dart geofencing contract (both apps)
```

* **State management:** Riverpod 3. `pickupTrackingProvider` is the single
  source of truth for the resident's pickup; `userProfileProvider` for the
  profile; `pickupRepositoryProvider` and `locationServiceProvider` are
  injectable (tests replace them).
* **No API logic in widgets.** Screens call the controller / services and get
  `ApiResult`s. URLs live only in `ApiEndpoints`.
* **Errors:** offline / DNS / TLS / timeout become a failed `ApiResult` with a
  user message; HTTP status codes are mapped per endpoint; malformed bodies are
  handled (never crash).

### Configuration

```bash
flutter run --dart-define-from-file=config/dev.json
flutter build apk --dart-define-from-file=config/prod.json
```

| Key | Meaning |
|---|---|
| `API_BASE_URL` | Default `https://ecotrack-rm92.onrender.com` |
| `APP_ENV` | `dev` / `prod` |
| `PICKUP_MAX_ACCURACY_M` | Optional pickup-location accuracy limit (meters). Unset = none. ❓ Needs decision |

No credentials or API keys exist in the app. Auth is the JWT issued at login.
Plain `http://` URLs need Android cleartext traffic enabled (not enabled today).

---

## 2. Existing API integration

### Verified endpoints

All requests send `Content-Type: application/json` and `Accept: application/json`.
Authenticated ones add `Authorization: Bearer <jwt>`. Any 2xx counts as success.
Timeout is 30 s.

| Endpoint | Request | Response the app relies on |
|---|---|---|
| `POST /public/register` | `{userName, password, phoneNumber, address, role:"ROLE_RESIDENT"}` | 2xx = ok; 403 = "Forbidden" message |
| `POST /users/login` | `{userName, password}` | 2xx with the **raw JWT as plain text** |
| `GET /users/profile` | — | JSON `{userName, ecoPoints, totalPickups, lastPickupDate}` (tolerant parsing); 401 → sign out |
| `GET /pickups/active` | — | 2xx + **pickup id as plain text**, or empty body (204 also fine) when none |
| `POST /pickups` | `{requestDate:"yyyy-MM-dd", latitude, longitude}` | 2xx + **new pickup id as plain text**; **403 = an active pickup already exists** (app then reads `/pickups/active`) |
| `PUT /pickups/status` | `{pickupId, status:"COMPLETED", points:10}` or `{pickupId, status:"FAILED"}` | 2xx = ok |

The JWT `sub` claim is shown as the username. Unauthenticated requests to the
live server return **403** (checked 2026-11-01), so an expired token is probably
a 403 rather than a 401. ❓ Needs decision: confirm the code, since the app only
signs out on 401.

### Prepared integration points (no contract yet)

`PickupRepository` already declares these. `HttpPickupRepository` returns
`ApiResult.notSupported` for each, and `PickupCapabilities.current` has every
flag `false`. To connect one: implement the method, then flip its flag.

| Method | Capability flag | Purpose |
|---|---|---|
| `getPickup(id)` → `PickupRecord` | `fetchById` | One pickup in any status (enables tracking past requests) |
| `getPickupHistory()` → `List<PickupRecord>` | `history` | Request history screen (none exists yet: no data) |
| `cancelPickup(id)` | `cancel` | Cancel/modify (no UI yet) |
| `getGeofence(pickupId)` → `Geofence` | `geofence` | Backend-issued geofence for a pickup |
| `getVerifiedEvents(pickupId)` → `List<GeofenceEvent>` | `verifiedEvents` | Verified collector progress shown on the tracking timeline |

`PickupRecord` holds only `pickupId`, raw status, request date and location,
which are things the app already sends or shows. Map the real response onto it.

---

## 3. Pickup lifecycle (resident side)

1. **Schedule:** the resident picks a date (today..+4 days). `LocationService`
   ensures *while-in-use* permission and reads **one** GPS fix. `POST /pickups`
   sends date + coordinates. The device stores (locally only) the id, date,
   request time, coordinates and reported accuracy, because the backend does not
   return them. No location history is kept.
2. **Track:** `PickupTrackingController` polls `GET /pickups/active` every 30 s
   while the tracking screen is open and the app is in the foreground. Home
   re-checks on load and on app resume. Overlapping checks are merged. When
   `verifiedEvents` is supported, the same poll also fetches verified events.
3. **Resolve (existing business rule):** the resident taps **Picked up**
   (`COMPLETED`, 10 points) or **Not picked up** (`FAILED`).
4. **Closed elsewhere:** if `/pickups/active` stops returning the id without
   this device reporting an outcome, the app shows "No longer active". It
   **never** assumes completion.

### Timeline mapping (`features/tracking/domain/tracking_timeline.dart`)

| Stage | Confirmed by | Today |
|---|---|---|
| Pickup Requested | `POST /pickups` 2xx | ✅ |
| Request Confirmed | `/pickups/active` lists the id | ✅ |
| Collector Assigned | verified `collectorAssigned` | "Not reported" |
| Collector En Route | verified `collectorApproaching` / `geofenceEntered` | "Not reported" |
| Pickup Arrived | verified `collectorArrived` / `collectionStarted` | "Not reported" |
| Waste Collected | verified `collectionCompleted`, or resident's **Picked up** | ✅ (resident) |
| Pickup Completed | `PUT /pickups/status COMPLETED` 2xx | ✅ |
| Not Collected | `PUT /pickups/status FAILED` 2xx | ✅ |
| No Longer Active | id disappears from `/pickups/active` | ✅ |

Collector stages show **"Not reported"** while `verifiedEvents` is unsupported,
and **"upcoming"** once it is supported. Verified events only *annotate* the
timeline. The pickup's status (active / completed / failed) still comes only
from backend status, so there is one state machine, not two.

---

## 4. EcoConnect ↔ EcoDispatch geofencing integration

### Shared contract: `packages/geofence_contract` (pure Dart)

EcoConnect already depends on it (`path: ../packages/geofence_contract`).
EcoDispatch should depend on the same package (path or git), so both apps
share one definition.

| Type | Content |
|---|---|
| `GeoPoint` | Validated WGS-84 coordinate, haversine distance |
| `Geofence` | `id`, `pickupId`, `center`, `radiusMeters`, `version`. **No default radius**; issued by the backend |
| `GeofenceEventType` | `pickupLocationEstablished`, `collectorAssigned`, `collectorApproaching`, `geofenceEntered`, `geofenceExited`, `collectorArrived`, `collectionStarted`, `collectionCompleted`, `pickupClosed`. One-shot types carry a lifecycle rank; enter/exit are repeatable |
| `GeofenceEventSource` | `resident`, `collector`, `backend` |
| `GeofenceEvent` | `eventId` (idempotency key), `pickupId`, `type`, `occurredAt` (UTC), `source`, optional `geofenceId`, `geofenceVersion`, single `location`, `accuracyMeters`, `actorId` |
| `GeofenceWireMapper` | **Interface** to translate to/from the backend's field names, once agreed. Nothing depends on backend names |
| `GeofencePolicy` | `maxAccuracyMeters`, `maxEventAge`, `maxClockSkew`, `retryDelays`. **All required, no defaults** |
| `GeofenceEvaluator` | inside / outside / **uncertain** / **unusable**, accounting for fix accuracy |
| `GeofenceTransitionDetector` | Enter/exit from confident readings only (no GPS jitter flapping) |
| `EventOutbox` | Controlled offline queue for collector events (below) |

The field names above are **candidate requirements**, not a backend schema.

### Responsibilities

| | EcoConnect (resident) | EcoDispatch (collector) | Backend (authoritative) |
|---|---|---|---|
| Pickup location | Sends coordinates with `POST /pickups` (one foreground fix) | Receives it with the assignment | Stores it; issues the geofence |
| Geofence config | Displays only (when exposed) | Fetches and monitors it | **Owns** radius and version |
| Collector location | ✗ never | Monitors while authorised | Verifies reported events |
| Geofence events | ✗ never produces collector events | Detects, queues, reports | **Validates, deduplicates, decides** |
| Arrival / collection / closure | Displays verified results | Reports claims | **Authoritative** |

**EcoConnect never marks a pickup collected because a phone entered a
geofence.** Resident-sourced events are ignored for collector stages
(`tracking_timeline.dart`, tested).

### Event flow (expected)

1. Backend assigns a pickup to a collector and issues `Geofence{id, pickupId,
   center, radiusMeters, version}`.
2. EcoDispatch evaluates fixes with `GeofenceEvaluator` + `GeofencePolicy`,
   turns confident transitions into `GeofenceEvent`s (new `eventId` each,
   `source: collector`, `geofenceVersion` set), and `enqueue`s them in
   `EventOutbox`.
3. `EventOutbox.flush()` sends events through a `GeofenceEventSender` (to be
   written in EcoDispatch with the agreed endpoint + `GeofenceWireMapper`).
4. Backend validates each event (identity, assignment, geofence version, time,
   location/accuracy, lifecycle) and acknowledges or rejects it. Then it
   updates the pickup.
5. EcoConnect receives the result through `getVerifiedEvents` (or a push
   channel, if one is added) and the pickup status.

### Duplicate prevention

* `eventId` is generated once per event and reused on every retry. **The
  backend should treat it as an idempotency key.**
* The outbox refuses the same `eventId` twice, and refuses a second one-shot
  event of the same type for a pickup (queued or already acknowledged).
* The backend should still enforce uniqueness (the device can be reinstalled).

### Offline synchronisation (`EventOutbox`)

* Persistent via an `OutboxStore` (JSON format provided). Stores only queued
  events plus small bookkeeping; **no location history**.
* An event is removed as delivered **only after the backend acknowledges it**.
* `retryLater` (offline, timeout, 5xx) is retried on the `retryDelays`
  schedule. After the last retry it is moved to `failed` (**never retried
  forever**). `rejected` is final.
* Events older than `maxEventAge` or dated beyond `maxClockSkew` in the future
  are refused (also re-checked before sending).
* Lifecycle guard: a one-shot event earlier than one already reported is
  refused (e.g. "approaching" after "arrived"), and nothing is accepted for a
  closed pickup (`markPickupClosed`).
* Events of one pickup are sent in order; one waiting for a retry holds back
  later events of the same pickup only.
* One flush at a time.

### Transitions that require backend verification

Collector assigned, approaching / entered, arrived, collection started,
collection completed, pickup closed. The resident's **Picked up / Not picked
up** confirmation is the existing business rule (`PUT /pickups/status`).
❓ Needs decision: whether it stays authoritative once collector events exist,
and whether the client should keep sending `points`.

---

## 5. Permissions and platform limits

| Platform | Declared | Why |
|---|---|---|
| Android | `INTERNET` | Backend |
| Android | `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION` | One foreground fix when scheduling. COARSE is required with FINE on Android 12+ (the user may grant approximate only, which shows as a large accuracy value) |
| iOS | `NSLocationWhenInUseUsageDescription` | Same, while-in-use only (was **missing**; iOS would have terminated the app on the location request) |

* **Not declared on purpose:** `ACCESS_BACKGROUND_LOCATION`, iOS "Always", and
  foreground services. The resident app never tracks location in the
  background.
* Permission is requested when needed (onboarding "Allow location" or
  scheduling), never silently at launch. Denied → explained. Permanently
  denied / GPS off → a Settings shortcut.
* **For EcoDispatch:** background geofencing needs background location
  permission, Play Store / App Store justification, battery-optimisation
  handling, and (Android) a foreground service. OS geofencing is best-effort:
  delivery can be delayed or missing when the app is killed, in Doze, or with
  battery saver. The backend must not depend on every event arriving.

---

## 6. Backend developer checklist

- [ ] Production API base URL (+ staging if any)
- [ ] Auth: token lifetime, refresh, 401 vs 403 on expiry
- [ ] Pickup request schema (confirm `requestDate` / `latitude` / `longitude`; time window?)
- [ ] Pickup response schema for get-by-id and history (`PickupRecord`)
- [ ] Pickup **status enumeration** and allowed transitions
- [ ] Error body format (e.g. `{ "message": … }`) for user-facing errors
- [ ] Cancel / modify rules
- [ ] Collector assignment response (what the resident may see: name? vehicle?)
- [ ] **Geofence configuration schema** (id, centre, radius, version) and who sets the radius
- [ ] **Geofence event reporting endpoint** + wire format (implement `GeofenceWireMapper`)
- [ ] **Event acknowledgement format** (ack / reject + reason; idempotent on `eventId`)
- [ ] Location verification rules (accuracy limit, dwell time, speed / plausibility checks)
- [ ] `GeofencePolicy` values: max accuracy, max event age, clock skew, retry schedule
- [ ] Status update mechanism for residents: polling `getVerifiedEvents` (supported now) or push (FCM / WebSocket / SSE)
- [ ] Offline sync expectations (late events accepted? until when?)
- [ ] Who confirms collection (resident, collector, or both) and who awards points

## Static UI with no backend behind it

Notifications (list, filter chips, ⋮ menu), Rewards badges and tier thresholds
(500 / 1500 / 3000), Profile email / "Zone 4B" labels, avatar edit button.

## Tests

```bash
cd app && flutter test                          # 84 tests incl. fake-backend contract tests
cd packages/geofence_contract && dart test      # 14 tests: evaluator, outbox, models
```

`app/test/support/test_harness.dart` (`FakeBackend`) encodes the verified
contract above. Update it if the contract changes.

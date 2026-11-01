# geofence_contract

Shared, backend-agnostic geofencing contract for the two EcoTrack apps:

- **EcoConnect** (resident app, `../../app`) uses the models to *display*
  verified collector events delivered by the backend. It never reports
  collector events itself.
- **EcoDispatch** (collector app, separate project) is expected to use the
  evaluator and the outbox to *detect and report* events.

Pure Dart, no dependencies, so it can also be used by Dart tooling or tests.

| File | Purpose |
|---|---|
| `geo_point.dart` | Validated coordinate + haversine distance |
| `geofence.dart` | Geofence issued by the backend (id, pickup, centre, radius, version); no default radius |
| `geofence_event.dart` | Workflow event types, sources, event model, `GeofenceWireMapper` interface for the (not yet agreed) backend wire format |
| `geofence_policy.dart` | Thresholds to agree with the backend (accuracy, max age, clock skew, retry schedule); no defaults |
| `geofence_evaluator.dart` | Accuracy-aware inside / outside / uncertain / unusable classification and jitter-free enter/exit detection |
| `event_outbox.dart` | Controlled offline queue: ack-only removal, bounded retries, dedupe, stale/lifecycle rejection, per-pickup ordering |

The backend stays authoritative for geofence configuration, assignment,
verified arrival, collection and closure. See `../../docs/BACKEND_INTEGRATION.md`.

```bash
dart pub get
dart test
```

import 'dart:convert';

import 'package:geofence_contract/geofence_contract.dart';
import 'package:test/test.dart';

/// Test-only policy values. Real values must come from the backend contract.
GeofencePolicy testPolicy({List<Duration>? retryDelays}) => GeofencePolicy(
      maxAccuracyMeters: 50,
      maxEventAge: const Duration(hours: 1),
      maxClockSkew: const Duration(minutes: 2),
      retryDelays: retryDelays ??
          const [Duration(seconds: 10), Duration(seconds: 60)],
    );

final t0 = DateTime.utc(2026, 11, 2, 7, 0);

GeofenceEvent ev(
  String id,
  GeofenceEventType type, {
  String pickupId = 'p1',
  DateTime? at,
}) =>
    GeofenceEvent(
      eventId: id,
      pickupId: pickupId,
      type: type,
      occurredAt: at ?? t0,
      source: GeofenceEventSource.collector,
    );

class ScriptedSender implements GeofenceEventSender {
  final List<DeliveryOutcome> script;
  final List<String> sent = [];
  ScriptedSender(this.script);

  @override
  Future<DeliveryOutcome> send(GeofenceEvent event) async {
    sent.add(event.eventId);
    return script.isEmpty ? const DeliveryOutcome.acknowledged() : script.removeAt(0);
  }
}

void main() {
  group('models', () {
    test('coordinates and radius are validated; no defaults', () {
      expect(() => GeoPoint(91, 0), throwsArgumentError);
      expect(() => GeoPoint(0, 181), throwsArgumentError);
      expect(
        () => Geofence(
            id: 'g', pickupId: 'p', center: GeoPoint(0, 0), radiusMeters: 0, version: 1),
        throwsArgumentError,
      );
    });

    test('haversine distance is accurate', () {
      // 0.001 deg of latitude is ~111.2 m.
      final d = GeoPoint(15.0, 73.0).distanceTo(GeoPoint(15.001, 73.0));
      expect(d, closeTo(111.2, 0.5));
    });

    test('events normalise timestamps to UTC and round-trip storage JSON', () {
      final e = GeofenceEvent(
        eventId: 'e1',
        pickupId: 'p1',
        type: GeofenceEventType.geofenceEntered,
        occurredAt: DateTime(2026, 11, 2, 12, 30),
        source: GeofenceEventSource.collector,
        geofenceId: 'g1',
        geofenceVersion: 3,
        location: GeoPoint(15.49, 73.82),
        accuracyMeters: 8,
      );
      expect(e.occurredAt.isUtc, isTrue);
      final back = GeofenceEvent.fromStorageJson(
          (jsonDecode(jsonEncode(e.toStorageJson())) as Map).cast());
      expect(back.eventId, 'e1');
      expect(back.type, GeofenceEventType.geofenceEntered);
      expect(back.location, GeoPoint(15.49, 73.82));
      expect(back.geofenceVersion, 3);
      expect(back.occurredAt, e.occurredAt);
    });
  });

  group('GeofenceEvaluator', () {
    final fence = Geofence(
        id: 'g1', pickupId: 'p1', center: GeoPoint(15.0, 73.0), radiusMeters: 100, version: 1);
    final evaluator = GeofenceEvaluator(testPolicy());

    test('accounts for accuracy on both sides of the boundary', () {
      // ~55 m from centre.
      final near = GeoPoint(15.0005, 73.0);
      expect(evaluator.classify(fence, near, accuracyMeters: 10), Proximity.inside);
      expect(evaluator.classify(fence, near, accuracyMeters: 49), Proximity.uncertain);
      // ~222 m from centre.
      final far = GeoPoint(15.002, 73.0);
      expect(evaluator.classify(fence, far, accuracyMeters: 20), Proximity.outside);
    });

    test('unknown or too-poor accuracy is unusable, never "inside"', () {
      final center = GeoPoint(15.0, 73.0);
      expect(evaluator.classify(fence, center, accuracyMeters: null), Proximity.unusable);
      expect(evaluator.classify(fence, center, accuracyMeters: 51), Proximity.unusable);
    });

    test('transition detector ignores jitter and reports confident changes', () {
      final d = GeofenceTransitionDetector();
      expect(d.update(Proximity.outside), isNull); // initial state, not an exit
      expect(d.update(Proximity.uncertain), isNull);
      expect(d.update(Proximity.inside), Proximity.inside); // entry
      expect(d.update(Proximity.unusable), isNull);
      expect(d.update(Proximity.inside), isNull); // no repeat
      expect(d.update(Proximity.outside), Proximity.outside); // exit
    });
  });

  group('EventOutbox', () {
    late DateTime now;
    EventOutbox outbox(GeofenceEventSender sender, {GeofencePolicy? policy}) =>
        EventOutbox(
          store: InMemoryOutboxStore(),
          sender: sender,
          policy: policy ?? testPolicy(),
          clock: () => now,
        );

    setUp(() => now = t0.add(const Duration(minutes: 1)));

    test('only acknowledged events are removed', () async {
      final sender = ScriptedSender([const DeliveryOutcome.retryLater('offline')]);
      final box = outbox(sender);
      await box.enqueue(ev('a', GeofenceEventType.collectorArrived));

      var report = await box.flush();
      expect(report.retryScheduled, 1);
      expect((await box.store.load()).pending, hasLength(1));

      now = now.add(const Duration(seconds: 11));
      report = await box.flush();
      expect(report.acknowledged, 1);
      expect((await box.store.load()).pending, isEmpty);
      expect(sender.sent, ['a', 'a']); // same idempotency key reused
    });

    test('retries are bounded, then the event is marked failed', () async {
      final sender = ScriptedSender(List.filled(5, const DeliveryOutcome.retryLater()));
      final box = outbox(sender);
      await box.enqueue(ev('a', GeofenceEventType.collectorArrived));

      await box.flush(); // attempt 1
      now = now.add(const Duration(seconds: 10));
      await box.flush(); // attempt 2
      now = now.add(const Duration(seconds: 60));
      final last = await box.flush(); // attempt 3 = max (2 retries)

      expect(last.failedPermanently, 1);
      final state = await box.store.load();
      expect(state.pending, isEmpty);
      expect(state.failed.single.reason, contains('3 attempts'));
      now = now.add(const Duration(hours: 1));
      await box.flush();
      expect(sender.sent, hasLength(3));
    });

    test('backend rejection is final (no retry)', () async {
      final sender = ScriptedSender([const DeliveryOutcome.rejected('outside verified area')]);
      final box = outbox(sender);
      await box.enqueue(ev('a', GeofenceEventType.collectorArrived));
      final report = await box.flush();
      expect(report.rejected, 1);
      expect((await box.store.load()).failed.single.reason, 'outside verified area');
    });

    test('duplicates are refused: same id or repeated one-shot type', () async {
      final box = outbox(ScriptedSender([]));
      expect(await box.enqueue(ev('a', GeofenceEventType.collectorArrived)),
          EnqueueResult.queued);
      expect(await box.enqueue(ev('a', GeofenceEventType.collectorArrived)),
          EnqueueResult.duplicate);
      expect(await box.enqueue(ev('b', GeofenceEventType.collectorArrived)),
          EnqueueResult.duplicate);
      await box.flush();
      // Still a duplicate after delivery.
      expect(await box.enqueue(ev('c', GeofenceEventType.collectorArrived)),
          EnqueueResult.duplicate);
      // Repeatable types are allowed more than once.
      expect(await box.enqueue(ev('d', GeofenceEventType.geofenceEntered)),
          EnqueueResult.queued);
      expect(await box.enqueue(ev('e', GeofenceEventType.geofenceEntered)),
          EnqueueResult.queued);
    });

    test('stale, future-dated and out-of-order events are rejected', () async {
      final box = outbox(ScriptedSender([]));
      expect(
        await box.enqueue(ev('old', GeofenceEventType.collectorApproaching,
            at: now.subtract(const Duration(hours: 2)))),
        EnqueueResult.stale,
      );
      expect(
        await box.enqueue(ev('future', GeofenceEventType.collectorApproaching,
            at: now.add(const Duration(minutes: 10)))),
        EnqueueResult.futureTimestamp,
      );
      await box.enqueue(ev('arr', GeofenceEventType.collectorArrived));
      expect(await box.enqueue(ev('appr', GeofenceEventType.collectorApproaching)),
          EnqueueResult.outOfOrder);
    });

    test('closed pickups accept no further events', () async {
      final box = outbox(ScriptedSender([]));
      await box.enqueue(ev('arr', GeofenceEventType.collectorArrived));
      await box.markPickupClosed('p1');
      expect((await box.store.load()).pending, isEmpty);
      expect(await box.enqueue(ev('x', GeofenceEventType.geofenceExited)),
          EnqueueResult.pickupClosed);
    });

    test('events of one pickup are delivered in order', () async {
      final sender = ScriptedSender([const DeliveryOutcome.retryLater()]);
      final box = outbox(sender);
      await box.enqueue(ev('enter', GeofenceEventType.geofenceEntered,
          at: t0));
      await box.enqueue(ev('arrive', GeofenceEventType.collectorArrived,
          at: t0.add(const Duration(seconds: 30))));
      await box.enqueue(ev('other', GeofenceEventType.collectorArrived,
          pickupId: 'p2', at: t0.add(const Duration(seconds: 40))));

      await box.flush();
      // "arrive" waits behind the retrying "enter"; p2 is unaffected.
      expect(sender.sent, ['enter', 'other']);
    });

    test('state survives a JSON round trip (for persistent stores)', () async {
      final box = outbox(ScriptedSender([const DeliveryOutcome.retryLater()]));
      await box.enqueue(ev('a', GeofenceEventType.collectorArrived));
      await box.flush();
      final json = jsonEncode((await box.store.load()).toJson());
      final restored = OutboxState.fromJson((jsonDecode(json) as Map).cast());
      expect(restored.pending.single.attempts, 1);
      expect(restored.highestRank['p1'], GeofenceEventType.collectorArrived.lifecycleRank);
    });
  });
}

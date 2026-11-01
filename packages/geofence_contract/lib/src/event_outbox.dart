import 'dart:async';

import 'geofence_event.dart';
import 'geofence_policy.dart';

/// What the backend said about one delivery attempt.
enum DeliveryStatus {
  /// The backend confirmed it stored the event. Only now is it "delivered".
  acknowledged,

  /// The backend refused the event (invalid, unverifiable, wrong lifecycle
  /// state...). Retrying would not help; it is moved to the failed list.
  rejected,

  /// Temporary problem (offline, timeout, 5xx). Retried per the policy.
  retryLater,
}

class DeliveryOutcome {
  final DeliveryStatus status;
  final String? reason;

  const DeliveryOutcome._(this.status, this.reason);
  const DeliveryOutcome.acknowledged() : this._(DeliveryStatus.acknowledged, null);
  const DeliveryOutcome.rejected(String reason)
      : this._(DeliveryStatus.rejected, reason);
  const DeliveryOutcome.retryLater([String? reason])
      : this._(DeliveryStatus.retryLater, reason);
}

/// Sends one event to the backend. Implemented by the app once the event
/// reporting endpoint exists (using a [GeofenceWireMapper]). Must reuse
/// [GeofenceEvent.eventId] as the idempotency key on every attempt.
abstract interface class GeofenceEventSender {
  Future<DeliveryOutcome> send(GeofenceEvent event);
}

class OutboxEntry {
  final GeofenceEvent event;
  final int attempts;
  final DateTime? nextAttemptAt;

  const OutboxEntry(this.event, {this.attempts = 0, this.nextAttemptAt});

  OutboxEntry retried(DateTime next) =>
      OutboxEntry(event, attempts: attempts + 1, nextAttemptAt: next);

  Map<String, Object?> toJson() => {
        'event': event.toStorageJson(),
        'attempts': attempts,
        'nextAttemptAt': nextAttemptAt?.toIso8601String(),
      };

  factory OutboxEntry.fromJson(Map<String, Object?> json) => OutboxEntry(
        GeofenceEvent.fromStorageJson(
            (json['event'] as Map).cast<String, Object?>()),
        attempts: json['attempts'] as int,
        nextAttemptAt: json['nextAttemptAt'] == null
            ? null
            : DateTime.parse(json['nextAttemptAt'] as String),
      );
}

class FailedDelivery {
  final GeofenceEvent event;
  final String reason;

  const FailedDelivery(this.event, this.reason);

  Map<String, Object?> toJson() =>
      {'event': event.toStorageJson(), 'reason': reason};

  factory FailedDelivery.fromJson(Map<String, Object?> json) => FailedDelivery(
        GeofenceEvent.fromStorageJson(
            (json['event'] as Map).cast<String, Object?>()),
        json['reason'] as String,
      );
}

/// Everything the outbox persists. Only queued events plus small bookkeeping
/// (dedupe keys, highest lifecycle rank, closed pickups); no location history.
class OutboxState {
  final List<OutboxEntry> pending;
  final List<FailedDelivery> failed;

  /// Dedupe keys of acknowledged events.
  final Set<String> deliveredKeys;

  /// Highest one-shot lifecycle rank queued or delivered, per pickup.
  final Map<String, int> highestRank;

  final Set<String> closedPickups;

  OutboxState({
    List<OutboxEntry>? pending,
    List<FailedDelivery>? failed,
    Set<String>? deliveredKeys,
    Map<String, int>? highestRank,
    Set<String>? closedPickups,
  })  : pending = pending ?? [],
        failed = failed ?? [],
        deliveredKeys = deliveredKeys ?? {},
        highestRank = highestRank ?? {},
        closedPickups = closedPickups ?? {};

  Map<String, Object?> toJson() => {
        'pending': pending.map((e) => e.toJson()).toList(),
        'failed': failed.map((e) => e.toJson()).toList(),
        'deliveredKeys': deliveredKeys.toList(),
        'highestRank': highestRank,
        'closedPickups': closedPickups.toList(),
      };

  factory OutboxState.fromJson(Map<String, Object?> json) => OutboxState(
        pending: (json['pending'] as List)
            .map((e) => OutboxEntry.fromJson((e as Map).cast()))
            .toList(),
        failed: (json['failed'] as List)
            .map((e) => FailedDelivery.fromJson((e as Map).cast()))
            .toList(),
        deliveredKeys: (json['deliveredKeys'] as List).cast<String>().toSet(),
        highestRank: (json['highestRank'] as Map).cast<String, int>(),
        closedPickups: (json['closedPickups'] as List).cast<String>().toSet(),
      );
}

/// Persistence for the outbox (e.g. a file or local database in the collector
/// app). [OutboxState.toJson] / [OutboxState.fromJson] give a ready format.
abstract interface class OutboxStore {
  Future<OutboxState> load();
  Future<void> save(OutboxState state);
}

class InMemoryOutboxStore implements OutboxStore {
  OutboxState _state = OutboxState();

  @override
  Future<OutboxState> load() async => _state;

  @override
  Future<void> save(OutboxState state) async => _state = state;
}

enum EnqueueResult {
  queued,

  /// Same event id, or a one-shot event type already queued/delivered for
  /// this pickup.
  duplicate,

  /// Older than [GeofencePolicy.maxEventAge].
  stale,

  /// Timestamped beyond [GeofencePolicy.maxClockSkew] in the future.
  futureTimestamp,

  /// A one-shot event earlier in the lifecycle than one already reported
  /// (e.g. "approaching" after "arrived").
  outOfOrder,

  /// The pickup is closed; no further events are accepted.
  pickupClosed,
}

class FlushReport {
  final int acknowledged;
  final int rejected;
  final int retryScheduled;
  final int failedPermanently;

  const FlushReport({
    this.acknowledged = 0,
    this.rejected = 0,
    this.retryScheduled = 0,
    this.failedPermanently = 0,
  });
}

/// A controlled, persistent queue for geofence events produced while the
/// device may be offline (collector side).
///
/// Guarantees:
///  * An event is only removed as delivered after the backend acknowledges it.
///  * Retries are bounded by [GeofencePolicy.retryDelays]; then the event is
///    moved to [OutboxState.failed] for the app to surface. No infinite retry.
///  * Duplicates (same id, or a repeated one-shot type) are never queued.
///  * Stale, future-dated, out-of-order and post-closure events are rejected
///    locally; the backend still validates everything it receives.
///  * Events of one pickup are delivered in order: if one must wait for a
///    retry, later events of that pickup wait too.
///  * Only one flush runs at a time.
class EventOutbox {
  final OutboxStore store;
  final GeofenceEventSender sender;
  final GeofencePolicy policy;
  final DateTime Function() _now;

  Future<FlushReport>? _flushing;

  EventOutbox({
    required this.store,
    required this.sender,
    required this.policy,
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  static String _oneShotKey(GeofenceEvent e) => '${e.pickupId}|${e.type.name}';

  Future<EnqueueResult> enqueue(GeofenceEvent event) async {
    final state = await store.load();
    final now = _now().toUtc();

    if (state.closedPickups.contains(event.pickupId)) {
      return EnqueueResult.pickupClosed;
    }
    if (now.difference(event.occurredAt) > policy.maxEventAge) {
      return EnqueueResult.stale;
    }
    if (event.occurredAt.difference(now) > policy.maxClockSkew) {
      return EnqueueResult.futureTimestamp;
    }

    final ids = state.pending.map((e) => e.event.eventId).toSet();
    if (ids.contains(event.eventId) ||
        state.deliveredKeys.contains(event.eventId)) {
      return EnqueueResult.duplicate;
    }

    final rank = event.type.lifecycleRank;
    if (rank != null) {
      final key = _oneShotKey(event);
      final queuedKeys = state.pending.map((e) => _oneShotKey(e.event)).toSet();
      if (queuedKeys.contains(key) || state.deliveredKeys.contains(key)) {
        return EnqueueResult.duplicate;
      }
      final highest = state.highestRank[event.pickupId];
      if (highest != null && rank < highest) {
        return EnqueueResult.outOfOrder;
      }
      state.highestRank[event.pickupId] = rank;
    }

    state.pending.add(OutboxEntry(event));
    if (event.type == GeofenceEventType.pickupClosed) {
      state.closedPickups.add(event.pickupId);
    }
    await store.save(state);
    return EnqueueResult.queued;
  }

  /// The backend reported the pickup closed: drop its pending events and
  /// refuse new ones.
  Future<void> markPickupClosed(String pickupId) async {
    final state = await store.load();
    state.closedPickups.add(pickupId);
    state.pending.removeWhere((e) =>
        e.event.pickupId == pickupId &&
        e.event.type != GeofenceEventType.pickupClosed);
    await store.save(state);
  }

  /// Attempts delivery of every due event. Concurrent calls share one run.
  Future<FlushReport> flush() {
    return _flushing ??= _flush().whenComplete(() => _flushing = null);
  }

  Future<FlushReport> _flush() async {
    final state = await store.load();
    final now = _now().toUtc();
    var acknowledged = 0, rejected = 0, retry = 0, failed = 0;

    final ordered = [...state.pending]
      ..sort((a, b) => a.event.occurredAt.compareTo(b.event.occurredAt));
    final blockedPickups = <String>{};

    for (final entry in ordered) {
      final event = entry.event;
      if (blockedPickups.contains(event.pickupId)) continue;
      final due = entry.nextAttemptAt;
      if (due != null && due.isAfter(now)) {
        blockedPickups.add(event.pickupId);
        continue;
      }

      if (now.difference(event.occurredAt) > policy.maxEventAge) {
        state.pending.remove(entry);
        state.failed.add(FailedDelivery(event, 'stale before delivery'));
        failed++;
        continue;
      }

      DeliveryOutcome outcome;
      try {
        outcome = await sender.send(event);
      } catch (e) {
        outcome = DeliveryOutcome.retryLater('$e');
      }

      switch (outcome.status) {
        case DeliveryStatus.acknowledged:
          state.pending.remove(entry);
          state.deliveredKeys.add(event.eventId);
          if (event.type.isOneShot) state.deliveredKeys.add(_oneShotKey(event));
          acknowledged++;
        case DeliveryStatus.rejected:
          state.pending.remove(entry);
          state.failed.add(
              FailedDelivery(event, outcome.reason ?? 'rejected by backend'));
          rejected++;
        case DeliveryStatus.retryLater:
          final attemptsSoFar = entry.attempts + 1;
          final index = state.pending.indexOf(entry);
          if (attemptsSoFar >= policy.maxAttempts) {
            state.pending.removeAt(index);
            state.failed.add(FailedDelivery(
                event, 'gave up after $attemptsSoFar attempts'));
            failed++;
          } else {
            state.pending[index] =
                entry.retried(now.add(policy.retryDelays[entry.attempts]));
            retry++;
          }
          blockedPickups.add(event.pickupId);
      }
      await store.save(state);
    }

    return FlushReport(
      acknowledged: acknowledged,
      rejected: rejected,
      retryScheduled: retry,
      failedPermanently: failed,
    );
  }
}

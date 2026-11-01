import 'package:flutter/material.dart';
import 'package:geofence_contract/geofence_contract.dart';

import 'pickup_tracking_state.dart';

/// Conceptual lifecycle stages shown on the tracking timeline.
enum TrackingStageId {
  requested,
  confirmed,
  collectorAssigned,
  collectorEnRoute,
  arrived,
  wasteCollected,
  completed,

  /// Off-path outcome: resident reported NOT PICKED UP (`FAILED`).
  notCollected,

  /// Off-path outcome: server closed the pickup, outcome not reported.
  closed,
}

enum StageStatus {
  /// Confirmed by a real backend response.
  done,

  /// The latest confirmed stage, i.e. where the pickup is now.
  current,

  /// Not reached yet.
  upcoming,

  /// The backend has no way to report this stage, so it is never shown as
  /// done. Displayed as "not reported".
  notReported,
}

class TrackingStep {
  final TrackingStageId id;
  final String title;
  final String description;
  final IconData icon;
  final StageStatus status;

  /// Only set when the time comes from a real event (never estimated).
  final DateTime? time;

  /// True for negative outcomes (styled with the error colour).
  final bool isNegative;

  const TrackingStep({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.status,
    this.time,
    this.isNegative = false,
  });

  TrackingStep withStatus(StageStatus status, {String? description}) =>
      TrackingStep(
        id: id,
        title: title,
        description: description ?? this.description,
        icon: icon,
        status: status,
        time: time,
        isNegative: isNegative,
      );
}

/// Backend status strings (sent via `PUT /pickups/status`) -> phase.
const Map<String, PickupPhase> backendStatusToPhase = {
  'COMPLETED': PickupPhase.completed,
  'FAILED': PickupPhase.notCollected,
};

/// Which timeline stage a VERIFIED collector/backend event confirms.
/// `geofenceExited` and `pickupClosed` do not map to a stage: closure is
/// reflected by the pickup phase, which only the backend status changes.
const Map<GeofenceEventType, TrackingStageId> verifiedEventStage = {
  GeofenceEventType.collectorAssigned: TrackingStageId.collectorAssigned,
  GeofenceEventType.collectorApproaching: TrackingStageId.collectorEnRoute,
  GeofenceEventType.geofenceEntered: TrackingStageId.collectorEnRoute,
  GeofenceEventType.collectorArrived: TrackingStageId.arrived,
  GeofenceEventType.collectionStarted: TrackingStageId.arrived,
  GeofenceEventType.collectionCompleted: TrackingStageId.wasteCollected,
};

const _notReportedText =
    'Not reported by the EcoTrack server yet, so this step cannot be tracked.';

/// Earliest verified time per stage. Resident-sourced events are ignored:
/// the resident's phone is never proof of the collector's progress.
Map<TrackingStageId, DateTime> _verifiedStageTimes(List<GeofenceEvent> events) {
  final times = <TrackingStageId, DateTime>{};
  for (final e in events) {
    if (e.source == GeofenceEventSource.resident) continue;
    final stage = verifiedEventStage[e.type];
    if (stage == null) continue;
    final existing = times[stage];
    if (existing == null || e.occurredAt.isBefore(existing)) {
      times[stage] = e.occurredAt;
    }
  }
  return times;
}

/// Builds the timeline for [state]. Returns an empty list when there is no
/// pickup to track.
List<TrackingStep> buildTimeline(PickupTrackingState state) {
  if (state.phase == PickupPhase.none) return const [];

  final verified = _verifiedStageTimes(state.verifiedEvents);

  TrackingStep collectorStage(
    TrackingStageId id,
    String title,
    IconData icon,
    String verifiedText,
    String pendingText,
  ) {
    final time = verified[id];
    if (time != null) {
      return TrackingStep(
        id: id,
        title: title,
        description: verifiedText,
        icon: icon,
        status: StageStatus.done,
        time: time,
      );
    }
    return TrackingStep(
      id: id,
      title: title,
      description: state.collectorEventsSupported ? pendingText : _notReportedText,
      icon: icon,
      status: state.collectorEventsSupported
          ? StageStatus.upcoming
          : StageStatus.notReported,
    );
  }

  final steps = <TrackingStep>[
    TrackingStep(
      id: TrackingStageId.requested,
      title: 'Pickup Requested',
      description: 'You scheduled a pickup from the app.',
      icon: Icons.edit_calendar_rounded,
      status: StageStatus.done,
      time: state.requestedAt,
    ),
    TrackingStep(
      id: TrackingStageId.confirmed,
      title: 'Request Confirmed',
      description: 'The EcoTrack server has your request on record.',
      icon: Icons.verified_rounded,
      status: StageStatus.done,
      time: state.requestedAt,
    ),
    collectorStage(
      TrackingStageId.collectorAssigned,
      'Collector Assigned',
      Icons.badge_rounded,
      'A collector has been assigned to your pickup.',
      'Appears once EcoTrack assigns a collector.',
    ),
    collectorStage(
      TrackingStageId.collectorEnRoute,
      'Collector En Route',
      Icons.local_shipping_rounded,
      'EcoTrack verified the collector is approaching your pickup point.',
      'Appears once the collector is approaching.',
    ),
    collectorStage(
      TrackingStageId.arrived,
      'Pickup Arrived',
      Icons.place_rounded,
      "EcoTrack verified the collector's arrival at your pickup point.",
      'Appears once the collector arrives.',
    ),
  ];

  final collectedTime = verified[TrackingStageId.wasteCollected];

  switch (state.phase) {
    case PickupPhase.active:
      steps.addAll([
        collectedTime != null
            ? TrackingStep(
                id: TrackingStageId.wasteCollected,
                title: 'Waste Collected',
                description: 'The collector recorded the collection. '
                    'Confirm it below to close the pickup.',
                icon: Icons.recycling_rounded,
                status: StageStatus.done,
                time: collectedTime,
              )
            : const TrackingStep(
                id: TrackingStageId.wasteCollected,
                title: 'Waste Collected',
                description: 'Confirm with “Picked up” once the collector has '
                    'taken your waste.',
                icon: Icons.recycling_rounded,
                status: StageStatus.upcoming,
              ),
        const TrackingStep(
          id: TrackingStageId.completed,
          title: 'Pickup Completed',
          description: 'The server records the pickup as completed.',
          icon: Icons.task_alt_rounded,
          status: StageStatus.upcoming,
        ),
      ]);
      // The latest confirmed stage is where the pickup is now.
      final lastDone = steps.lastIndexWhere((s) => s.status == StageStatus.done);
      final current = steps[lastDone];
      steps[lastDone] = current.withStatus(
        StageStatus.current,
        description: current.id == TrackingStageId.confirmed
            ? 'The EcoTrack server has your request on record and it is '
                'awaiting collection. Once your waste has been collected, '
                'confirm it below.'
            : null,
      );
    case PickupPhase.completed:
      steps.addAll([
        TrackingStep(
          id: TrackingStageId.wasteCollected,
          title: 'Waste Collected',
          description: collectedTime != null
              ? 'The collector recorded the collection.'
              : 'You confirmed the collector took your waste.',
          icon: Icons.recycling_rounded,
          status: StageStatus.done,
          time: collectedTime ?? state.resolvedAt,
        ),
        TrackingStep(
          id: TrackingStageId.completed,
          title: 'Pickup Completed',
          description: 'The server recorded this pickup as completed.',
          icon: Icons.task_alt_rounded,
          status: StageStatus.current,
          time: state.resolvedAt,
        ),
      ]);
    case PickupPhase.notCollected:
      steps.add(TrackingStep(
        id: TrackingStageId.notCollected,
        title: 'Not Collected',
        description: 'You reported that the waste was not picked up. '
            'You can schedule a new pickup.',
        icon: Icons.report_gmailerrorred_rounded,
        status: StageStatus.current,
        time: state.resolvedAt,
        isNegative: true,
      ));
    case PickupPhase.closed:
      steps.add(TrackingStep(
        id: TrackingStageId.closed,
        title: 'No Longer Active',
        description: 'The server no longer lists this pickup as active. Its '
            'final outcome was not reported to the app, so it is not shown '
            'as completed.',
        icon: Icons.inventory_2_outlined,
        status: StageStatus.current,
        time: state.resolvedAt,
      ));
    case PickupPhase.none:
      break;
  }
  return steps;
}

/// The step the pickup is currently at (the one marked [StageStatus.current]).
TrackingStep? currentStep(List<TrackingStep> steps) {
  for (final s in steps) {
    if (s.status == StageStatus.current) return s;
  }
  return null;
}

/// The next step that will actually be confirmed (skips not-reported ones).
TrackingStep? nextTrackableStep(List<TrackingStep> steps) {
  for (final s in steps) {
    if (s.status == StageStatus.upcoming) return s;
  }
  return null;
}

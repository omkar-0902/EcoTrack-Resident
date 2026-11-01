import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../tracking/data/pickup_tracking_controller.dart';

export '../../tracking/data/pickup_tracking_controller.dart'
    show pickupTrackingProvider, PickupTrackingController;

/// Whether the resident currently has an active pickup.
///
/// Read-only and derived from [pickupTrackingProvider], which is the single
/// source of truth. (Previously this was a separately writable flag that
/// screens set independently, so it could disagree with the backend.)
final pickupActiveProvider = Provider<bool>(
  (ref) => ref.watch(pickupTrackingProvider.select((s) => s.isActive)),
);

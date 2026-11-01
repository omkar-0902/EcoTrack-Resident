import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/config/api_config.dart';
import '../../../core/haptics.dart';
import '../data/pickup_tracking_controller.dart';
import '../domain/pickup_format.dart';
import '../domain/pickup_tracking_state.dart';
import '../domain/tracking_timeline.dart';
import 'pickup_outcome_buttons.dart';

/// Delivery-style tracking for one pickup request.
///
/// Opened with the pickup id as the route argument (`/track`), so every entry
/// point shows exactly the request it was opened for. While open and in the
/// foreground it polls the backend every [ApiConfig.trackingPollInterval];
/// polling stops when the screen is closed, the app is backgrounded, or the
/// pickup is no longer active.
class TrackingView extends ConsumerStatefulWidget {
  /// Pickup to show. When null, the current route argument is used.
  final String? pickupId;

  const TrackingView({super.key, this.pickupId});

  @override
  ConsumerState<TrackingView> createState() => _TrackingViewState();
}

class _TrackingViewState extends ConsumerState<TrackingView> {
  Timer? _pollTimer;
  AppLifecycleListener? _lifecycle;
  bool _inForeground = true;
  String? _pickupId;
  bool _resolvedArgs = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () {
        _inForeground = true;
        _refresh();
        _updatePolling();
      },
      onHide: () {
        _inForeground = false;
        _updatePolling();
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refresh();
      _updatePolling();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_resolvedArgs) {
      _resolvedArgs = true;
      final arg = ModalRoute.of(context)?.settings.arguments;
      _pickupId = widget.pickupId ?? (arg is String ? arg : null);
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _lifecycle?.dispose();
    super.dispose();
  }

  Future<void> _refresh() => ref.read(pickupTrackingProvider.notifier).sync();

  /// Polls only while: screen open, app in foreground, and the pickup shown
  /// here is the active one.
  void _updatePolling() {
    final s = ref.read(pickupTrackingProvider);
    final shouldPoll =
        mounted && _inForeground && s.isActive && s.describes(_id(s));
    if (shouldPoll && _pollTimer == null) {
      _pollTimer = Timer.periodic(
        ApiConfig.trackingPollInterval,
        (_) => _refresh(),
      );
    } else if (!shouldPoll) {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  /// The pickup id this screen is for. Without an explicit id, the current
  /// pickup is shown.
  String? _id(PickupTrackingState s) => _pickupId ?? s.pickupId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final state = ref.watch(pickupTrackingProvider);
    final id = _id(state);

    ref.listen(pickupTrackingProvider.select((s) => s.phase), (_, _) {
      _updatePolling();
    });

    final Widget body;
    Widget? bottom;
    if (state.describes(id)) {
      final steps = buildTimeline(state);
      body = _TrackingContent(state: state, steps: steps, onRefresh: _refresh);
      if (state.isActive) {
        bottom = const PickupOutcomeButtons();
      } else {
        bottom = ElevatedButton(
          onPressed: () {
            AppHaptics.lightImpact();
            Navigator.maybePop(context);
          },
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 60),
          ),
          child: const Text("DONE"),
        );
      }
    } else if (state.lastSyncedAt == null && state.syncError == null) {
      // First check has not finished yet.
      body = const Center(child: CircularProgressIndicator());
    } else {
      body = _UnavailableView(
        pickupId: id,
        errorMessage: state.syncError,
        onRetry: _refresh,
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "TRACK PICKUP",
          style: GoogleFonts.spaceGrotesk(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            color: cs.primary,
          ),
        ),
      ),
      body: body,
      bottomNavigationBar: bottom == null
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: bottom,
            ),
    );
  }
}

class _TrackingContent extends StatelessWidget {
  final PickupTrackingState state;
  final List<TrackingStep> steps;
  final Future<void> Function() onRefresh;

  const _TrackingContent({
    required this.state,
    required this.steps,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final current = currentStep(steps);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        children: [
          if (state.syncError != null) ...[
            _ConnectionBanner(state: state, onRetry: onRefresh),
            const SizedBox(height: 16),
          ],
          _StatusHeader(state: state, current: current),
          const SizedBox(height: 32),
          const _SectionLabel("TRACKING"),
          const SizedBox(height: 16),
          for (var i = 0; i < steps.length; i++)
            _TimelineRow(
              step: steps[i],
              isLast: i == steps.length - 1,
              animateCurrent: state.isActive,
            ),
          const SizedBox(height: 24),
          const _SectionLabel("PICKUP DETAILS"),
          const SizedBox(height: 16),
          _DetailsCard(state: state, current: current),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.spaceGrotesk(
        fontSize: 10,
        fontWeight: FontWeight.bold,
        letterSpacing: 2,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// Prominent summary of where the pickup is now. Cross-fades when it changes.
class _StatusHeader extends StatelessWidget {
  final PickupTrackingState state;
  final TrackingStep? current;

  const _StatusHeader({required this.state, required this.current});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = (current?.isNegative ?? false) ? cs.error : cs.primary;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        switchInCurve: Curves.easeOutCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SizeTransition(sizeFactor: animation, child: child),
        ),
        child: Column(
          key: ValueKey(current?.id),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    "CURRENT STATUS",
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
                if (state.isSyncing)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: cs.primary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    current?.title ?? "Unknown",
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                      height: 1.1,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: accent, width: 2),
                  ),
                  child: Icon(
                    current?.icon ?? Icons.help_outline,
                    color: accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              current?.description ?? "",
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.5,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final TrackingStep step;
  final bool isLast;
  final bool animateCurrent;

  const _TimelineRow({
    required this.step,
    required this.isLast,
    required this.animateCurrent,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = step.isNegative ? cs.error : cs.primary;
    final isDone = step.status == StageStatus.done;
    final isCurrent = step.status == StageStatus.current;
    final isNotReported = step.status == StageStatus.notReported;

    final titleColor = (isDone || isCurrent)
        ? cs.onSurface
        : cs.onSurfaceVariant.withValues(alpha: isNotReported ? 0.55 : 0.8);

    return Semantics(
      label: '${step.title}: ${_statusLabel(step.status)}',
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 44,
              child: Column(
                children: [
                  _StepDot(
                    step: step,
                    accent: accent,
                    pulse: isCurrent && animateCurrent,
                  ),
                  if (!isLast)
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: isDone
                              ? accent
                              : cs.outlineVariant.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 20, top: 4),
                // Every non-last row is tall enough to leave a visible
                // connector below its dot (short rows used to hide it).
                constraints: BoxConstraints(minHeight: isLast ? 0 : 76),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            step.title,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: isCurrent ? 17 : 15,
                              fontWeight: FontWeight.bold,
                              color: isCurrent ? accent : titleColor,
                            ),
                          ),
                        ),
                        if (step.time != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            formatEventTime(step.time!),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (isNotReported) ...[
                      const SizedBox(height: 6),
                      _Tag(text: "NOT REPORTED", color: cs.onSurfaceVariant),
                    ],
                    if (isCurrent ||
                        isNotReported ||
                        step.status == StageStatus.upcoming) ...[
                      const SizedBox(height: 6),
                      Text(
                        isCurrent ? _shortCurrentText(step) : step.description,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          height: 1.4,
                          color: cs.onSurfaceVariant.withValues(
                            alpha: isNotReported ? 0.6 : 0.9,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The header already shows the long explanation; keep the row brief.
  String _shortCurrentText(TrackingStep step) => switch (step.id) {
    TrackingStageId.confirmed => 'Awaiting collection.',
    TrackingStageId.completed => 'Done.',
    _ => step.description,
  };

  static String _statusLabel(StageStatus s) => switch (s) {
    StageStatus.done => 'completed',
    StageStatus.current => 'current',
    StageStatus.upcoming => 'upcoming',
    StageStatus.notReported => 'not reported by the server',
  };
}

class _StepDot extends StatefulWidget {
  final TrackingStep step;
  final Color accent;
  final bool pulse;

  const _StepDot({
    required this.step,
    required this.accent,
    required this.pulse,
  });

  @override
  State<_StepDot> createState() => _StepDotState();
}

class _StepDotState extends State<_StepDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void initState() {
    super.initState();
    if (widget.pulse) _pulse.repeat();
  }

  @override
  void didUpdateWidget(covariant _StepDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulse && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (!widget.pulse && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final status = widget.step.status;
    final accent = widget.accent;

    final double size = switch (status) {
      StageStatus.current => 36,
      StageStatus.done => 28,
      _ => 24,
    };
    final Color fill = switch (status) {
      StageStatus.current || StageStatus.done => accent,
      _ => Colors.transparent,
    };
    final Color border = switch (status) {
      StageStatus.current || StageStatus.done => accent,
      StageStatus.upcoming => cs.outlineVariant,
      StageStatus.notReported => cs.outlineVariant.withValues(alpha: 0.5),
    };
    final Widget icon = switch (status) {
      StageStatus.done => Icon(
        Icons.check_rounded,
        size: 16,
        color: cs.onPrimary,
      ),
      StageStatus.current => Icon(
        widget.step.icon,
        size: 18,
        color: cs.onPrimary,
      ),
      StageStatus.upcoming => Icon(
        widget.step.icon,
        size: 12,
        color: cs.onSurfaceVariant,
      ),
      StageStatus.notReported => Icon(
        Icons.more_horiz,
        size: 12,
        color: cs.onSurfaceVariant.withValues(alpha: 0.5),
      ),
    };

    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.pulse)
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) => Container(
                width: size + 16 * _pulse.value,
                height: size + 16 * _pulse.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.25 * (1 - _pulse.value)),
                ),
              ),
            ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fill,
              border: Border.all(color: border, width: 2),
              boxShadow: status == StageStatus.current
                  ? [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.35),
                        blurRadius: 14,
                      ),
                    ]
                  : null,
            ),
            child: Center(child: icon),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;

  const _Tag({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: GoogleFonts.spaceGrotesk(
          fontSize: 8,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
          color: color.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  final PickupTrackingState state;
  final TrackingStep? current;

  const _DetailsCard({required this.state, required this.current});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final scheduled = state.requestDate == null
        ? null
        : '${DateFormat('EEE, MMM d').format(state.requestDate!)} · $kCollectionWindow';

    final String? lastUpdated;
    if (state.isSyncing && state.lastSyncedAt == null) {
      lastUpdated = 'Checking…';
    } else if (state.lastSyncedAt != null) {
      lastUpdated = 'Checked at ${formatClockTime(state.lastSyncedAt!)}';
    } else {
      lastUpdated = null;
    }

    final loc = state.pickupLocation;
    final acc = state.pickupLocationAccuracyMeters;
    final location = loc == null
        ? null
        : '${loc.latitude.toStringAsFixed(5)}, ${loc.longitude.toStringAsFixed(5)}'
            '${acc == null ? '' : ' · ±${acc.round()} m'}';

    final rows = <(String, String?, String)>[
      ('REQUEST ID', '#${state.pickupId}', ''),
      ('STATUS', current?.title, 'Unknown'),
      ('SCHEDULED', scheduled, 'Not available on this device'),
      ('PICKUP LOCATION', location, 'Not available on this device'),
      ('PICKUP TYPE', null, 'Not provided by server'),
      ('COLLECTOR', null, 'Not provided by server'),
      ('ESTIMATED ARRIVAL', null, 'Not available'),
      ('LAST UPDATED', lastUpdated, 'Not checked yet'),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                color: cs.outlineVariant.withValues(alpha: 0.3),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(
                      rows[i].$1,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      rows[i].$2 ?? rows[i].$3,
                      textAlign: TextAlign.right,
                      style: rows[i].$2 != null
                          ? GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface,
                            )
                          : GoogleFonts.inter(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Shown when the backend could not be reached; the last known state stays
/// visible underneath.
class _ConnectionBanner extends StatelessWidget {
  final PickupTrackingState state;
  final Future<void> Function() onRetry;

  const _ConnectionBanner({required this.state, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final since = state.lastSyncedAt == null
        ? ''
        : ' Showing the last known status from ${formatClockTime(state.lastSyncedAt!)}.';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: cs.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_outlined, size: 20, color: cs.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Couldn't refresh.$since",
              style: GoogleFonts.inter(fontSize: 12, color: cs.onSurface),
            ),
          ),
          TextButton(
            onPressed: state.isSyncing ? null : onRetry,
            child: const Text("RETRY"),
          ),
        ],
      ),
    );
  }
}

/// The selected request is not the one the backend can report on.
class _UnavailableView extends StatelessWidget {
  final String? pickupId;
  final String? errorMessage;
  final Future<void> Function() onRetry;

  const _UnavailableView({
    required this.pickupId,
    required this.errorMessage,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = errorMessage != null
        ? "Couldn't load tracking"
        : "Tracking unavailable";
    final message =
        errorMessage ??
        (pickupId == null
            ? "You don't have an active pickup right now."
            : "Live status is only available for your current active pickup. "
                  "The EcoTrack server does not provide tracking details for "
                  "request #$pickupId.");

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.travel_explore_rounded,
              size: 48,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: onRetry, child: const Text("RETRY")),
          ],
        ),
      ),
    );
  }
}

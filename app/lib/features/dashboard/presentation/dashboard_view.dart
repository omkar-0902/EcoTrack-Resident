import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/services/auth_service.dart';
import '../../../core/haptics.dart';
import '../../../core/session.dart';
import '../../profile/data/profile_provider.dart';
import '../../schedule/data/pickup_provider.dart';
import '../../tracking/domain/pickup_format.dart';
import '../../tracking/domain/pickup_tracking_state.dart';
import '../../tracking/domain/tracking_timeline.dart';
import '../../../core/app_theme.dart';
import '../../../shared/widgets/resident_app_bar.dart';

class DashboardView extends ConsumerStatefulWidget {
  const DashboardView({super.key});

  @override
  ConsumerState<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends ConsumerState<DashboardView> {
  bool _started = false;
  String userName = "";
  AppLifecycleListener? _lifecycle;

  @override
  void initState() {
    super.initState();
    // Re-check the pickup when the resident comes back to the app, so Home
    // reflects changes made on the server while the app was in the background.
    _lifecycle = AppLifecycleListener(onResume: _syncActivePickup);
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // didChangeDependencies also runs on theme / MediaQuery changes (e.g. the
    // keyboard opening). Load only once instead of re-hitting the API each time.
    if (!_started) {
      _started = true;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is String && args.isNotEmpty) userName = args;
      _loadSession();
    }
  }

  Future<void> _loadSession() async {
    final token = await AuthService.getToken();
    if (!mounted) return;

    // No session: userProfileProvider fails with 401 and the listener in
    // build() signs out and routes to /login. Navigating here as well would
    // race with it.
    if (token == null) return;

    if (userName.isEmpty) {
      final fromToken = await AuthService.getUsernameFromToken();
      if (!mounted) return;
      setState(() => userName = fromToken ?? "User");
    }

    await _syncActivePickup();
  }

  /// Makes the backend the source of truth for the active pickup (see
  /// [PickupTrackingController.sync]).
  Future<void> _syncActivePickup() async {
    if (!mounted) return;
    await ref.read(pickupTrackingProvider.notifier).sync();
  }

  Future<void> _retry() async {
    ref.invalidate(userProfileProvider);
    await _syncActivePickup();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final pickup = ref.watch(pickupTrackingProvider);

    ref.listen(userProfileProvider, (previous, next) {
      final error = next.error;
      if (error is ProfileLoadException && error.isUnauthorized) {
        // Session expired or was revoked on the server.
        signOut(context);
      }
    });

    if (profileAsync.isLoading && !profileAsync.hasValue) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (profileAsync.hasError && !profileAsync.hasValue) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: _LoadErrorView(
          message: profileAsync.error.toString(),
          onRetry: _retry,
        ),
      );
    }

    final profile = profileAsync.requireValue;
    final ecoPoints = profile.ecoPoints;
    final lastPickupDate = profile.lastPickupDate;
    final displayName = userName.isNotEmpty
        ? userName
        : (profile.userName.isNotEmpty ? profile.userName : "User");

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: ResidentAppBar(
        showAvatarOnLeft: true,
        title: displayName.toUpperCase(),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () {
              AppHaptics.lightImpact();
              Navigator.pushNamed(context, '/notifications');
            },
            icon: Stack(
              children: [
                const Icon(Icons.notifications_outlined, color: Colors.white),
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryNeon,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            pickup.isActive
                ? _ActivePickupCard(state: pickup)
                : const _NoActivityCard(),

            const SizedBox(height: 32),

            _PointsCard(ecoPoints: ecoPoints),

            const SizedBox(height: 16),

            _LastRequestCard(date: lastPickupDate),

            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }
}

class _PointsCard extends StatelessWidget {
  final int ecoPoints;

  const _PointsCard({required this.ecoPoints});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "ECO POINTS",
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  color: cs.onSurfaceVariant,
                ),
              ),
              Icon(Icons.military_tech, color: cs.primary),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "$ecoPoints",
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 4),
                child: Icon(Icons.bolt, color: cs.primary, size: 24),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ecoPoints / 100,
              backgroundColor: cs.surfaceContainerHighest,
              color: cs.primary,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "$ecoPoints pts earned",
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: cs.onSurfaceVariant,
                ),
              ),
              Text(
                "TOTAL $ecoPoints",
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: cs.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LastRequestCard extends StatelessWidget {
  final String date;

  const _LastRequestCard({required this.date});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "MY LAST REQUEST",
            style: GoogleFonts.spaceGrotesk(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.recycling, color: cs.primary, size: 32),
              ),
              const SizedBox(width: 16),
              // Expanded so long dates / large system font sizes wrap instead
              // of overflowing the card.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      date.isEmpty ? "No completed pickups yet" : "Collected on $date",
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface,
                      ),
                    ),
                    if (date.isNotEmpty)
                      Text(
                        "Completed",
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NoActivityCard extends StatelessWidget {
  const _NoActivityCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.eco_outlined, size: 48, color: cs.primary),
          ),
          const SizedBox(height: 24),
          Text(
            "NO ACTIVE ACTIVITY",
            style: GoogleFonts.spaceGrotesk(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Your ecosystem is currently at rest. Schedule a new pickup to start tracking.",
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 14, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Summary of the real active pickup (replaces a hard-coded "Collector is on
/// the way / En Route" card that never reflected the actual request).
class _ActivePickupCard extends StatelessWidget {
  final PickupTrackingState state;

  const _ActivePickupCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final steps = buildTimeline(state);
    final current = currentStep(steps);

    final String nextText;
    if (state.requestDate != null) {
      nextText = "Next: collection ${relativePickupDay(state.requestDate!)}, "
          "$kCollectionWindow";
    } else {
      final next = nextTrackableStep(steps);
      nextText = next == null ? "" : "Next: ${next.title.toLowerCase()}";
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "CURRENT STATUS",
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        current?.title ?? "Pickup active",
                        key: ValueKey(current?.id),
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: cs.primary, width: 2),
                ),
                child: Icon(current?.icon ?? Icons.local_shipping, color: cs.primary),
              ),
            ],
          ),
          if (nextText.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              nextText,
              style: GoogleFonts.inter(fontSize: 14, color: cs.onSurfaceVariant),
            ),
          ],
          if (state.syncError != null) ...[
            const SizedBox(height: 8),
            Text(
              "Couldn't refresh. Showing last known status.",
              style: GoogleFonts.inter(fontSize: 12, color: cs.error),
            ),
          ],
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              AppHaptics.mediumImpact();
              Navigator.pushNamed(context, '/track', arguments: state.pickupId);
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
            ),
            icon: const Icon(Icons.route_rounded),
            label: const Text("TRACK PICKUP"),
          ),
        ],
      ),
    );
  }
}

class _LoadErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _LoadErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 48, color: cs.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 14, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                AppHaptics.lightImpact();
                onRetry();
              },
              child: const Text("RETRY"),
            ),
          ],
        ),
      ),
    );
  }
}

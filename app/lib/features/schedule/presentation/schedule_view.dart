import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/haptics.dart';
import '../../../core/app_theme.dart';
import '../../../shared/widgets/resident_app_bar.dart';
import '../data/pickup_provider.dart';
import '../../../services/auth_service.dart';
import '../../../services/location_service.dart';
import '../../../shared/widgets/ghost_button.dart';
import '../../tracking/domain/pickup_format.dart';
import '../../tracking/presentation/pickup_outcome_buttons.dart';

class ScheduleView extends ConsumerStatefulWidget {
  const ScheduleView({super.key});

  @override
  ConsumerState<ScheduleView> createState() => _ScheduleViewState();
}

class _ScheduleViewState extends ConsumerState<ScheduleView> {
  int selectedIndex = 0;
  late List<Map<String, dynamic>> days;

  /// True while a create request is in flight. Disables the button so a slow
  /// network cannot cause duplicate submissions.
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _generateDays();
  }

  void _generateDays() {
    final now = DateTime.now();
    days = List.generate(5, (index) {
      final date = now.add(Duration(days: index));
      return {
        'day': DateFormat('E').format(date),
        'date': DateFormat('d').format(date),
        'fullDate': date,
      };
    });
  }

  void _showMessage(String message, {SnackBarAction? action}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), action: action));
  }

  /// Explains why the location could not be used, with a shortcut to the
  /// relevant system settings where that is the fix.
  void _showLocationIssue(LocationOutcome outcome) {
    final issue = outcome.issue!;
    final service = ref.read(locationServiceProvider);
    final fixableInSettings = issue == LocationIssue.serviceDisabled ||
        issue == LocationIssue.permissionDeniedForever;
    _showMessage(
      describeLocationIssue(issue, accuracyMeters: outcome.fix?.accuracyMeters),
      action: fixableInSettings
          ? SnackBarAction(
              label: 'SETTINGS',
              onPressed: () => service.openSettingsFor(issue),
            )
          : null,
    );
  }

  Future<void> _confirmRequest() async {
    if (_isSubmitting) return;
    AppHaptics.success();
    setState(() => _isSubmitting = true);

    try {
      final token = await AuthService.getToken();
      if (token == null) {
        _showMessage("Your session has ended. Please sign in again.");
        return;
      }

      final selectedDate = days[selectedIndex]['fullDate'] as DateTime;

      // The pickup location is the resident's current position, read once
      // (foreground only) at the moment of scheduling.
      final outcome = await ref.read(locationServiceProvider).getCurrentFix();
      if (!mounted) return;
      if (!outcome.isSuccess) {
        _showLocationIssue(outcome);
        return;
      }

      final result = await ref.read(pickupTrackingProvider.notifier).create(
            requestDate: selectedDate,
            location: outcome.fix!,
          );
      if (!mounted) return;

      if (!result.isSuccess) {
        _showMessage(result.errorMessage);
      }
      // On success the controller marks the pickup active and this screen
      // switches to the confirmation view.
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isScheduled = ref.watch(pickupActiveProvider);

    // Back is never blocked here. The active pickup stays visible on Home and
    // in the tracking screen.
    return Scaffold(
      extendBodyBehindAppBar: isScheduled,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: ResidentAppBar(
        showAvatarOnLeft: false,
        leading: null,
      ),
      body: isScheduled ? _buildActiveRequestView(cs) : _buildSchedulingForm(cs),
    );
  }

  Widget _buildSchedulingForm(ColorScheme cs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Schedule a Pickup",
            style: GoogleFonts.spaceGrotesk(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Confirm your next automated municipal collection.",
            style: GoogleFonts.inter(fontSize: 14, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 48),

          Text(
            "SELECT PICKUP DATE",
            style: GoogleFonts.spaceGrotesk(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),

          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: days.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final isSelected = selectedIndex == index;
                return GestureDetector(
                  onTap: () {
                    AppHaptics.selectionClick();
                    setState(() => selectedIndex = index);
                  },
                  child: Container(
                    width: 72,
                    decoration: BoxDecoration(
                      color: isSelected ? cs.primary : cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(20),
                      border: isSelected
                          ? null
                          : Border.all(
                              color: cs.outlineVariant.withValues(alpha: 0.2),
                            ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: cs.primary.withValues(alpha: 0.3),
                                blurRadius: 15,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          days[index]['day'].toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? cs.onPrimary
                                : cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          days[index]['date'],
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? cs.onPrimary : cs.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 48),

          ElevatedButton(
            onPressed: _isSubmitting ? null : _confirmRequest,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 64),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text("CONFIRM REQUEST"),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveRequestView(ColorScheme cs) {
    // Use the date the pickup was actually requested for (single source of
    // truth). Unknown when the pickup was restored from the backend, whose
    // response does not include the date.
    final pickup = ref.watch(pickupTrackingProvider);
    final selectedDate = pickup.requestDate;
    final relativeDate = selectedDate == null
        ? "on your scheduled date"
        : relativePickupDay(selectedDate);

    return Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.surfaceBase,
              const Color(0xFF031A12),
              const Color(0xFF010E0A),
            ],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background "Forest" feel
            Positioned.fill(
              child: Opacity(
                opacity: 0.1,
                child: Image.network(
                  "https://images.unsplash.com/photo-1441974231531-c6227db76b6e?q=80&w=2560&auto=format&fit=crop",
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(),
                ),
              ),
            ),
            
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 10),
                  
                  // Success Indicator
                  Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.primaryNeon.withValues(alpha: 0.05),
                            border: Border.all(
                              color: AppTheme.primaryNeon.withValues(alpha: 0.1),
                              width: 1,
                            ),
                          ),
                        ),
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.primaryNeon.withValues(alpha: 0.1),
                          ),
                        ),
                        Container(
                          width: 85,
                          height: 85,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.primaryNeon,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryNeon,
                                blurRadius: 25,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.check_rounded, size: 50, color: AppTheme.onPrimary),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 40),

                  Text(
                    "Pickup Requested\nSuccessfully!",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.1,
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: AppTheme.onSurfaceVariant.withValues(alpha: 0.8),
                      ),
                      children: [
                        TextSpan(text: "Your collector will arrive $relativeDate between "),
                        TextSpan(
                          text: kCollectionWindow,
                          style: const TextStyle(
                            color: AppTheme.primaryNeon,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),

                  // Entry point: confirmation -> tracking for this request.
                  GhostButton(
                    text: "TRACK PICKUP",
                    fullWidth: true,
                    onPressed: () => Navigator.pushNamed(
                      context,
                      '/track',
                      arguments: pickup.pickupId,
                    ),
                  ),

                  // Room for the pinned outcome buttons.
                  const SizedBox(height: 140),
                ],
              ),
            ),

            // Action buttons pinned to the bottom, above the system
            // navigation area (gesture bar or 3-button bar).
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: const PickupOutcomeButtons(),
              ),
            ),
          ],
        ),
      );
  }
}

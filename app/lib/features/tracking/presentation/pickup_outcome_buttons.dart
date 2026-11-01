import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/app_theme.dart';
import '../../../core/haptics.dart';
import '../../../models/pickup.dart';
import '../data/pickup_tracking_controller.dart';

/// "NOT PICKED UP" / "PICKED UP" actions for the active pickup.
///
/// These are the only way the current backend contract moves a pickup to a
/// final status (`PUT /pickups/status`). Shared by the confirmation view and
/// the tracking screen so both behave identically.
class PickupOutcomeButtons extends ConsumerStatefulWidget {
  const PickupOutcomeButtons({super.key});

  @override
  ConsumerState<PickupOutcomeButtons> createState() =>
      _PickupOutcomeButtonsState();
}

class _PickupOutcomeButtonsState extends ConsumerState<PickupOutcomeButtons> {
  bool _isSubmitting = false;

  Future<void> _resolve(String status, {int? points}) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    final result = await ref
        .read(pickupTrackingProvider.notifier)
        .resolve(status, points: points);

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (!result.isSuccess) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(result.errorMessage)));
      // Keep the lock in place — outcome was not recorded.
      return;
    }

    // The controller has already set the phase to completed / notCollected,
    // which flips PopScope.canPop to true. Pop now to return the user to the
    // previous screen (Home or wherever they navigated from).
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isSubmitting
                ? null
                : () {
                    AppHaptics.lightImpact();
                    _resolve(PickupStatus.failed);
                  },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFFF5252), width: 1),
              minimumSize: const Size(double.infinity, 60),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              "NOT PICKED UP",
              style: GoogleFonts.spaceGrotesk(
                color: const Color(0xFFFF5252),
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _isSubmitting
                ? null
                : () {
                    AppHaptics.success();
                    // Existing business rule: 10 points on completion.
                    _resolve(PickupStatus.completed, points: 10);
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryNeon,
              foregroundColor: AppTheme.onPrimary,
              minimumSize: const Size(double.infinity, 60),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    "PICKED UP",
                    style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

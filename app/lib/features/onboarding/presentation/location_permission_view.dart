import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/haptics.dart';
import '../../../services/location_service.dart';

class LocationPermissionView extends ConsumerStatefulWidget {
  const LocationPermissionView({super.key});

  @override
  ConsumerState<LocationPermissionView> createState() =>
      _LocationPermissionViewState();
}

class _LocationPermissionViewState extends ConsumerState<LocationPermissionView>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  bool _isRequesting = false;

  void _showMessage(String message, {SnackBarAction? action}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), action: action),
    );
  }

  /// Asks for "while using the app" location permission (never background).
  /// Returns true when the user can move on; false when they must act first
  /// (feedback is shown). The position itself is only read later, when a
  /// pickup is scheduled.
  Future<bool> _requestLocationAccess() async {
    final service = ref.read(locationServiceProvider);
    final issue = await service.ensurePermission();
    switch (issue) {
      case null:
        return true;
      case LocationIssue.permissionDeniedForever:
        _showMessage(describeLocationIssue(issue));
        await service.openSettingsFor(issue);
        return false;
      case LocationIssue.serviceDisabled:
        _showMessage(
          describeLocationIssue(issue),
          action: SnackBarAction(
            label: 'SETTINGS',
            onPressed: () => service.openSettingsFor(issue),
          ),
        );
        return false;
      case LocationIssue.permissionDenied:
        _showMessage("Location permission denied");
        return false;
      case LocationIssue.unavailable:
      case LocationIssue.inaccurate:
        // Permission state could not be read right now; not a reason to
        // block onboarding (location is checked again when scheduling).
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          Positioned(
            top: -50,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.primary.withValues(alpha: 0.03),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                children: [
                  const Spacer(),

                  Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        ScaleTransition(
                          scale: _pulseAnimation,
                          child: Container(
                            width: 160,
                            height: 160,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: cs.primary.withValues(alpha: 0.05),
                            ),
                          ),
                        ),
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: cs.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.location_on,
                            size: 48,
                            color: cs.onPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 60),

                  Text(
                    "ALLOW LOCATION ACCESS",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 16),

                  Text(
                    "We use your location to match you with the nearest collector and send accurate proximity alerts.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 16),
                  ),

                  const Spacer(),

                  ElevatedButton(
                    onPressed: _isRequesting
                        ? null
                        : () async {
                            AppHaptics.mediumImpact();
                            setState(() => _isRequesting = true);

                            final granted = await _requestLocationAccess();

                            if (!context.mounted) return;
                            setState(() => _isRequesting = false);

                            if (granted) {
                              Navigator.pushReplacementNamed(context, '/login');
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 64),
                    ),
                    child: _isRequesting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text("ALLOW LOCATION"),
                  ),

                  const SizedBox(height: 16),

                  TextButton(
                    onPressed: () {
                      AppHaptics.lightImpact();
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                    child: Text(
                      "MAYBE LATER",
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Text(
                    "SECURE 256-BIT ENCRYPTED GEO-DATA",
                    style: GoogleFonts.spaceGrotesk(fontSize: 8),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

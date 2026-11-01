import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/haptics.dart';
import '../../../core/session.dart';
import '../../../shared/widgets/resident_app_bar.dart';
import '../../../shared/widgets/animated_theme_toggler.dart';
import '../../../services/auth_service.dart';
import '../data/profile_provider.dart';

class ProfileView extends ConsumerStatefulWidget {
  const ProfileView({super.key});

  @override
  ConsumerState<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends ConsumerState<ProfileView> {
  /// Fallback name from the JWT, shown if the profile cannot be loaded.
  String? _tokenUserName;
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    AuthService.getUsernameFromToken().then((name) {
      if (mounted) setState(() => _tokenUserName = name);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final profileAsync = ref.watch(userProfileProvider);
    final profile = profileAsync.asData?.value;

    final String userName;
    if (profile != null && profile.userName.isNotEmpty) {
      userName = profile.userName;
    } else if (profileAsync.isLoading && profile == null) {
      userName = "Loading...";
    } else {
      userName = _tokenUserName ?? "Resident";
    }
    final ecoPoints = profile?.ecoPoints.toString() ?? "0";
    final totalPickups = profile?.totalPickups.toString() ?? "0";
    final lastPickupDate = (profile == null || profile.lastPickupDate.isEmpty)
        ? "—"
        : profile.lastPickupDate;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: ResidentAppBar(
        showAvatarOnLeft: false,
        actions: [
          const AnimatedThemeToggler(),
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.white),
            onPressed: () {
              AppHaptics.lightImpact();
              Navigator.pushNamed(context, '/notifications');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Profile Header
            Center(
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: cs.primary.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 56,
                          backgroundColor: cs.surfaceContainer,
                          child: Icon(
                            Icons.person,
                            size: 64,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () => AppHaptics.mediumImpact(),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: cs.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.edit,
                              size: 20,
                              color: cs.onPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Text(
                    userName,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),

                  Text(
                    "resident@zone4b",
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: cs.onSurfaceVariant,
                    ),
                  ),

                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      "ZONE 4B RESIDENT",
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        color: cs.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 48),

            // Stats Bento Grid
            Row(
              children: [
                _StatCard(label: "Total Pickups", value: totalPickups),
                const SizedBox(width: 12),
                _StatCard(label: "EcoPoints", value: ecoPoints),
                const SizedBox(width: 12),
                _StatCard(label: "Last", value: lastPickupDate),
              ],
            ),

            const SizedBox(height: 48),

            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "ACCOUNT PREFERENCES",
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),

            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _isLoggingOut
                  ? null
                  : () async {
                      AppHaptics.mediumImpact();
                      setState(() => _isLoggingOut = true);
                      await signOut(context);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.error.withValues(alpha: 0.1),
                foregroundColor: Theme.of(context).colorScheme.error,
                minimumSize: const Size(double.infinity, 64),
              ),
              child: const Text("LOGOUT"),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;

  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: cs.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.primary.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Text(
              label.toUpperCase(),
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: cs.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

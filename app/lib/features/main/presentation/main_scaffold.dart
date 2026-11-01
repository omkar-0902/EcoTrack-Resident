import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/haptics.dart';
import '../../dashboard/presentation/dashboard_view.dart';
import '../../schedule/presentation/schedule_view.dart';
import '../../rewards/presentation/rewards_view.dart';
import '../../profile/presentation/profile_view.dart';
import '../../schedule/data/pickup_provider.dart';
import '../../../shared/widgets/pill_nav_bar.dart';
import '../data/navigation_provider.dart';

class MainScaffold extends ConsumerStatefulWidget {
  const MainScaffold({super.key});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  // Global Key to maintain RotatingLogo state across page switches.
  final rotatingLogoKey = GlobalKey();

  // Built once so each tab keeps its state (scroll position, form selection)
  // inside the IndexedStack.
  static const List<Widget> _pages = [
    DashboardView(),
    ScheduleView(),
    RewardsView(),
    ProfileView(),
  ];

  void _selectTab(int index) {
    if (ref.read(navigationProvider) == index) return;
    ref.read(navigationProvider.notifier).state = index;
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = ref.watch(navigationProvider);
    final cs = Theme.of(context).colorScheme;
    final pickup = ref.watch(pickupTrackingProvider);

    // Layout uses the Scaffold's own slots instead of a Stack with hard-coded
    // offsets:
    //  * bottomNavigationBar is always laid out at the bottom, wrapped in a
    //    SafeArea so it sits above the gesture bar / 3-button bar, and the body
    //    ends above it, so it never covers tab content.
    //  * floatingActionButton is placed by the Scaffold directly above the
    //    navigation bar on every screen height.
    //  * The navigation bar stays visible at all times (it used to disappear
    //    whenever a pickup was active, leaving the resident unable to reach
    //    Rewards / Profile / Logout).
    return PopScope(
      // Android system back on a non-Home tab returns to the Home tab instead
      // of closing the app; on the Home tab it behaves normally (exits).
      canPop: selectedIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          AppHaptics.selectionClick();
          _selectTab(0);
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: IndexedStack(index: selectedIndex, children: _pages),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        floatingActionButton: selectedIndex != 0
            ? null
            : FloatingActionButton.extended(
                // While a pickup is active, scheduling another is not allowed
                // by the backend, so the action becomes "Track Pickup".
                onPressed: () {
                  AppHaptics.mediumImpact();
                  if (pickup.isActive) {
                    Navigator.pushNamed(
                      context,
                      '/track',
                      arguments: pickup.pickupId,
                    );
                  } else {
                    Navigator.pushNamed(context, '/schedule');
                  }
                },
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                icon: Icon(pickup.isActive ? Icons.route_rounded : Icons.add),
                label: Text(
                  pickup.isActive ? "TRACK PICKUP" : "SCHEDULE PICKUP",
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: PillNavigationBar(
            logoKey: rotatingLogoKey,
            currentIndex: selectedIndex,
            onLogoTap: () {
              // Cycle through 0 -> 1 -> 2 -> 3 -> 0
              _selectTab((selectedIndex + 1) % 4);
            },
            onItemTap: _selectTab,
            items: const [
              PillNavItemData(label: "HOME", icon: Icons.home_max),
              PillNavItemData(label: "REQUESTS", icon: Icons.calendar_today),
              PillNavItemData(label: "REWARDS", icon: Icons.military_tech),
              PillNavItemData(label: "PROFILE", icon: Icons.person),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_theme.dart';
import '../../../shared/widgets/resident_app_bar.dart';
import '../../profile/data/profile_provider.dart';

class RewardsView extends ConsumerStatefulWidget {
  const RewardsView({super.key});

  @override
  ConsumerState<RewardsView> createState() => _RewardsViewState();
}

class _RewardsViewState extends ConsumerState<RewardsView> {
  /// Real points from the shared profile; "0" while loading or unavailable
  /// (previously a hard-coded placeholder of "1,240" was shown).
  String get ecoPoints =>
      ref.watch(userProfileProvider).asData?.value.ecoPoints.toString() ?? "0";

  Map<String, dynamic> _getTierData() {
    int points = int.tryParse(ecoPoints.replaceAll(',', '')) ?? 0;

    if (points < 500) {
      return {
        "name": "BRONZE",
        "nextName": "SILVER",
        "progress": points / 500,
        "remaining": 500 - points,
        "index": 0,
      };
    } else if (points < 1500) {
      double progress = (points - 500) / 1000;
      return {
        "name": "SILVER",
        "nextName": "GOLD",
        "progress": progress,
        "remaining": 1500 - points,
        "index": 1,
      };
    } else if (points < 3000) {
      double progress = (points - 1500) / 1500;
      return {
        "name": "GOLD",
        "nextName": "PLATINUM",
        "progress": progress,
        "remaining": 3000 - points,
        "index": 2,
      };
    } else {
      return {
        "name": "PLATINUM",
        "nextName": "MAX",
        "progress": 1.0,
        "remaining": 0,
        "index": 3,
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    final tierData = _getTierData();

    return Scaffold(
      backgroundColor: AppTheme.surfaceBase,
      appBar: const ResidentAppBar(
        showAvatarOnLeft: true,
        title: "",
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            // Tier Progress Card
            _buildTierCard(tierData),

            const SizedBox(height: 32),

            // Tier Selector
            _buildTierSelector(tierData["index"]),

            const SizedBox(height: 48),

            // Earned Badges
            _buildSectionHeader("EARNED BADGES"),
            const SizedBox(height: 20),
            _buildBadgeList(),

            const SizedBox(height: 48),

            // Rewards Coming Soon
            _buildComingSoonCard(),

            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  Widget _buildTierCard(Map<String, dynamic> tierData) {
    final progress = (tierData["progress"] as double).clamp(0.0, 1.0);
    final remaining = tierData["remaining"] as int;
    final isMax = tierData["nextName"] == "MAX";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF00E676),
            const Color(0xFF00C853).withValues(alpha: 0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E676).withValues(alpha: 0.25),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.emoji_events_outlined,
                    color: Colors.black54, size: 16),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    "${tierData["name"]} TIER RESIDENT",
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text(
            "Your EcoPoints:",
            style: GoogleFonts.spaceGrotesk(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black.withValues(alpha: 0.7),
              height: 1.1,
            ),
          ),
          Text(
            ecoPoints,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 52,
              fontWeight: FontWeight.bold,
              color: Colors.black,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  isMax
                      ? "MAX TIER REACHED"
                      : "$remaining PTS TO ${tierData["nextName"]} TIER",
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.black.withValues(alpha: 0.6),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "${(progress * 100).toInt()}%",
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Stack(
            children: [
              Container(
                height: 14,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              FractionallySizedBox(
                widthFactor: progress,
                child: Container(
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTierSelector(int selectedTierIndex) {
    final tiers = ["BRONZE", "SILVER", "GOLD", "PLATINUM"];
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: tiers.asMap().entries.map((entry) {
            final index = entry.key;
            final tier = entry.value;
            final isSelected = index == selectedTierIndex;
            return Column(
              children: [
                Text(
                  tier,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? Colors.white
                        : AppTheme.onSurfaceVariant.withValues(alpha: 0.6),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? AppTheme.primaryNeon
                        : AppTheme.surfaceContainerHighest,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppTheme.primaryNeon.withValues(alpha: 0.6),
                              blurRadius: 10,
                              spreadRadius: 2,
                            )
                          ]
                        : null,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Container(
          height: 1,
          width: double.infinity,
          color: AppTheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.spaceGrotesk(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        letterSpacing: 2,
        color: Colors.white,
      ),
    );
  }

  Widget _buildBadgeList() {
    return SizedBox(
      height: 110,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildBadgeItem(Icons.local_florist, "FIRST PICKUP 🌱"),
          const SizedBox(width: 16),
          _buildBadgeItem(Icons.calendar_month, "7-DAY STREAK ♻️"),
          const SizedBox(width: 16),
          _buildBadgeItem(Icons.public, "100KG DIVERTED 🌍"),
          const SizedBox(width: 16),
          _buildBadgeItem(Icons.bolt, "30-DAY ACTIVE ⚡", isLocked: true),
        ],
      ),
    );
  }

  Widget _buildBadgeItem(IconData icon, String label, {bool isLocked = false}) {
    return Column(
      children: [
        Container(
          width: 82,
          height: 82,
          decoration: BoxDecoration(
            color: isLocked ? AppTheme.surfaceContainerLow : AppTheme.surfaceContainerHigh.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isLocked ? Colors.transparent : AppTheme.primaryNeon.withValues(alpha: 0.2),
            ),
          ),
          child: Icon(
            icon,
            color: isLocked ? Colors.white24 : AppTheme.primaryNeon,
            size: 32,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 8,
            fontWeight: FontWeight.bold,
            color: isLocked ? Colors.white24 : Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildComingSoonCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(44),
        border: Border.all(color: AppTheme.primaryNeon.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          // Glowing Tree Icon
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryNeon.withValues(alpha: 0.15),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: const Icon(
              Icons.forest_rounded,
              size: 84,
              color: AppTheme.primaryNeon,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            "REWARDS COMING SOON",
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
              color: AppTheme.primaryNeon,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Our digital ecosystem is evolving. New high-tech sustainable rewards are being curated for your district.",
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.onSurfaceVariant.withValues(alpha: 0.8),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildDot(true),
              _buildDot(false),
              _buildDot(false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDot(bool active) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? AppTheme.primaryNeon : AppTheme.primaryNeon.withValues(alpha: 0.2),
      ),
    );
  }
}

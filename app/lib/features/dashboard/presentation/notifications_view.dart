import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/haptics.dart';

class NotificationsView extends StatelessWidget {
  const NotificationsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
          tooltip: 'Back',
          onPressed: () {
            AppHaptics.lightImpact();
            // Opened via pushNamed from Home/Profile/app bar; returns there.
            // maybePop is a no-op if this is somehow the only route, instead
            // of popping to a blank screen.
            Navigator.maybePop(context);
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert, color: Theme.of(context).colorScheme.onSurface),
            onPressed: () => AppHaptics.lightImpact(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Activity & Alerts",
              style: GoogleFonts.spaceGrotesk(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                letterSpacing: -1,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Real-time logistics and ecosystem updates for your sector.",
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            
            // Filter Chips
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _FilterChip(label: "All", isActive: true),
                  _FilterChip(label: "Pickups"),
                  _FilterChip(label: "Rewards"),
                  _FilterChip(label: "System"),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // Notifications List
            const _NotificationItem(
              title: "Collector is 50m away — be ready!",
              subtitle: "Vehicle #4092 approaching your drop zone.",
              category: "LIVE PROXIMITY",
              time: "Just Now",
              icon: Icons.local_shipping,
              isPriority: true,
            ),
            const _NotificationItem(
              title: "Collector arrived in your area",
              subtitle: "Sector 4B North cluster is now active.",
              category: "ARRIVAL UPDATE",
              time: "5 min ago",
              icon: Icons.location_on,
            ),
            const _NotificationItem(
              title: "Badge unlocked: 7-day Streak!",
              subtitle: "You've earned 500 Eco-Credits this week.",
              category: "ACHIEVEMENT",
              time: "Today",
              icon: Icons.military_tech,
              color: Colors.amberAccent,
            ),
            const _NotificationItem(
              title: "Pickup rescheduled to Thursday 10AM",
              subtitle: "System maintenance in Sector 4B requires a brief delay.",
              category: "SCHEDULE CHANGE",
              time: "2h ago",
              icon: Icons.calendar_month,
              color: Colors.orangeAccent,
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isActive;

  const _FilterChip({required this.label, this.isActive = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1) : Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
          border: isActive ? Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)) : null,
          boxShadow: isActive ? [
            BoxShadow(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
              blurRadius: 10,
            )
          ] : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            color: isActive ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _NotificationItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final String category;
  final String time;
  final IconData icon;
  final bool isPriority;
  final Color? color;

  const _NotificationItem({
    required this.title,
    required this.subtitle,
    required this.category,
    required this.time,
    required this.icon,
    this.isPriority = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final themeColor = color ?? (isPriority ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isPriority ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3) : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: themeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: themeColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        category,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          color: themeColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                      Text(
                        time,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

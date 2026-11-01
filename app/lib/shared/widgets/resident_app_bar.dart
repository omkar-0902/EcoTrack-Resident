import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_theme.dart';
import '../../core/haptics.dart';

class ResidentAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final Widget? titleWidget;
  final bool showAvatarOnLeft;
  final List<Widget>? actions;
  final Widget? leading;
  final double? leadingWidth;

  const ResidentAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.showAvatarOnLeft = true,
    this.actions,
    this.leading,
    this.leadingWidth,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      leadingWidth: leadingWidth ?? (showAvatarOnLeft ? 160 : 56),
      leading: leading ?? (showAvatarOnLeft
          ? Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppTheme.surfaceContainerHigh,
                    child: const Icon(Icons.person, color: AppTheme.primaryNeon, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title ?? "ZONE 4B",
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: AppTheme.primaryNeon,
                    ),
                  ),
                ],
              ),
            )
          : null),
      title: titleWidget ?? (!showAvatarOnLeft && title != null
          ? Text(
              title!,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                color: AppTheme.primaryNeon,
              ),
            )
          : null),
      actions: actions ??
          [
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 24),
                  tooltip: 'Notifications',
                  onPressed: () {
                    AppHaptics.lightImpact();
                    Navigator.pushNamed(context, '/notifications');
                  },
                ),
                Positioned(
                  right: 12,
                  top: 12,
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
            if (!showAvatarOnLeft) ...[
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(right: 16),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: AppTheme.surfaceContainerHigh,
                  child: Icon(Icons.person, color: AppTheme.primaryNeon, size: 20),
                ),
              ),
            ],
            const SizedBox(width: 16),
          ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

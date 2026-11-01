import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/haptics.dart';

class GhostButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool fullWidth;

  const GhostButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final button = OutlinedButton(
      onPressed: () {
        AppHaptics.lightImpact();
        onPressed();
      },
      style: OutlinedButton.styleFrom(
        side: BorderSide(
          color: cs.primary.withValues(alpha: 0.2),
          width: 1.5,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.spaceGrotesk(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
          color: cs.primary,
        ),
      ),
    );

    if (fullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CustomTextField extends StatelessWidget {
  final String label;
  final String? hint;
  final bool obscureText;
  final TextEditingController? controller;
  final TextInputType keyboardType;
  final IconData? prefixIcon;

  const CustomTextField({
    super.key,
    required this.label,
    this.hint,
    this.obscureText = false,
    this.controller,
    this.keyboardType = TextInputType.text,
    this.prefixIcon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label.toUpperCase(),
            style: GoogleFonts.spaceGrotesk(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: GoogleFonts.inter(
            color: cs.onSurface,
            fontSize: 16,
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon != null 
              ? Icon(prefixIcon, color: cs.primary.withValues(alpha: 0.5), size: 20)
              : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          ),
        ),
      ],
    );
  }
}

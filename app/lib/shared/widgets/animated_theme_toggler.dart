import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/haptics.dart';
import '../../core/theme_provider.dart';

class AnimatedThemeToggler extends ConsumerStatefulWidget {
  const AnimatedThemeToggler({super.key});

  @override
  ConsumerState<AnimatedThemeToggler> createState() => _AnimatedThemeTogglerState();
}

class _AnimatedThemeTogglerState extends ConsumerState<AnimatedThemeToggler>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _rotation = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );

    // Initial state matching the current theme
    if (ref.read(themeProvider) == ThemeMode.light) {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleTheme() {
    final mode = ref.read(themeProvider);
    final nextMode = mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;

    AppHaptics.mediumImpact();
    
    if (nextMode == ThemeMode.light) {
      _controller.forward();
    } else {
      _controller.reverse();
    }

    ref.read(themeProvider.notifier).state = nextMode;
  }

  @override
  Widget build(BuildContext context) {

    return GestureDetector(
      onTap: _toggleTheme,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final colorScheme = Theme.of(context).colorScheme;
          return RotationTransition(
            turns: _rotation,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Color.lerp(
                  colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
                  colorScheme.primary.withValues(alpha: 0.1),
                  _controller.value,
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Color.lerp(
                    colorScheme.outlineVariant.withValues(alpha: 0.1),
                    colorScheme.primary.withValues(alpha: 0.3),
                    _controller.value,
                  )!,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                   // Moon Rays (disappear) / Sun Rays (appear)
                  ...List.generate(8, (index) {
                    final angle = index * 0.785;
                    return Opacity(
                      opacity: _controller.value,
                      child: Transform.rotate(
                        angle: angle,
                        child: Transform.translate(
                          offset: const Offset(0, -12),
                          child: Container(
                            width: 2,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                  
                  // Main Morphing Body
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Color.lerp(
                        Theme.of(context).colorScheme.onSurface,
                        Theme.of(context).colorScheme.primary,
                        _controller.value,
                      ),
                      shape: BoxShape.circle,
                    ),
                  ),
                  
                  // Moon Cutter
                  Positioned(
                    right: 4 + (12 * _controller.value),
                    top: 4 - (4 * _controller.value),
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Color.lerp(
                          // Use scaffold bg to avoid ghost boxes in light mode
                          Theme.of(context).scaffoldBackgroundColor,
                          Colors.transparent,
                          _controller.value,
                        ),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

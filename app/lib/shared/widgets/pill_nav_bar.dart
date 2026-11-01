import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/haptics.dart';

class PillNavigationBar extends StatelessWidget {
  final List<PillNavItemData> items;
  final int currentIndex;
  final VoidCallback onLogoTap;

  /// Called with the index of the tapped item.
  final ValueChanged<int>? onItemTap;
  final Key? logoKey;

  const PillNavigationBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onLogoTap,
    this.onItemTap,
    this.logoKey,
  });

  @override
  Widget build(BuildContext context) {
    // The outer spacing is applied OUTSIDE the clip: previously the margin was
    // inside ClipRRect/BackdropFilter, so the blur region was larger than the
    // visible pill and clipped/blurred whatever sat just above it (e.g. the
    // Schedule Pickup button's glow). System insets are handled by the
    // SafeArea that wraps this widget in MainScaffold.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: 72,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainer.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: 0.2),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 25,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                // Rotating Logo - Now the primary navigation trigger (State preserved via logoKey)
                _RotatingLogo(key: logoKey, onTap: onLogoTap),
                const SizedBox(width: 8),

                // Navigation items: each opens its tab.
                Expanded(
                  child: Row(
                    children: List.generate(items.length, (index) {
                      final isActive = currentIndex == index;
                      return Expanded(
                        child: Semantics(
                          button: true,
                          selected: isActive,
                          label: items[index].label,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: onItemTap == null
                                ? null
                                : () {
                                    AppHaptics.selectionClick();
                                    onItemTap!(index);
                                  },
                            child: _PillNavItem(
                              data: items[index],
                              isActive: isActive,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PillNavItemData {
  final String label;
  final IconData icon;

  const PillNavItemData({required this.label, required this.icon});
}

class _RotatingLogo extends StatefulWidget {
  final VoidCallback onTap;
  const _RotatingLogo({super.key, required this.onTap});

  @override
  State<_RotatingLogo> createState() => _RotatingLogoState();
}

class _RotatingLogoState extends State<_RotatingLogo>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  final List<_LeafParticle> _particles = [];

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  void _spawnParticles() {
    setState(() {
      final random = math.Random();
      for (int i = 0; i < 6; i++) {
        _particles.add(
          _LeafParticle(
            id: DateTime.now().millisecondsSinceEpoch + i,
            angle: random.nextDouble() * 2 * math.pi,
            distance: 40.0 + random.nextDouble() * 40.0,
            onFinished: (id) {
              setState(() {
                _particles.removeWhere((p) => p.id == id);
              });
            },
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // Particles Layer
        ..._particles,

        // The Main Button
        MouseRegion(
          onEnter: (_) {
            if (!_rotationController.isAnimating) {
              _rotationController.forward(from: 0);
            }
          },
          child: GestureDetector(
            onTap: () {
              AppHaptics.mediumImpact();
              // Force rotation from beginning
              _rotationController.forward(from: 0);
              _spawnParticles();
              widget.onTap();
            },
            child: RotationTransition(
              turns: _rotationController,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/logo.jpg',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LeafParticle extends StatefulWidget {
  final int id;
  final double angle;
  final double distance;
  final Function(int) onFinished;

  const _LeafParticle({
    required this.id,
    required this.angle,
    required this.distance,
    required this.onFinished,
  });

  @override
  State<_LeafParticle> createState() => _LeafParticleState();
}

class _LeafParticleState extends State<_LeafParticle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<double> _pos;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _opacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
      ),
    );

    _pos = Tween<double>(
      begin: 0.0,
      end: widget.distance,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.2), weight: 30),
      TweenSequenceItem(tween: Tween<double>(begin: 1.2, end: 0.0), weight: 70),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _controller.forward().then((_) => widget.onFinished(widget.id));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final x = math.cos(widget.angle) * _pos.value;
        final y = math.sin(widget.angle) * _pos.value;

        return Positioned(
          left: 24 + x - 6,
          top: 24 + y - 6,
          child: Opacity(
            opacity: _opacity.value,
            child: Transform.scale(
              scale: _scale.value,
              child: Transform.rotate(
                angle: widget.angle + _controller.value * 2,
                child: Icon(
                  Icons.eco,
                  color: Theme.of(context).colorScheme.primary,
                  size: 12,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PillNavItem extends StatefulWidget {
  final PillNavItemData data;
  final bool isActive;

  const _PillNavItem({required this.data, required this.isActive});

  @override
  State<_PillNavItem> createState() => _PillNavItemState();
}

class _PillNavItemState extends State<_PillNavItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _anim = CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart);

    if (widget.isActive) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(_PillNavItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // The "Bubble" Fill effect (Bottom-up scaling)
              AnimatedBuilder(
                animation: _anim,
                builder: (context, child) {
                  return FractionalTranslation(
                    translation: const Offset(0, 0),
                    child: Transform.scale(
                      scale:
                          _anim.value * 3.5, // Large enough to cover the pill
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  );
                },
              ),

              // Content Stack (Text sliding)
              AnimatedBuilder(
                animation: _anim,
                builder: (context, child) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // Inactive Icon
                      Opacity(
                        opacity: (1.0 - _anim.value).clamp(0.0, 1.0),
                        child: Transform.translate(
                          offset: Offset(0, -30 * _anim.value),
                          child: Icon(
                            widget.data.icon,
                            size: 18,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),

                      // Active Text
                      Opacity(
                        opacity: _anim.value,
                        child: Transform.translate(
                          offset: Offset(0, 30 * (1.0 - _anim.value)),
                          child: Text(
                            widget.data.label,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onPrimary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),

              // Active Dot
              if (widget.isActive)
                Positioned(
                  bottom: 6,
                  child: FadeTransition(
                    opacity: _anim,
                    child: Container(
                      width: 3,
                      height: 3,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.onPrimary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

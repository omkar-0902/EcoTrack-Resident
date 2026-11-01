import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../core/theme_provider.dart';
import 'circular_reveal_clipper.dart';

/// Applies the selected theme and plays a circular-reveal transition when the
/// theme changes.
///
/// The app subtree ([child], which contains the root Navigator) is built
/// exactly ONCE. The previous implementation placed [child] in the tree two
/// or three times (one per theme layer), which put the Navigator's GlobalKey
/// in several places at once. That caused "Multiple widgets used the same
/// GlobalKey" errors on every rebuild and made Flutter move the live Navigator
/// between layers, breaking navigation and input.
///
/// Instead, a snapshot of the old-theme frame is captured just before the
/// switch and painted on top of the live (new-theme) tree, with a growing
/// circular hole that reveals the new theme underneath.
class ThemeTransitionWrapper extends ConsumerStatefulWidget {
  final Widget child;

  const ThemeTransitionWrapper({super.key, required this.child});

  @override
  ConsumerState<ThemeTransitionWrapper> createState() =>
      _ThemeTransitionWrapperState();
}

class _ThemeTransitionWrapperState extends ConsumerState<ThemeTransitionWrapper>
    with SingleTickerProviderStateMixin {
  final GlobalKey _boundaryKey = GlobalKey();
  late final AnimationController _controller;
  ui.Image? _snapshot;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(_clearSnapshot);
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    _clearSnapshot();
    super.dispose();
  }

  void _clearSnapshot() {
    _snapshot?.dispose();
    _snapshot = null;
  }

  /// Captures the currently painted (old theme) frame. Returns null when a
  /// snapshot is not possible (e.g. nothing painted yet); in that case the
  /// theme simply switches without the reveal animation.
  ui.Image? _captureSnapshot() {
    try {
      final boundary = _boundaryKey.currentContext?.findRenderObject();
      if (boundary is! RenderRepaintBoundary || boundary.debugNeedsPaint) {
        return null;
      }
      final pixelRatio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
      return boundary.toImageSync(pixelRatio: pixelRatio);
    } catch (_) {
      return null;
    }
  }

  void _onThemeChanged(ThemeMode? previous, ThemeMode next) {
    if (previous == next) return;
    final snapshot = _captureSnapshot();
    _clearSnapshot();
    if (snapshot == null) {
      _controller.value = 1.0;
      return;
    }
    _snapshot = snapshot;
    _controller.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    // Runs synchronously when the provider changes, before the new-theme
    // frame is painted, so the snapshot still shows the old theme.
    ref.listen<ThemeMode>(themeProvider, _onThemeChanged);

    final themeMode = ref.watch(themeProvider);
    final themeData =
        themeMode == ThemeMode.light ? AppTheme.lightTheme : AppTheme.darkTheme;
    final snapshot = _snapshot;

    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        RepaintBoundary(
          key: _boundaryKey,
          child: Theme(data: themeData, child: widget.child),
        ),
        if (snapshot != null)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return ClipPath(
                    clipper: _InverseClipper(
                      CircularRevealClipper(
                        fraction: _controller.value,
                        // Theme toggler sits at the top-right of the Profile view.
                        center: Offset(MediaQuery.sizeOf(context).width - 40, 60),
                      ),
                    ),
                    child: RawImage(image: snapshot, fit: BoxFit.fill),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

/// Clips to everything OUTSIDE the wrapped clipper's path.
class _InverseClipper extends CustomClipper<Path> {
  final CircularRevealClipper inner;

  _InverseClipper(this.inner);

  @override
  Path getClip(Size size) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addPath(inner.getClip(size), Offset.zero);
  }

  @override
  bool shouldReclip(covariant _InverseClipper oldClipper) =>
      inner.shouldReclip(oldClipper.inner);
}

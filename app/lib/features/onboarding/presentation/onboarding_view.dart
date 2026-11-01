import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/haptics.dart';

class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingSlide> _slides = [
    const OnboardingSlide(
      title: "Schedule By Date",
      description:
          "Select your preferred date for waste collection. The municipality collector will arrive during the fixed window.",
      icon: Icons.home_work,
      accentColorIsPrimary: true, // Marker for dynamic primary color
    ),
    const OnboardingSlide(
      title: "Live Updates",
      description:
          "Track proximity with real-time text alerts—no maps needed. Intuitive digital forest awareness.",
      icon: Icons.sensors,
      accentColorIsPrimary: true,
    ),
    const OnboardingSlide(
      title: "Earn EcoPoints",
      description:
          "Get rewarded for responsible disposal and climb the tiers. Your impact, gamified.",
      icon: Icons.military_tech,
      accentColor: Colors.amberAccent,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Ambient Glows
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
              ),
            ),
          ),

          PageView.builder(
            controller: _pageController,
            itemCount: _slides.length,
            onPageChanged: (index) {
              AppHaptics.lightImpact();
              setState(() => _currentPage = index);
            },
            itemBuilder: (context, index) {
              return _OnboardingSlideWidget(slide: _slides[index]);
            },
          ),

          // Pagination and Actions
          Positioned(
            bottom: 60,
            left: 24,
            right: 24,
            child: Column(
              children: [
                // Indicators
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_slides.length, (index) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: _currentPage == index ? 32 : 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: _currentPage == index
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(
                                context,
                              ).colorScheme.outlineVariant.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 48),

                if (_currentPage == _slides.length - 1)
                  ElevatedButton(
                    onPressed: () {
                      AppHaptics.mediumImpact();
                      Navigator.pushReplacementNamed(
                        context,
                        '/location-permission',
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 64),
                    ),
                    child: const Text("GET STARTED"),
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () {
                          AppHaptics.lightImpact();
                          Navigator.pushReplacementNamed(
                            context,
                            '/location-permission',
                          );
                        },
                        child: Text(
                          "SKIP",
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          AppHaptics.mediumImpact();
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOutCubic,
                          );
                        },
                        icon: Icon(
                          Icons.arrow_forward,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        iconSize: 32,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingSlide {
  final String title;
  final String description;
  final IconData icon;
  final Color? accentColor;
  final bool accentColorIsPrimary;

  const OnboardingSlide({
    required this.title,
    required this.description,
    required this.icon,
    this.accentColor,
    this.accentColorIsPrimary = false,
  });
}

class _OnboardingSlideWidget extends StatelessWidget {
  final OnboardingSlide slide;

  const _OnboardingSlideWidget({required this.slide});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = slide.accentColorIsPrimary
        ? cs.primary
        : (slide.accentColor ?? cs.primary);

    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: cs.surfaceContainer,
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: color.withValues(alpha: 0.1)),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.05),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Icon(slide.icon, size: 100, color: color),
          ),
          const SizedBox(height: 60),
          Text(
            slide.title.toUpperCase(),
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: -1,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            slide.description,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 16,
              height: 1.6,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

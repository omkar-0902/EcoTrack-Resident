import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import '../../../services/auth_service.dart';

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  @override
  void initState() {
    super.initState();
    _handleStartUp();
  }

  Future<void> _handleStartUp() async {
    // Wait for the animation/branding to show
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    // Check if session is valid. Any unexpected failure is treated as
    // "no session" so the user is never stuck on the splash screen.
    bool isSessionValid = false;
    String? username;
    try {
      isSessionValid = await AuthService.isSessionValid();
      if (isSessionValid) {
        username = await AuthService.getUsernameFromToken();
      }
    } catch (_) {
      isSessionValid = false;
    }

    // pushReplacement replaces the TOP route; only redirect if the splash is
    // still the visible route, so it can never replace some other screen.
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;

    if (isSessionValid) {
      Navigator.pushReplacementNamed(
        context, 
        '/home', 
        arguments: username ?? "User",
      );
    } else {
      // Navigate to Onboarding for fresh feel or if session expired
      Navigator.pushReplacementNamed(context, '/onboarding');
    }
  }

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
          
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                    image: const DecorationImage(
                      image: AssetImage('assets/images/logo.jpg'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  "ECO CONNECT",
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "SUSTAINABILITY HUB",
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          
          // Bottom Loader
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                  strokeWidth: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

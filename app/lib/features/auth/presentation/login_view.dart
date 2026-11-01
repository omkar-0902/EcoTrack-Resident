import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/services/auth_service.dart';
import '../../../core/haptics.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/ghost_button.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final TextEditingController userNameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLoading = false;

  @override
  void dispose() {
    userNameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    if (isLoading) return;
    AppHaptics.mediumImpact();

    final userName = userNameController.text.trim();
    // Trimmed for consistency with registration, which trims the password.
    final password = passwordController.text.trim();

    if (userName.isEmpty || password.isEmpty) {
      _showMessage("Please enter your username and password");
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => isLoading = true);

    final result = await AuthService.loginUser(
      userName: userName,
      password: password,
    );

    if (!mounted) return;
    setState(() => isLoading = false);

    if (result.isSuccess) {
      _showMessage("Login Successful");
      Navigator.pushReplacementNamed(context, '/home', arguments: userName);
    } else {
      _showMessage(result.errorMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    image: const DecorationImage(
                      image: AssetImage('assets/images/logo.jpg'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              Text(
                "WELCOME BACK",
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),

              Text(
                "Sign in to your\nResident Portal",
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 48),

              CustomTextField(
                label: "Username",
                hint: "Enter your username",
                prefixIcon: Icons.person_outline,
                controller: userNameController,
              ),

              const SizedBox(height: 24),

              CustomTextField(
                label: "Password",
                hint: "Enter your password",
                obscureText: true,
                prefixIcon: Icons.lock_outline,
                controller: passwordController,
              ),

              const SizedBox(height: 40),

              ElevatedButton(
                onPressed: isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 64),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text("ACCESS SYSTEM"),
              ),

              const SizedBox(height: 24),

              GhostButton(
                text: "CREATE ACCOUNT",
                fullWidth: true,
                onPressed: () {
                  Navigator.pushNamed(context, '/register');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

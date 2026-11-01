import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/haptics.dart';
import '../../../shared/widgets/custom_text_field.dart';
import 'package:app/services/auth_service.dart';

class RegistrationView extends StatefulWidget {
  const RegistrationView({super.key});

  @override
  State<RegistrationView> createState() => _RegistrationViewState();
}

class _RegistrationViewState extends State<RegistrationView> {
  // ✅ Controllers
  final TextEditingController userNameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLoading = false;

  @override
  void dispose() {
    userNameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Returns to the screen that opened registration (the login screen).
  /// Falls back to replacing with login if registration is the only route,
  /// so Back never leaves a blank screen.
  void _goBack() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushReplacementNamed('/login');
    }
  }

  String? _validate({
    required String userName,
    required String phone,
    required String address,
    required String password,
  }) {
    if (userName.isEmpty || phone.isEmpty || address.isEmpty || password.isEmpty) {
      return "Please fill in all fields";
    }
    if (!RegExp(r'^\+?[0-9]+$').hasMatch(phone)) {
      return "Phone number can only contain digits";
    }
    return null;
  }

  Future<void> _submit() async {
    if (isLoading) return;
    AppHaptics.mediumImpact();

    final userName = userNameController.text.trim();
    final phone = phoneController.text.trim();
    final address = addressController.text.trim();
    final password = passwordController.text.trim();

    final error = _validate(
      userName: userName,
      phone: phone,
      address: address,
      password: password,
    );
    if (error != null) {
      _showMessage(error);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => isLoading = true);

    final result = await AuthService.registerUser(
      userName: userName,
      password: password,
      phoneNumber: phone,
      address: address,
    );

    if (!mounted) return;
    setState(() => isLoading = false);

    if (result.isSuccess) {
      _showMessage("Registration Successful");
      _goBack();
    } else {
      _showMessage(result.errorMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: Theme.of(context).colorScheme.onSurface,
            size: 20,
          ),
          tooltip: 'Back',
          onPressed: () {
            AppHaptics.lightImpact();
            _goBack();
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "JOIN THE FOREST",
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),

              Text(
                "Create your\nEco Account",
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  height: 1.1,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),

              const SizedBox(height: 40),

              // ✅ Full Name
              CustomTextField(
                label: "Full Name",
                hint: "John Doe",
                prefixIcon: Icons.person_outline,
                controller: userNameController,
              ),
              const SizedBox(height: 20),

              // ✅ Phone Number
              CustomTextField(
                label: "Phone Number",
                hint: "9876543210",
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                controller: phoneController,
              ),
              const SizedBox(height: 20),

              // ✅ Address
              CustomTextField(
                label: "Address",
                hint: "Goa",
                prefixIcon: Icons.location_on_outlined,
                controller: addressController,
              ),
              const SizedBox(height: 20),

              // ✅ Password
              CustomTextField(
                label: "Password",
                hint: "••••••••",
                obscureText: true,
                prefixIcon: Icons.lock_outline,
                controller: passwordController,
              ),

              const SizedBox(height: 48),

              // 🚀 REGISTER BUTTON
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
                    : const Text("INITIALIZE ACCOUNT"),
              ),

              const SizedBox(height: 24),

              // T&C
              Center(
                child: Text(
                  "By joining, you agree to our Eco-Directives.",
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
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

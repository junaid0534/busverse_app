import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'otp_verification_screen.dart';
import 'email_verification_sent_screen.dart';
import 'package:bus_ticket_system/database/db_helper.dart';
import 'package:bus_ticket_system/database/user_model.dart';
import 'package:bus_ticket_system/services/auth_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  bool male = false;
  bool female = false;
  bool acceptTerms = false;
  bool isLoading = false;

  bool passwordVisible = false;
  bool confirmPasswordVisible = false;

  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final cnicController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // TOP BLUE BAR
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                decoration: const BoxDecoration(
                  color: Color(0xFF388AF6),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      "Register",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          "Login",
                          style: TextStyle(
                            color: Color(0xFF388AF6),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // First & Last Name Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(child: _buildField("First Name", firstNameController)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildField("Last Name", lastNameController)),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildField("Email", emailController, type: TextInputType.emailAddress, icon: Icons.email_outlined),
              ),

              const SizedBox(height: 10),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildField("Phone No", phoneController, type: TextInputType.phone, icon: Icons.phone_outlined),
              ),

              const SizedBox(height: 10),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildField("CNIC Number", cnicController, type: TextInputType.number, icon: Icons.credit_card_outlined),
              ),

              const SizedBox(height: 12),

              // Gender
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Gender",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        _genderChip("Male", male, () {
                          setState(() { male = true; female = false; });
                        }),
                        const SizedBox(width: 10),
                        _genderChip("Female", female, () {
                          setState(() { female = true; male = false; });
                        }),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Password
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildPasswordField("Password", passwordController, passwordVisible, () {
                  setState(() => passwordVisible = !passwordVisible);
                }),
              ),

              const SizedBox(height: 10),

              // Confirm Password
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildPasswordField("Confirm Password", confirmPasswordController, confirmPasswordVisible, () {
                  setState(() => confirmPasswordVisible = !confirmPasswordVisible);
                }),
              ),

              const SizedBox(height: 10),

              // Terms & Privacy
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: Checkbox(
                        value: acceptTerms,
                        activeColor: const Color(0xFF388AF6),
                        onChanged: (val) {
                          setState(() => acceptTerms = val ?? false);
                        },
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          text: "I accept the ",
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          children: [
                            TextSpan(
                              text: "Terms",
                              style: const TextStyle(
                                color: Color(0xFF388AF6),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const TextSpan(text: " and "),
                            TextSpan(
                              text: "Privacy Policy",
                              style: const TextStyle(
                                color: Color(0xFF388AF6),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Create Account Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF388AF6),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: isLoading ? null : _handleSignup,
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            "Create Account",
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Common Input Field ───
  Widget _buildField(String label, TextEditingController controller, {
    TextInputType type = TextInputType.text,
    IconData? icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          keyboardType: type,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: label,
            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            prefixIcon: icon != null ? Icon(icon, size: 18, color: const Color(0xFF388AF6)) : null,
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF388AF6), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Password Field ───
  Widget _buildPasswordField(String label, TextEditingController controller, bool isVisible, VoidCallback toggle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          obscureText: !isVisible,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: label,
            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            prefixIcon: const Icon(Icons.lock_outline, size: 18, color: Color(0xFF388AF6)),
            suffixIcon: IconButton(
              icon: Icon(
                isVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                size: 18,
                color: const Color(0xFF94A3B8),
              ),
              onPressed: toggle,
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF388AF6), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Gender Chip ───
  Widget _genderChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF388AF6) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFF388AF6) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  // ─── Signup Handler ───
  Future<void> _handleSignup() async {
    if (!acceptTerms) {
      _msg("Please accept Terms & Privacy Policy");
      return;
    }

    if (emailController.text.trim().isEmpty || passwordController.text.trim().isEmpty) {
      _msg("Please enter Email and Password");
      return;
    }

    if (passwordController.text.length < 6) {
      _msg("Password must be at least 6 characters long");
      return;
    }

    if (passwordController.text != confirmPasswordController.text) {
      _msg("Passwords do not match");
      return;
    }

    if (!male && !female) {
      _msg("Please select gender");
      return;
    }

    final phone = phoneController.text.trim();
    if (phone.isEmpty) {
      _msg("Please enter your Phone Number");
      return;
    }

    setState(() => isLoading = true);

    try {
      // 1. Create Firebase Auth Account & Send Official Email Verification Link
      await AuthService.instance.signUpWithFirebaseAndSendVerificationEmail(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
        firstName: firstNameController.text.trim(),
        lastName: lastNameController.text.trim(),
        phone: phone,
        cnic: cnicController.text.trim(),
        gender: male ? "Male" : "Female",
      );

      if (!mounted) return;

      // 2. Open Email Verification Sent Screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EmailVerificationSentScreen(
            email: emailController.text.trim(),
            password: passwordController.text.trim(),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        _msg(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _msg(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: Colors.red),
    );
  }
}

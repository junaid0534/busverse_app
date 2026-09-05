import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bus_ticket_system/database/db_helper.dart';
import 'package:bus_ticket_system/services/auth_service.dart';
import 'package:bus_ticket_system/services/supabase_service.dart';

class EditBasicInfoScreen extends StatefulWidget {
  final int userId;
  final String userEmail;

  const EditBasicInfoScreen({
    super.key,
    required this.userId,
    required this.userEmail,
  });

  @override
  State<EditBasicInfoScreen> createState() => _EditBasicInfoScreenState();
}

class _EditBasicInfoScreenState extends State<EditBasicInfoScreen> {
  final _formKey = GlobalKey<FormState>();

  Map<String, dynamic>? user;
  bool isLoading = true;
  bool isSaving = false;

  // Controllers
  final TextEditingController firstNameCtrl = TextEditingController();
  final TextEditingController lastNameCtrl = TextEditingController();
  final TextEditingController phoneCtrl = TextEditingController();
  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController cnicCtrl = TextEditingController();
  final TextEditingController cityCtrl = TextEditingController();
  final TextEditingController streetCtrl = TextEditingController();

  final TextEditingController currentPasswordCtrl = TextEditingController();
  final TextEditingController newPasswordCtrl = TextEditingController();
  final TextEditingController confirmPasswordCtrl = TextEditingController();

  String selectedGender = "M";
  String passwordError = '';
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  static const Color primaryBlue = Color(0xFF388AF6);
  static const Color darkNavy = Color(0xFF1E3C72);
  static const Color darkText = Color(0xFF1E293B);
  static const Color subText = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    fetchUser();
  }

  Future<void> fetchUser() async {
    String email = widget.userEmail.trim();
    if (email.isEmpty) {
      email = FirebaseAuth.instance.currentUser?.email ?? AuthService.instance.currentEmail ?? "";
    }

    dynamic data;
    if (email.isNotEmpty) {
      data = await DBHelper.instance.getUserByEmail(email);
    }
    if (data == null && widget.userId > 0) {
      data = await DBHelper.instance.getUserById(widget.userId);
    }

    if (data == null) {
      final all = await DBHelper.instance.getAllUsers();
      if (all.isNotEmpty) {
        final last = all.last;
        data = {
          'id': last.id,
          'firstName': last.firstName,
          'lastName': last.lastName,
          'phone': last.phone,
          'email': last.email,
          'cnic': last.cnic,
          'gender': last.gender,
          'city': last.city,
          'street': last.street,
        };
      }
    }

    // Sync from Supabase if needed
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (data == null && currentUid != null) {
      final cloudProfile = await SupabaseService.instance.getUserProfile(currentUid);
      if (cloudProfile != null) {
        data = {
          'id': 1,
          'firstName': cloudProfile['first_name'] ?? '',
          'lastName': cloudProfile['last_name'] ?? '',
          'phone': cloudProfile['phone'] ?? '',
          'email': cloudProfile['email'] ?? email,
          'cnic': cloudProfile['cnic'] ?? '',
          'gender': cloudProfile['gender'] ?? 'M',
          'city': cloudProfile['city'] ?? '',
          'street': cloudProfile['street'] ?? '',
        };
      }
    }

    if (mounted) {
      setState(() {
        user = data;
        firstNameCtrl.text = data?['firstName'] ?? '';
        lastNameCtrl.text = data?['lastName'] ?? '';
        phoneCtrl.text = data?['phone'] ?? '';
        emailCtrl.text = data?['email'] ?? email;
        cnicCtrl.text = data?['cnic'] ?? '';
        cityCtrl.text = data?['city'] ?? '';
        streetCtrl.text = data?['street'] ?? '';
        selectedGender = (data?['gender'] == 'F' || data?['gender'] == 'Female') ? 'F' : 'M';
        isLoading = false;
      });
    }
  }

  Future<void> updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isSaving = true;
      passwordError = '';
    });

    final String newEmail = emailCtrl.text.trim();
    final int activeId = (user != null && user!['id'] is int) ? user!['id'] as int : widget.userId;

    if (newEmail != (user?['email'] ?? '')) {
      final existingUser = await DBHelper.instance.getUserByEmail(newEmail);
      if (!mounted) return;
      if (existingUser != null && existingUser['id'] != activeId) {
        setState(() => isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This email is already registered to another account.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
    }

    Map<String, dynamic> updates = {
      'firstName': firstNameCtrl.text.trim(),
      'lastName': lastNameCtrl.text.trim(),
      'phone': phoneCtrl.text.trim(),
      'email': newEmail,
      'cnic': cnicCtrl.text.trim(),
      'gender': selectedGender,
      'city': cityCtrl.text.trim(),
      'street': streetCtrl.text.trim(),
    };

    bool passwordChanged = false;
    if (currentPasswordCtrl.text.isNotEmpty ||
        newPasswordCtrl.text.isNotEmpty ||
        confirmPasswordCtrl.text.isNotEmpty) {
      if (currentPasswordCtrl.text.isEmpty ||
          newPasswordCtrl.text.isEmpty ||
          confirmPasswordCtrl.text.isEmpty) {
        setState(() {
          passwordError = 'All password fields are required';
          isSaving = false;
        });
        return;
      }

      if (newPasswordCtrl.text != confirmPasswordCtrl.text) {
        setState(() {
          passwordError = 'New passwords do not match';
          isSaving = false;
        });
        return;
      }

      if (newPasswordCtrl.text.length < 6) {
        setState(() {
          passwordError = 'Password must be at least 6 characters';
          isSaving = false;
        });
        return;
      }

      if (user != null && user!['password'] != null && user!['password'] != currentPasswordCtrl.text) {
        setState(() {
          passwordError = 'Current password is incorrect';
          isSaving = false;
        });
        return;
      }

      updates['password'] = newPasswordCtrl.text;
      passwordChanged = true;

      // Update Firebase Auth password if logged in
      try {
        await FirebaseAuth.instance.currentUser?.updatePassword(newPasswordCtrl.text);
      } catch (e) {
        print("Firebase password update note: $e");
      }
    }

    // 1. Update SQLite
    try {
      if (activeId > 0) {
        await DBHelper.instance.updateUser(activeId, updates);
      }
    } catch (e) {
      print("SQLite update error: $e");
    }

    // 2. Update Supabase Profile
    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid ?? activeId.toString();
      await SupabaseService.instance.upsertUserProfile(
        firebaseUid: currentUid,
        email: newEmail,
        firstName: firstNameCtrl.text.trim(),
        lastName: lastNameCtrl.text.trim(),
        phone: phoneCtrl.text.trim(),
        cnic: cnicCtrl.text.trim(),
        gender: selectedGender,
        city: cityCtrl.text.trim(),
        street: streetCtrl.text.trim(),
      );
    } catch (e) {
      print("Supabase update profile error: $e");
    }

    if (!mounted) return;
    setState(() => isSaving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF16A34A),
        content: Text(
          passwordChanged
              ? 'Profile & password updated successfully!'
              : 'Profile updated successfully!',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );

    Navigator.pop(context, true);
  }

  @override
  void dispose() {
    firstNameCtrl.dispose();
    lastNameCtrl.dispose();
    phoneCtrl.dispose();
    emailCtrl.dispose();
    cnicCtrl.dispose();
    cityCtrl.dispose();
    streetCtrl.dispose();
    currentPasswordCtrl.dispose();
    newPasswordCtrl.dispose();
    confirmPasswordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: darkText,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: darkText, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryBlue))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // ─── PROFILE AVATAR BANNER ───
                    Center(
                      child: Stack(
                        children: [
                          Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [darkNavy, primaryBlue],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryBlue.withOpacity(0.25),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                firstNameCtrl.text.isNotEmpty
                                    ? firstNameCtrl.text[0].toUpperCase()
                                    : "U",
                                style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: primaryBlue,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(Icons.edit_rounded, color: Colors.white, size: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ─── PERSONAL INFORMATION CARD ───
                    _buildSectionCard(
                      title: "Personal Information",
                      icon: Icons.person_outline_rounded,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildInputField(
                                controller: firstNameCtrl,
                                label: 'First Name',
                                hint: 'e.g. Muhammad',
                                icon: Icons.person_outline_rounded,
                                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildInputField(
                                controller: lastNameCtrl,
                                label: 'Last Name',
                                hint: 'e.g. Ali',
                                icon: Icons.person_outline_rounded,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _buildInputField(
                          controller: phoneCtrl,
                          label: 'Phone Number',
                          hint: '0300 1234567',
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 14),
                        _buildInputField(
                          controller: emailCtrl,
                          label: 'Email Address',
                          hint: 'user@email.com',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Email is required';
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v)) {
                              return 'Enter a valid email address';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        _buildInputField(
                          controller: cnicCtrl,
                          label: 'CNIC Number',
                          hint: '35201-1234567-1',
                          icon: Icons.credit_card_outlined,
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 14),

                        // Gender Selector
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Gender",
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: darkText),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(10),
                                    onTap: () => setState(() => selectedGender = "M"),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      decoration: BoxDecoration(
                                        color: selectedGender == "M" ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: selectedGender == "M" ? primaryBlue : const Color(0xFFE2E8F0),
                                          width: selectedGender == "M" ? 1.5 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.man_rounded,
                                            size: 18,
                                            color: selectedGender == "M" ? primaryBlue : subText,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            "Male",
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: selectedGender == "M" ? primaryBlue : darkText,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(10),
                                    onTap: () => setState(() => selectedGender = "F"),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      decoration: BoxDecoration(
                                        color: selectedGender == "F" ? const Color(0xFFFDF2F8) : const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: selectedGender == "F" ? const Color(0xFFEC4899) : const Color(0xFFE2E8F0),
                                          width: selectedGender == "F" ? 1.5 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.woman_rounded,
                                            size: 18,
                                            color: selectedGender == "F" ? const Color(0xFFEC4899) : subText,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            "Female",
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: selectedGender == "F" ? const Color(0xFFEC4899) : darkText,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),
                        _buildInputField(
                          controller: cityCtrl,
                          label: 'City / Region',
                          hint: 'e.g. Lahore',
                          icon: Icons.location_city_outlined,
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ─── CHANGE PASSWORD CARD (OPTIONAL) ───
                    _buildSectionCard(
                      title: "Security & Password (Optional)",
                      icon: Icons.lock_outline_rounded,
                      children: [
                        _buildPasswordField(
                          controller: currentPasswordCtrl,
                          label: 'Current Password',
                          hint: 'Enter your existing password',
                          isObscure: _obscureCurrent,
                          onToggle: () => setState(() => _obscureCurrent = !_obscureCurrent),
                        ),
                        const SizedBox(height: 14),
                        _buildPasswordField(
                          controller: newPasswordCtrl,
                          label: 'New Password',
                          hint: 'Minimum 6 characters',
                          isObscure: _obscureNew,
                          onToggle: () => setState(() => _obscureNew = !_obscureNew),
                        ),
                        const SizedBox(height: 14),
                        _buildPasswordField(
                          controller: confirmPasswordCtrl,
                          label: 'Confirm New Password',
                          hint: 'Re-enter new password',
                          isObscure: _obscureConfirm,
                          onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                        ),

                        if (passwordError.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 16),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    passwordError,
                                    style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ─── SAVE / UPDATE BUTTON ───
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isSaving ? null : updateProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.save_rounded, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'Save Profile Changes',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: primaryBlue),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: darkText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: darkText),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: darkText),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
            prefixIcon: Icon(icon, size: 18, color: primaryBlue),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
              borderSide: const BorderSide(color: primaryBlue, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool isObscure,
    required VoidCallback onToggle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: darkText),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: isObscure,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: darkText),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: primaryBlue),
            suffixIcon: IconButton(
              icon: Icon(
                isObscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 18,
                color: subText,
              ),
              onPressed: onToggle,
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
              borderSide: const BorderSide(color: primaryBlue, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
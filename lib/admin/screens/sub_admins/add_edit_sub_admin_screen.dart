import 'package:flutter/material.dart';
import 'package:bus_ticket_system/database/db_helper.dart';
import 'package:bus_ticket_system/database/user_model.dart';

class AddEditSubAdminScreen extends StatefulWidget {
  final Map<String, dynamic>? existing;

  const AddEditSubAdminScreen({super.key, this.existing});

  @override
  State<AddEditSubAdminScreen> createState() => _AddEditSubAdminScreenState();
}

class _AddEditSubAdminScreenState extends State<AddEditSubAdminScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _fnameCtrl;
  late final TextEditingController _lnameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _passCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _terminalNameCtrl;

  String? _selectedCity;
  late String _status;
  bool _obscurePassword = true;
  bool _isSaving = false;

  static const Color primaryBlue = Color(0xFF388AF6);
  static const Color darkNavy = Color(0xFF1E3C72);
  static const Color darkText = Color(0xFF1E293B);
  static const Color subText = Color(0xFF64748B);
  static const Color bgSurface = Color(0xFFF8FAFC);
  static const Color borderColor = Color(0xFFE2E8F0);

  final List<String> cityList = const [
    "Lahore",
    "Islamabad",
    "Rawalpindi",
    "Karachi",
    "Faisalabad",
    "Multan",
    "Peshawar",
    "Quetta",
    "Sialkot",
    "Gujranwala",
    "Bahawalpur",
    "Sargodha",
    "Hyderabad",
    "Abbottabad",
    "Sahiwal",
    "Rahim Yar Khan",
    "Sukkur",
    "Gujrat",
    "Murree",
  ];

  bool get isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final data = widget.existing;
    _fnameCtrl = TextEditingController(text: data?['firstName'] ?? '');
    _lnameCtrl = TextEditingController(text: data?['lastName'] ?? '');
    _emailCtrl = TextEditingController(text: data?['email'] ?? '');
    _passCtrl = TextEditingController(text: data?['password'] ?? '');
    _phoneCtrl = TextEditingController(text: data?['phone'] ?? '');
    _terminalNameCtrl = TextEditingController(
      text: data?['terminalName'] ?? '',
    );

    final existingCity = data?['terminalCity'];
    if (existingCity != null && cityList.contains(existingCity)) {
      _selectedCity = existingCity;
    } else {
      _selectedCity = null;
    }

    _status = (data?['status'] ?? 'active').toString().toLowerCase();
  }

  @override
  void dispose() {
    _fnameCtrl.dispose();
    _lnameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _phoneCtrl.dispose();
    _terminalNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveSubAdmin() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCity == null || _selectedCity!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a city"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final email = _emailCtrl.text.trim().toLowerCase();

      // Duplicate email check when creating new or changing email
      if (!isEdit || (widget.existing?['email']?.toString().toLowerCase() != email)) {
        final existingUser = await DBHelper.instance.getUserByEmail(email);
        if (existingUser != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("A user or agent with this email already exists"),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
            setState(() => _isSaving = false);
          }
          return;
        }
      }

      final user = UserModel(
        id: isEdit ? (widget.existing!['id'] as int?) : null,
        firstName: _fnameCtrl.text.trim(),
        lastName: _lnameCtrl.text.trim(),
        email: email,
        phone: _phoneCtrl.text.trim(),
        cnic: widget.existing?['cnic'] ?? '',
        gender: widget.existing?['gender'] ?? 'Male',
        password: _passCtrl.text.trim(),
        role: 'sub_admin',
        terminalName: _terminalNameCtrl.text.trim().isEmpty
            ? 'Central Terminal'
            : _terminalNameCtrl.text.trim(),
        terminalCity: _selectedCity!,
        status: _status,
      );

      if (isEdit) {
        await DBHelper.instance.updateSubAdmin(widget.existing!['id'] as int, user);
      } else {
        await DBHelper.instance.insertSubAdmin(user);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEdit
                  ? "Terminal Agent updated successfully!"
                  : "Terminal Agent registered successfully!",
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint("Error saving agent: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to save: $e"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgSurface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: darkText, size: 19),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isEdit ? "Edit Terminal Agent" : "Register Terminal Agent",
          style: const TextStyle(
            color: darkText,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Top Hero Banner (Blue Card)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [darkNavy, primaryBlue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: primaryBlue.withAlpha(50),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(30),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEdit ? "Update Agent Credentials" : "Terminal POS Manager",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          isEdit
                              ? "Modify terminal assignment, credentials and status."
                              : "Create credentials for physical counter ticket bookings.",
                          style: TextStyle(
                            color: Colors.white.withAlpha(200),
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Form Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Section 1: Personal Info
                    _buildFormCard(
                      title: "Personal Information",
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _fnameCtrl,
                                label: "First Name",
                                validator: (v) =>
                                    v == null || v.trim().isEmpty ? "Required" : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextField(
                                controller: _lnameCtrl,
                                label: "Last Name",
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          controller: _phoneCtrl,
                          label: "Contact Number",
                          keyboardType: TextInputType.phone,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return "Required";
                            if (v.trim().length < 10) return "Invalid phone number";
                            return null;
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Section 2: City & Terminal
                    _buildFormCard(
                      title: "Terminal Assignment",
                      children: [
                        // City Dropdown
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "City",
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: darkText,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: bgSurface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: borderColor),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedCity,
                                  isExpanded: true,
                                  hint: const Text(
                                    "Select City",
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF94A3B8),
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: primaryBlue, size: 20),
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: darkText,
                                  ),
                                  items: cityList.map((city) {
                                    return DropdownMenuItem<String>(
                                      value: city,
                                      child: Text(city),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) setState(() => _selectedCity = val);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Terminal
                        _buildTextField(
                          controller: _terminalNameCtrl,
                          label: "Terminal",
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? "Terminal required" : null,
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Section 3: Credentials
                    _buildFormCard(
                      title: "Login Credentials",
                      children: [
                        _buildTextField(
                          controller: _emailCtrl,
                          label: "Login Email",
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return "Email is required";
                            if (!v.contains('@') || !v.contains('.')) return "Enter a valid email";
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          controller: _passCtrl,
                          label: "Password",
                          obscureText: _obscurePassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: subText,
                              size: 18,
                            ),
                            onPressed: () {
                              setState(() => _obscurePassword = !_obscurePassword);
                            },
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return "Password required";
                            if (v.trim().length < 4) return "Min 4 chars";
                            return null;
                          },
                        ),
                        if (isEdit) ...[
                          const SizedBox(height: 12),
                          const Divider(color: borderColor),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Account Status",
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: darkText,
                                    ),
                                  ),
                                  Text(
                                    _status == 'active'
                                        ? "Active - Agent can log in"
                                        : "Suspended",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: _status == 'active' ? const Color(0xFF10B981) : Colors.red,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              Switch(
                                value: _status == 'active',
                                activeThumbColor: const Color(0xFF10B981),
                                onChanged: (val) {
                                  setState(() {
                                    _status = val ? 'active' : 'suspended';
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _isSaving ? null : _saveSubAdmin,
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                isEdit ? "Update Agent" : "Register Agent",
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(4),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: darkText,
            ),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: borderColor),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: darkText,
          ),
        ),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          validator: validator,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: darkText),
          decoration: InputDecoration(
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: bgSurface,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: primaryBlue, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.red, width: 1),
            ),
          ),
        ),
      ],
    );
  }
}

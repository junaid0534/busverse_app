import 'package:flutter/material.dart';
import 'package:bus_ticket_system/database/db_helper.dart';

class AddEditDriverScreen extends StatefulWidget {
  final Map<String, dynamic>? existingDriver;

  const AddEditDriverScreen({super.key, this.existingDriver});

  @override
  State<AddEditDriverScreen> createState() => _AddEditDriverScreenState();
}

class _AddEditDriverScreenState extends State<AddEditDriverScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _firstNameCtrl;
  late TextEditingController _lastNameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _passwordCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _cnicCtrl;
  late TextEditingController _licenseCtrl;

  List<Map<String, dynamic>> _buses = [];
  Map<String, dynamic>? _selectedBus;
  String _status = 'active';
  bool _isLoading = false;
  bool _obscurePass = true;

  static const Color primaryBlue = Color(0xFF388AF6);
  static const Color darkText = Color(0xFF1E293B);
  static const Color subText = Color(0xFF64748B);

  bool get isEdit => widget.existingDriver != null;

  @override
  void initState() {
    super.initState();
    final d = widget.existingDriver ?? {};
    _firstNameCtrl = TextEditingController(text: d['firstName'] ?? d['first_name'] ?? '');
    _lastNameCtrl = TextEditingController(text: d['lastName'] ?? d['last_name'] ?? '');
    _emailCtrl = TextEditingController(text: d['email'] ?? '');
    _passwordCtrl = TextEditingController(text: d['password'] ?? '');
    _phoneCtrl = TextEditingController(text: d['phone'] ?? '');
    _cnicCtrl = TextEditingController(text: d['cnic'] ?? '');
    _licenseCtrl = TextEditingController(text: d['licenseNo'] ?? d['license_no'] ?? '');
    _status = (d['status'] ?? 'active').toString().toLowerCase();

    _loadBuses();
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneCtrl.dispose();
    _cnicCtrl.dispose();
    _licenseCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBuses() async {
    try {
      final list = await DBHelper.instance.getAllBuses();
      if (mounted) {
        setState(() {
          _buses = list;
          if (isEdit && widget.existingDriver != null) {
            final assignedId = widget.existingDriver!['assignedBusId'] ?? widget.existingDriver!['assigned_bus_id'];
            final assignedNum = widget.existingDriver!['assignedBusNumber'] ?? widget.existingDriver!['assigned_bus_number'];
            _selectedBus = _buses.where((b) => b['id'].toString() == assignedId.toString() || b['busNumber'] == assignedNum).firstOrNull;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _saveDriver() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailCtrl.text.trim().toLowerCase();

      // Check duplicate email
      if (!isEdit || (widget.existingDriver?['email']?.toString().toLowerCase() != email)) {
        final existing = await DBHelper.instance.getUserByEmail(email);
        if (existing != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("A user or driver with this email already exists"),
                backgroundColor: Colors.redAccent,
              ),
            );
            setState(() => _isLoading = false);
          }
          return;
        }
      }

      final busId = _selectedBus?['id']?.toString() ?? '';
      final busNumber = _selectedBus?['busNumber'] ?? _selectedBus?['bus_number'] ?? '';
      final route = "${_selectedBus?['fromCity'] ?? ''} - ${_selectedBus?['toCity'] ?? ''}".trim();

      final payload = {
        'first_name': _firstNameCtrl.text.trim(),
        'last_name': _lastNameCtrl.text.trim(),
        'email': email,
        'password': _passwordCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'cnic': _cnicCtrl.text.trim(),
        'role': 'driver',
        'status': _status,
        'license_no': _licenseCtrl.text.trim().isNotEmpty ? _licenseCtrl.text.trim() : 'HTV-Verified',
        'assigned_bus_id': busId,
        'assigned_bus_number': busNumber,
        'assigned_route': route,
        'region': _licenseCtrl.text.trim(),
        'street': busId,
        'zip': busNumber,
        'city': route,
      };

      if (isEdit) {
        await DBHelper.instance.updateDriver(widget.existingDriver!['id'], payload);
      } else {
        await DBHelper.instance.insertDriver(payload);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEdit ? "Captain updated successfully!" : "Captain registered successfully!"),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save: $e"), backgroundColor: Colors.redAccent),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: darkText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isEdit ? "Edit Captain / Driver" : "Register New Driver",
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: darkText),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: primaryBlue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: primaryBlue.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.admin_panel_settings_rounded, color: primaryBlue, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Admin Controlled Login",
                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: darkText),
                          ),
                          Text(
                            "The driver will use this Email & Password to log in directly into Driver Trip Mode.",
                            style: TextStyle(fontSize: 11.5, color: subText),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Names
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _firstNameCtrl,
                      label: "First Name",
                      hint: "e.g. Muhammad",
                      icon: Icons.person_rounded,
                      validator: (v) => v!.trim().isEmpty ? "Required" : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      controller: _lastNameCtrl,
                      label: "Last Name",
                      hint: "e.g. Aslam",
                      icon: Icons.person_outline_rounded,
                      validator: (v) => v!.trim().isEmpty ? "Required" : null,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Email & Password
              _buildTextField(
                controller: _emailCtrl,
                label: "Driver Login Email",
                hint: "e.g. driver.aslam@busverse.com",
                icon: Icons.email_rounded,
                keyboardType: TextInputType.emailAddress,
                validator: (v) => !v!.contains('@') ? "Valid email required" : null,
              ),

              const SizedBox(height: 14),

              _buildTextField(
                controller: _passwordCtrl,
                label: "Driver Login Password",
                hint: "Set secure password (e.g. Pass@123)",
                icon: Icons.lock_rounded,
                obscureText: _obscurePass,
                suffixIcon: IconButton(
                  icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility, size: 18, color: subText),
                  onPressed: () => setState(() => _obscurePass = !_obscurePass),
                ),
                validator: (v) => v!.length < 4 ? "Min 4 characters" : null,
              ),

              const SizedBox(height: 14),

              // Phone & CNIC
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _phoneCtrl,
                      label: "Phone Number",
                      hint: "0300-1234567",
                      icon: Icons.phone_rounded,
                      keyboardType: TextInputType.phone,
                      validator: (v) => v!.trim().isEmpty ? "Required" : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      controller: _cnicCtrl,
                      label: "CNIC Number",
                      hint: "35201-1234567-1",
                      icon: Icons.badge_rounded,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Commercial License No.
              _buildTextField(
                controller: _licenseCtrl,
                label: "HTV Commercial License No.",
                hint: "e.g. LHR-HTV-984321",
                icon: Icons.card_membership_rounded,
              ),

              const SizedBox(height: 18),

              // Assigned Fleet Bus Selector
              const Text(
                "Assign Fleet Bus",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: darkText),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<Map<String, dynamic>>(
                    value: _selectedBus,
                    isExpanded: true,
                    hint: const Text("Select Bus for this Driver", style: TextStyle(fontSize: 13, color: subText)),
                    items: _buses.map((bus) {
                      final bNum = bus['busNumber'] ?? bus['bus_number'] ?? '';
                      final from = bus['fromCity'] ?? bus['from_city'] ?? '';
                      final to = bus['toCity'] ?? bus['to_city'] ?? '';
                      final bClass = bus['busClass'] ?? bus['bus_class'] ?? '';
                      return DropdownMenuItem(
                        value: bus,
                        child: Text(
                          "$bNum ($from ➔ $to) • $bClass",
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: darkText),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedBus = val),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Status Dropdown
              const Text(
                "Account Status",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: darkText),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _status,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'active', child: Text("Active (Can Login & Drive)", style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w600))),
                      DropdownMenuItem(value: 'suspended', child: Text("Suspended (Blocked from Login)", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600))),
                    ],
                    onChanged: (val) => setState(() => _status = val ?? 'active'),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _isLoading ? null : _saveDriver,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      : Text(
                          isEdit ? "Update Captain Profile" : "Register Driver Account",
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: darkText)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          validator: validator,
          style: const TextStyle(fontSize: 13.5, color: darkText),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 12.5, color: subText),
            prefixIcon: Icon(icon, size: 18, color: subText),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primaryBlue, width: 1.5)),
          ),
        ),
      ],
    );
  }
}

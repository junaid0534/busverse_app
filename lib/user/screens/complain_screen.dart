import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../database/db_helper.dart';
import '../../services/supabase_service.dart';

class ComplainScreen extends StatefulWidget {
  final int userId;

  const ComplainScreen({super.key, required this.userId});

  @override
  State<ComplainScreen> createState() => _ComplainScreenState();
}

class _ComplainScreenState extends State<ComplainScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _detailsController = TextEditingController();
  final TextEditingController _busNumberController = TextEditingController();

  String _selectedCategory = "Bus Delay";
  final List<String> _categories = [
    "Bus Delay",
    "AC / Climate Issue",
    "Ticket / Refund",
    "Staff Behavior",
    "Luggage Problem",
    "Overcharging",
    "Other",
  ];

  bool _isSubmitting = false;
  List<Map<String, dynamic>> _myComplaints = [];
  bool _isLoadingComplaints = true;

  static const Color primaryBlue = Color(0xFF388AF6);
  static const Color darkText = Color(0xFF1E293B);
  static const Color subText = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserComplaints();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _detailsController.dispose();
    _busNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadUserComplaints() async {
    setState(() => _isLoadingComplaints = true);
    List<Map<String, dynamic>> list = [];

    // SQLite fetch
    try {
      final all = await DBHelper.instance.getAllComplains();
      list = all.where((c) => c['userId'] == widget.userId || widget.userId == 0).toList();
    } catch (_) {}

    if (mounted) {
      setState(() {
        _myComplaints = list;
        _isLoadingComplaints = false;
      });
    }
  }

  Future<void> _submitComplaint() async {
    final details = _detailsController.text.trim();
    if (details.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please write the complaint details"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final busInfo = _busNumberController.text.trim();
    final String fullMessage = "[$_selectedCategory] ${busInfo.isNotEmpty ? 'Bus/Ref: $busInfo | ' : ''}$details";
    final String userEmail = FirebaseAuth.instance.currentUser?.email ?? "User#${widget.userId}";

    // 1. Supabase Cloud Sync
    try {
      await SupabaseService.instance.addComplain(userEmail, fullMessage);
    } catch (e) {
      print("Supabase complain error: $e");
    }

    // 2. Local SQLite Sync
    try {
      await DBHelper.instance.insertComplain(userId: widget.userId, message: fullMessage);
    } catch (e) {
      print("SQLite complain error: $e");
    }

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _detailsController.clear();
      _busNumberController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Complaint submitted successfully. Reference ticket generated."),
        backgroundColor: Color(0xFF16A34A),
      ),
    );

    _loadUserComplaints();
    _tabController.animateTo(1); // Switch to "My Complaints" tab
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: darkText, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Complaints Center",
          style: TextStyle(color: darkText, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFDC2626),
          unselectedLabelColor: subText,
          indicatorColor: const Color(0xFFDC2626),
          indicatorWeight: 2.5,
          labelStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: "Register Complaint"),
            Tab(text: "My Complaints"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ─── TAB 1: REGISTER COMPLAINT FORM ───
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Banner
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.shield_outlined, color: Color(0xFFDC2626), size: 22),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "We take service quality seriously. Your complaint will be reviewed by Junaid Movers management within 24 hours.",
                          style: TextStyle(fontSize: 12, color: Color(0xFF991B1B), height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Category Selection
                const Text(
                  "Select Complaint Category",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: darkText),
                ),
                const SizedBox(height: 10),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _categories.map((cat) {
                    final isSel = _selectedCategory == cat;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedCategory = cat),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSel ? const Color(0xFFFEF2F2) : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSel ? const Color(0xFFEF4444) : const Color(0xFFE2E8F0),
                            width: isSel ? 1.5 : 1,
                          ),
                        ),
                        child: Text(
                          cat,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isSel ? const Color(0xFFDC2626) : darkText,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 18),

                // Bus / Ticket Number (Optional)
                const Text(
                  "Bus Number or Ticket Reference (Optional)",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: darkText),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _busNumberController,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: "e.g. JND-101 or Ref: BV-8921",
                    hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.confirmation_number_outlined, size: 18, color: primaryBlue),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: primaryBlue, width: 1.5)),
                  ),
                ),

                const SizedBox(height: 16),

                // Complaint Details
                const Text(
                  "Detailed Complaint Description",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: darkText),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _detailsController,
                  maxLines: 5,
                  style: const TextStyle(fontSize: 13.5),
                  decoration: InputDecoration(
                    hintText: "Please describe what happened in detail (time, location, conductor/driver behavior, specific issue)...",
                    hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.all(14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: primaryBlue, width: 1.5)),
                  ),
                ),

                const SizedBox(height: 24),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitComplaint,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text("Submit Official Complaint", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),

          // ─── TAB 2: MY COMPLAINTS LIST ───
          RefreshIndicator(
            color: const Color(0xFFDC2626),
            onRefresh: _loadUserComplaints,
            child: _isLoadingComplaints
                ? const Center(child: CircularProgressIndicator(color: primaryBlue))
                : _myComplaints.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        itemCount: _myComplaints.length,
                        itemBuilder: (context, index) {
                          return _buildComplaintCard(_myComplaints[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildComplaintCard(Map<String, dynamic> c) {
    final raw = c['message'] ?? '';
    final date = c['date'] ?? '';

    String cat = "Complaint";
    String details = raw;
    if (raw.startsWith('[')) {
      final close = raw.indexOf(']');
      if (close != -1) {
        cat = raw.substring(1, close);
        details = raw.substring(close + 1).trim();
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  cat,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFDC2626)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.access_time_rounded, size: 12, color: Color(0xFFD97706)),
                    SizedBox(width: 4),
                    Text(
                      "UNDER REVIEW",
                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFFD97706)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            details,
            style: const TextStyle(fontSize: 13, color: darkText, fontWeight: FontWeight.w600, height: 1.3),
          ),
          const SizedBox(height: 10),
          const Divider(color: Color(0xFFF1F5F9), height: 1),
          const SizedBox(height: 8),
          Text(
            "Submitted on: $date",
            style: const TextStyle(fontSize: 11, color: subText),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.done_all_rounded, size: 54, color: Color(0xFF16A34A)),
            SizedBox(height: 14),
            Text("No Complaints Found", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: darkText)),
            SizedBox(height: 4),
            Text("You have not submitted any complaints yet.", style: TextStyle(fontSize: 12, color: subText)),
          ],
        ),
      ),
    );
  }
}

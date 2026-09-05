import 'package:flutter/material.dart';
import '../../database/db_helper.dart';

class AdminComplainsScreen extends StatefulWidget {
  const AdminComplainsScreen({super.key});

  @override
  State<AdminComplainsScreen> createState() => _AdminComplainsScreenState();
}

class _AdminComplainsScreenState extends State<AdminComplainsScreen> {
  List<Map<String, dynamic>> complainList = [];
  bool isLoading = true;

  static const Color primaryBlue = Color(0xFF388AF6);
  static const Color darkText = Color(0xFF1E293B);
  static const Color subText = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    final complains = await DBHelper.instance.getAllComplains();
    if (mounted) {
      setState(() {
        complainList = complains;
        isLoading = false;
      });
    }
  }

  Future<void> _refresh() async {
    setState(() => isLoading = true);
    await fetchData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          "Customer Complaints",
          style: TextStyle(color: darkText, fontSize: 18, fontWeight: FontWeight.w700),
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
          : complainList.isEmpty
              ? _buildEmptyState(
                  icon: Icons.check_circle_outline_rounded,
                  title: "No Open Complaints",
                  subtitle: "Great job! There are no customer complaints reported.",
                )
              : RefreshIndicator(
                  onRefresh: _refresh,
                  color: primaryBlue,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    itemCount: complainList.length,
                    itemBuilder: (context, index) {
                      final item = complainList[index];
                      return _modernComplainCard(item);
                    },
                  ),
                ),
    );
  }

  Widget _modernComplainCard(Map<String, dynamic> item) {
    final String rawMsg = item['message'] ?? 'No message';
    final String date = item['date'] ?? '';
    final String userId = (item['userId'] ?? 'Guest').toString();

    // Extract category if enclosed in brackets e.g. [Bus Delay]
    String category = "General Complaint";
    String bodyMsg = rawMsg;
    if (rawMsg.startsWith('[')) {
      final closeIdx = rawMsg.indexOf(']');
      if (closeIdx != -1) {
        category = rawMsg.substring(1, closeIdx);
        bodyMsg = rawMsg.substring(closeIdx + 1).trim();
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
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
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
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.report_problem_rounded, color: Color(0xFFDC2626), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      category,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFDC2626)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  "User #$userId",
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: primaryBlue),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            bodyMsg,
            style: const TextStyle(fontSize: 13.5, color: darkText, fontWeight: FontWeight.w600, height: 1.3),
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFFF1F5F9), height: 1),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.access_time_rounded, size: 13, color: subText),
                  const SizedBox(width: 4),
                  Text(date, style: const TextStyle(fontSize: 11, color: subText)),
                ],
              ),
              const Row(
                children: [
                  Icon(Icons.pending_actions_rounded, size: 14, color: Color(0xFFD97706)),
                  SizedBox(width: 4),
                  Text(
                    "Action Required",
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFD97706)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 50, color: const Color(0xFF16A34A)),
            ),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 17, color: darkText, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, color: subText)),
          ],
        ),
      ),
    );
  }
}
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
    final String email = (item['user_email'] ?? item['userEmail'] ?? item['email'] ?? '').toString().trim();
    final String userBadge = email.isNotEmpty
        ? email
        : ((item['userId'] != null && item['userId'].toString().isNotEmpty && item['userId'].toString() != '0')
            ? "User #${item['userId']}"
            : "Valued Customer");

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

    // Extract admin reply & status
    final String rawAdminReply = (item['admin_reply'] ?? item['adminReply'] ?? '').toString().trim();
    String currentStatus = (item['status'] ?? 'Pending').toString();
    String adminReply = (rawAdminReply.toLowerCase() == 'null') ? '' : rawAdminReply;

    if (adminReply.isEmpty && bodyMsg.contains('\n[Admin Response')) {
      final idx = bodyMsg.indexOf('\n[Admin Response');
      final substring = bodyMsg.substring(idx);
      bodyMsg = bodyMsg.substring(0, idx).trim();

      if (substring.contains(']:')) {
        final colonIdx = substring.indexOf(']:');
        final header = substring.substring(0, colonIdx);
        if (header.contains('-')) {
          currentStatus = header.split('-').last.trim();
        }
        adminReply = substring.substring(colonIdx + 2).trim();
      }
    }

    if (adminReply.toLowerCase() == 'null') adminReply = '';
    if (bodyMsg.toLowerCase() == 'null') bodyMsg = '';
    if (currentStatus.toLowerCase() == 'null') currentStatus = 'Pending';

    final bool isResolved = currentStatus.toLowerCase() == 'resolved';
    final bool isInProgress = currentStatus.toLowerCase() == 'in progress' || currentStatus.toLowerCase() == 'investigating';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
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
                  userBadge,
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

          // Admin Response & Resolution Box
          if (adminReply.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isResolved ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isResolved ? const Color(0xFFBBF7D0) : const Color(0xFFFDE68A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isResolved ? Icons.check_circle_rounded : Icons.sync_problem_rounded,
                            color: isResolved ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                            size: 15,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            "Admin Resolution ($currentStatus)",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isResolved ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                            ),
                          ),
                        ],
                      ),
                      InkWell(
                        onTap: () => _openReplyModal(item, currentReply: adminReply, currentStatus: currentStatus, cleanBody: bodyMsg),
                        child: const Text(
                          "Update",
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: primaryBlue),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    adminReply,
                    style: const TextStyle(fontSize: 12.5, color: darkText, height: 1.35),
                  ),
                ],
              ),
            ),
          ],

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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: isResolved
                          ? const Color(0xFFDCFCE7)
                          : (isInProgress ? const Color(0xFFFEF3C7) : const Color(0xFFFEE2E2)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isResolved ? "Resolved" : (isInProgress ? "In Progress" : "Pending"),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isResolved
                            ? const Color(0xFF16A34A)
                            : (isInProgress ? const Color(0xFFD97706) : const Color(0xFFDC2626)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _openReplyModal(item, currentReply: adminReply, currentStatus: currentStatus, cleanBody: bodyMsg),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: primaryBlue.withAlpha(20),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: primaryBlue.withAlpha(40)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.reply_rounded, size: 13, color: primaryBlue),
                          const SizedBox(width: 4),
                          Text(
                            adminReply.isNotEmpty ? "Update Reply" : "Reply / Action",
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: primaryBlue),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openReplyModal(
    Map<String, dynamic> item, {
    String currentReply = '',
    String currentStatus = 'Resolved',
    String cleanBody = '',
  }) {
    final int? id = item['id'] is int ? item['id'] as int : int.tryParse(item['id']?.toString() ?? '');
    if (id == null) return;

    final String email = (item['user_email'] ?? item['userEmail'] ?? item['email'] ?? '').toString().trim();
    final String origMsg = item['message'] ?? cleanBody;
    final TextEditingController replyController = TextEditingController(text: currentReply);
    String selectedStatus = currentStatus.isNotEmpty && currentStatus != 'Pending' ? currentStatus : 'Resolved';
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Row(
                children: [
                  Icon(Icons.support_agent_rounded, color: primaryBlue, size: 22),
                  SizedBox(width: 8),
                  Text(
                    "Resolve & Reply to Complaint",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: darkText),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      email.isNotEmpty ? email : "Customer",
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: subText),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      cleanBody.isNotEmpty ? cleanBody : origMsg,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, color: darkText, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                "Update Complaint Status:",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: subText),
              ),
              const SizedBox(height: 6),
              Row(
                children: ["Resolved", "In Progress", "Investigating"].map((status) {
                  final isSel = selectedStatus.toLowerCase() == status.toLowerCase();
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(status),
                      selected: isSel,
                      selectedColor: status == "Resolved" ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                      backgroundColor: const Color(0xFFF1F5F9),
                      labelStyle: TextStyle(
                        fontSize: 11.5,
                        fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                        color: isSel
                            ? (status == "Resolved" ? const Color(0xFF16A34A) : const Color(0xFFD97706))
                            : darkText,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: isSel
                              ? (status == "Resolved" ? const Color(0xFF16A34A) : const Color(0xFFD97706))
                              : const Color(0xFFCBD5E1),
                        ),
                      ),
                      onSelected: (_) => setModalState(() => selectedStatus = status),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: replyController,
                minLines: 3,
                maxLines: 6,
                decoration: InputDecoration(
                  hintText: "Enter the resolution details or response for the passenger...",
                  hintStyle: const TextStyle(fontSize: 13, color: subText),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: primaryBlue, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          final text = replyController.text.trim();
                          if (text.isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text("Please enter a response/resolution message")),
                            );
                            return;
                          }

                          setModalState(() => isSaving = true);
                          final scaffoldMessenger = ScaffoldMessenger.of(context);
                          final nav = Navigator.of(ctx);

                          final success = await DBHelper.instance.replyToComplain(
                            complainId: id,
                            replyText: text,
                            status: selectedStatus,
                            userEmail: email,
                            originalMessage: origMsg,
                          );

                          if (mounted) {
                            nav.pop();
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text(success ? "Response sent & user notified! ✨" : "Response saved"),
                                backgroundColor: const Color(0xFF16A34A),
                              ),
                            );
                            _refresh();
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          "Send Resolution & Notify User",
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),
        ),
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
              decoration: const BoxDecoration(
                color: Color(0xFFDCFCE7),
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
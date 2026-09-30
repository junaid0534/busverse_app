import 'package:flutter/material.dart';
import '../../database/db_helper.dart';

class AdminFeedbackScreen extends StatefulWidget {
  const AdminFeedbackScreen({super.key});

  @override
  State<AdminFeedbackScreen> createState() => _AdminFeedbackScreenState();
}

class _AdminFeedbackScreenState extends State<AdminFeedbackScreen> {
  List<Map<String, dynamic>> feedbackList = [];
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
    final feedbacks = await DBHelper.instance.getAllFeedbacks();
    if (mounted) {
      setState(() {
        feedbackList = feedbacks;
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
          "Customer Reviews & Ratings",
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
          : feedbackList.isEmpty
              ? _buildEmptyState(
                  icon: Icons.reviews_outlined,
                  title: "No Feedbacks Yet",
                  subtitle: "Customer reviews and travel feedback will appear here.",
                )
              : RefreshIndicator(
                  onRefresh: _refresh,
                  color: primaryBlue,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    itemCount: feedbackList.length,
                    itemBuilder: (context, index) {
                      final item = feedbackList[index];
                      return _modernFeedbackCard(item);
                    },
                  ),
                ),
    );
  }

  Widget _modernFeedbackCard(Map<String, dynamic> item) {
    final String rawMsg = item['message'] ?? 'No message';
    final String date = item['date'] ?? '';
    final String email = (item['user_email'] ?? item['userEmail'] ?? item['email'] ?? '').toString().trim();
    final String userBadge = email.isNotEmpty
        ? email
        : ((item['userId'] != null && item['userId'].toString().isNotEmpty && item['userId'].toString() != '0')
            ? "User #${item['userId']}"
            : "Valued Customer");

    // Extract stars if enclosed in brackets e.g. [5 Stars]
    int starCount = 5;
    String bodyMsg = rawMsg;
    if (rawMsg.startsWith('[')) {
      final closeIdx = rawMsg.indexOf(']');
      if (closeIdx != -1) {
        final prefix = rawMsg.substring(1, closeIdx);
        starCount = int.tryParse(prefix.split(' ').first) ?? 5;
        bodyMsg = rawMsg.substring(closeIdx + 1).trim();
      }
    }

    // Extract admin reply
    final String rawAdminReply = (item['admin_reply'] ?? item['adminReply'] ?? '').toString().trim();
    String adminReply = (rawAdminReply.toLowerCase() == 'null') ? '' : rawAdminReply;
    if (adminReply.isEmpty && bodyMsg.contains('\n[Admin Response]:')) {
      final parts = bodyMsg.split('\n[Admin Response]:');
      if (parts.length > 1) {
        adminReply = parts.sublist(1).join('\n[Admin Response]:').trim();
      }
    }
    if (bodyMsg.contains('\n[Admin Response]:')) {
      bodyMsg = bodyMsg.split('\n[Admin Response]:').first.trim();
    }
    if (adminReply.toLowerCase() == 'null') adminReply = '';
    if (bodyMsg.toLowerCase() == 'null') bodyMsg = '';

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
              Row(
                children: List.generate(5, (index) {
                  return Icon(
                    index < starCount ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: const Color(0xFFEAB308),
                    size: 18,
                  );
                }),
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
          const SizedBox(height: 10),
          Text(
            bodyMsg,
            style: const TextStyle(fontSize: 13.5, color: darkText, fontWeight: FontWeight.w600, height: 1.3),
          ),

          // Admin Response Box if exists
          if (adminReply.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.verified_user_rounded, color: Color(0xFF16A34A), size: 14),
                          SizedBox(width: 5),
                          Text(
                            "Admin Response",
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF16A34A)),
                          ),
                        ],
                      ),
                      InkWell(
                        onTap: () => _openReplyModal(item, currentReply: adminReply, cleanBody: bodyMsg),
                        child: const Text(
                          "Edit",
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
              if (adminReply.isEmpty)
                InkWell(
                  onTap: () => _openReplyModal(item, currentReply: "", cleanBody: bodyMsg),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: primaryBlue.withAlpha(20),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: primaryBlue.withAlpha(40)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.reply_rounded, size: 13, color: primaryBlue),
                        SizedBox(width: 4),
                        Text(
                          "Reply to User",
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: primaryBlue),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _openReplyModal(Map<String, dynamic> item, {String currentReply = '', String cleanBody = ''}) {
    final int? id = item['id'] is int ? item['id'] as int : int.tryParse(item['id']?.toString() ?? '');
    if (id == null) return;

    final String email = (item['user_email'] ?? item['userEmail'] ?? item['email'] ?? '').toString().trim();
    final String origMsg = item['message'] ?? cleanBody;
    final TextEditingController replyController = TextEditingController(text: currentReply);
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
              Row(
                children: [
                  const Icon(Icons.reply_rounded, color: primaryBlue, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    currentReply.isNotEmpty ? "Edit Admin Response" : "Reply to Customer Review",
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: darkText),
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
              TextField(
                controller: replyController,
                minLines: 3,
                maxLines: 6,
                decoration: InputDecoration(
                  hintText: "Write a helpful and polite response to the customer...",
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
                              const SnackBar(content: Text("Please enter a reply message")),
                            );
                            return;
                          }

                          setModalState(() => isSaving = true);
                          final scaffoldMessenger = ScaffoldMessenger.of(context);
                          final nav = Navigator.of(ctx);

                          final success = await DBHelper.instance.replyToFeedback(
                            feedbackId: id,
                            replyText: text,
                            userEmail: email,
                            originalMessage: origMsg,
                          );

                          if (mounted) {
                            nav.pop();
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text(success ? "Reply sent & user notified! ✨" : "Reply saved"),
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
                          "Send Response",
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
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
                color: Color(0xFFFEFCE8),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 50, color: const Color(0xFFEAB308)),
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
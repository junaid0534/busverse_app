import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../database/db_helper.dart';
import '../../services/supabase_service.dart';

class FeedbackScreen extends StatefulWidget {
  final int userId;

  const FeedbackScreen({super.key, required this.userId});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _feedbackController = TextEditingController();

  int _rating = 5;
  String _selectedAspect = "Overall Travel Experience";
  final List<String> _aspects = [
    "Overall Travel Experience",
    "Bus Cleanliness & Comfort",
    "Punctuality & Timings",
    "Driver & Staff Service",
    "App & Booking Ease",
  ];

  bool _isSubmitting = false;
  List<Map<String, dynamic>> _myFeedbacks = [];
  bool _isLoadingFeedbacks = true;

  static const Color primaryBlue = Color(0xFF388AF6);
  static const Color darkText = Color(0xFF1E293B);
  static const Color subText = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserFeedbacks();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _loadUserFeedbacks() async {
    setState(() => _isLoadingFeedbacks = true);
    List<Map<String, dynamic>> list = [];

    // SQLite fetch
    try {
      final all = await DBHelper.instance.getAllFeedbacks();
      list = all.where((f) => f['userId'] == widget.userId || widget.userId == 0).toList();
    } catch (_) {}

    if (mounted) {
      setState(() {
        _myFeedbacks = list;
        _isLoadingFeedbacks = false;
      });
    }
  }

  Future<void> _submitFeedback() async {
    final text = _feedbackController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please write a few words of review"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final String fullMessage = "[$_rating Stars | $_selectedAspect] $text";
    final String userEmail = FirebaseAuth.instance.currentUser?.email ?? "User#${widget.userId}";

    // 1. Supabase Cloud Sync
    try {
      await SupabaseService.instance.addFeedback(userEmail, fullMessage);
    } catch (e) {
      print("Supabase feedback error: $e");
    }

    // 2. Local SQLite Sync
    try {
      await DBHelper.instance.insertFeedback(userId: widget.userId, message: fullMessage);
    } catch (e) {
      print("SQLite feedback error: $e");
    }

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _feedbackController.clear();
      _rating = 5;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Thank you for your feedback! ⭐"),
        backgroundColor: Color(0xFF16A34A),
      ),
    );

    _loadUserFeedbacks();
    _tabController.animateTo(1); // Switch to "My Reviews" tab
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
          "Ratings & Feedback",
          style: TextStyle(color: darkText, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: primaryBlue,
          unselectedLabelColor: subText,
          indicatorColor: primaryBlue,
          indicatorWeight: 2.5,
          labelStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: "Write Review"),
            Tab(text: "My Reviews"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ─── TAB 1: WRITE REVIEW FORM ───
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Star Rating Header Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        "How was your journey with BusVerse?",
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: darkText),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        "Tap the stars to rate your overall experience",
                        style: TextStyle(fontSize: 12, color: subText),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          final star = index + 1;
                          return IconButton(
                            iconSize: 40,
                            icon: Icon(
                              star <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                              color: const Color(0xFFEAB308),
                            ),
                            onPressed: () => setState(() => _rating = star),
                          );
                        }),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getRatingLabel(_rating),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFCA8A04)),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Aspect Selection
                const Text(
                  "What would you like to highlight?",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: darkText),
                ),
                const SizedBox(height: 10),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _aspects.map((asp) {
                    final isSel = _selectedAspect == asp;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedAspect = asp),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSel ? const Color(0xFFEFF6FF) : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSel ? primaryBlue : const Color(0xFFE2E8F0),
                            width: isSel ? 1.5 : 1,
                          ),
                        ),
                        child: Text(
                          asp,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isSel ? primaryBlue : darkText,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 18),

                // Comments input
                const Text(
                  "Your Review / Suggestions",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: darkText),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _feedbackController,
                  maxLines: 4,
                  style: const TextStyle(fontSize: 13.5),
                  decoration: InputDecoration(
                    hintText: "Tell us what you liked or what we can improve for your next trip...",
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
                    onPressed: _isSubmitting ? null : _submitFeedback,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text("Submit Review", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),

          // ─── TAB 2: MY REVIEWS LIST ───
          RefreshIndicator(
            color: primaryBlue,
            onRefresh: _loadUserFeedbacks,
            child: _isLoadingFeedbacks
                ? const Center(child: CircularProgressIndicator(color: primaryBlue))
                : _myFeedbacks.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        itemCount: _myFeedbacks.length,
                        itemBuilder: (context, index) {
                          return _buildFeedbackCard(_myFeedbacks[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  String _getRatingLabel(int r) {
    switch (r) {
      case 5:
        return "⭐⭐⭐⭐⭐ Excellent Journey";
      case 4:
        return "⭐⭐⭐⭐ Very Good";
      case 3:
        return "⭐⭐⭐ Average Experience";
      case 2:
        return "⭐⭐ Below Expectations";
      default:
        return "⭐ Poor Experience";
    }
  }

  Widget _buildFeedbackCard(Map<String, dynamic> f) {
    final raw = f['message'] ?? '';
    final date = f['date'] ?? '';

    int starCount = 5;
    String comment = raw;
    if (raw.startsWith('[')) {
      final close = raw.indexOf(']');
      if (close != -1) {
        final meta = raw.substring(1, close);
        starCount = int.tryParse(meta.split(' ').first) ?? 5;
        comment = raw.substring(close + 1).trim();
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
              Row(
                children: List.generate(5, (i) {
                  return Icon(
                    i < starCount ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: const Color(0xFFEAB308),
                    size: 18,
                  );
                }),
              ),
              Text(
                date,
                style: const TextStyle(fontSize: 11, color: subText),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            comment,
            style: const TextStyle(fontSize: 13, color: darkText, fontWeight: FontWeight.w600, height: 1.3),
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
            Icon(Icons.rate_review_outlined, size: 54, color: primaryBlue),
            SizedBox(height: 14),
            Text("No Reviews Yet", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: darkText)),
            SizedBox(height: 4),
            Text("Your submitted reviews and ratings will show up here.", style: TextStyle(fontSize: 12, color: subText)),
          ],
        ),
      ),
    );
  }
}

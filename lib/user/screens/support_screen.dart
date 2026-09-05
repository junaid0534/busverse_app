import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'complain_screen.dart';
import 'feedback_screen.dart';

class SupportScreen extends StatefulWidget {
  final int userId;

  const SupportScreen({super.key, required this.userId});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  static const Color primaryBlue = Color(0xFF388AF6);
  static const Color darkNavy = Color(0xFF1E3C72);
  static const Color darkText = Color(0xFF1E293B);
  static const Color subText = Color(0xFF64748B);

  // FAQ Expanded State
  final List<Map<String, String>> _faqs = [
    {
      "q": "How can I cancel or refund my ticket?",
      "a": "Go to 'My Tickets' from your home dashboard, select your active ticket, and tap 'Cancel Ticket'. Your refund will be credited back to your BusVerse Wallet immediately.",
    },
    {
      "q": "What is the luggage allowance per passenger?",
      "a": "Each passenger is allowed up to 20 KG of standard luggage free of cost. For oversized or commercial cargo, please book through our Cargo service.",
    },
    {
      "q": "How early should I arrive at the bus terminal?",
      "a": "We recommend arriving at the departure terminal at least 20 to 30 minutes prior to the scheduled departure time for smooth baggage tagging and boarding.",
    },
    {
      "q": "Do I need a printed ticket for boarding?",
      "a": "No! BusVerse provides 100% digital paperless boarding. Simply show your E-Ticket with the QR code from the app to the boarding conductor.",
    },
    {
      "q": "Can I change my seat or departure time after booking?",
      "a": "Yes, you can cancel your existing booking and re-book for your preferred time/seat, or contact our 24/7 helpline at 0301-4025346 for staff assistance.",
    },
  ];

  int? _expandedFaqIndex;

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
          "Help & Support Center",
          style: TextStyle(
            color: darkText,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── TOP HERO ASSISTANCE BANNER ───
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [darkNavy, primaryBlue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: primaryBlue.withOpacity(0.28),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "How can we help you today?",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.headset_mic_rounded, color: Colors.white, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Our customer support team is available 24/7 to resolve your queries and feedback.",
                    style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
                  ),
                  const SizedBox(height: 14),

                  // Quick Action Buttons (Call & WhatsApp)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _launchCall,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: primaryBlue,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          icon: const Icon(Icons.phone_rounded, size: 16),
                          label: const Text("Call Helpline", style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _launchWhatsApp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF22C55E),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          icon: const Icon(Icons.chat_bubble_rounded, size: 16),
                          label: const Text("WhatsApp", style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ─── ACTION TILES (COMPLAIN & FEEDBACK) ───
            const Text(
              "Tickets & Feedback",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: darkText),
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: _actionCard(
                    title: "Complaints Center",
                    subtitle: "Fast 24-hr resolution",
                    icon: Icons.report_problem_rounded,
                    iconColor: const Color(0xFFDC2626),
                    bgColor: const Color(0xFFFEF2F2),
                    borderColor: const Color(0xFFFECACA),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ComplainScreen(userId: widget.userId),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _actionCard(
                    title: "Rate & Feedback",
                    subtitle: "Rate your travel",
                    icon: Icons.star_rate_rounded,
                    iconColor: const Color(0xFFEAB308),
                    bgColor: const Color(0xFFFEFCE8),
                    borderColor: const Color(0xFFFEF08A),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FeedbackScreen(userId: widget.userId),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 22),

            // ─── FREQUENTLY ASKED QUESTIONS (FAQS) ───
            const Text(
              "Frequently Asked Questions (FAQs)",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: darkText),
            ),
            const SizedBox(height: 10),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _faqs.length,
                separatorBuilder: (context, index) => const Divider(color: Color(0xFFF1F5F9), height: 1),
                itemBuilder: (context, index) {
                  final faq = _faqs[index];
                  final isExpanded = _expandedFaqIndex == index;

                  return Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      key: Key("faq_$index"),
                      initiallyExpanded: isExpanded,
                      onExpansionChanged: (expanded) {
                        setState(() {
                          _expandedFaqIndex = expanded ? index : null;
                        });
                      },
                      tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      title: Text(
                        faq["q"] ?? "",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isExpanded ? primaryBlue : darkText,
                        ),
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      children: [
                        Text(
                          faq["a"] ?? "",
                          style: const TextStyle(fontSize: 12, color: subText, height: 1.4),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            // ─── SOCIAL MEDIA CHANNELS ───
            const Text(
              "Connect on Social Media",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: darkText),
            ),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _socialButton(Icons.facebook, "Facebook", const Color(0xFF1877F2), _openFacebook),
                  _socialButton(Icons.camera_alt_rounded, "Instagram", const Color(0xFFE1306C), _openInstagram),
                  _socialButton(Icons.language_rounded, "Website", primaryBlue, _openWebsite),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _actionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: darkText)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: subText)),
          ],
        ),
      ),
    );
  }

  Widget _socialButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: darkText)),
        ],
      ),
    );
  }



  void _launchCall() async {
    final uri = Uri.parse("tel:03014025346");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _launchWhatsApp() async {
    final uri = Uri.parse("https://wa.me/923014025346");
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _openFacebook() async {
    final uri = Uri.parse("https://facebook.com");
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _openInstagram() async {
    final uri = Uri.parse("https://instagram.com");
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _openWebsite() async {
    final uri = Uri.parse("https://busverse.pk");
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

import 'package:flutter/material.dart';
import 'topup_wallet_screen.dart';

class MyWalletScreen extends StatelessWidget {
  const MyWalletScreen({super.key});

  static const Color primaryBlue = Color(0xFF388AF6);
  static const Color darkNavy = Color(0xFF1E3C72);
  static const Color darkText = Color(0xFF1E293B);
  static const Color subText = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final String userName = args?['userName'] ?? 'Valued Customer';
    final String userEmail = args?['userEmail'] ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        leading: const BackButton(color: darkText),
        title: const Text(
          "BusVerse Wallet",
          style: TextStyle(color: darkText, fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── WALLET BALANCE CARD ───
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [darkNavy, primaryBlue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: primaryBlue.withOpacity(0.3),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Hello, $userName", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                          if (userEmail.isNotEmpty)
                            Text(userEmail, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 22),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text("AVAILABLE BALANCE", style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1)),
                  const SizedBox(height: 4),
                  const Text("PKR 8,500.00", style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const TopupWalletScreen()),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: primaryBlue,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                          label: const Text("Top Up Wallet", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ─── RECENT TRANSACTIONS ───
            const Text(
              "Recent Transactions",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: darkText),
            ),
            const SizedBox(height: 12),

            _transactionTile(
              title: "Ticket Booking • LHR → ISB",
              date: "Today, 02:45 PM",
              amount: "- PKR 3,200",
              isDebit: true,
              icon: Icons.confirmation_number_outlined,
            ),
            _transactionTile(
              title: "Wallet Top-up via JazzCash",
              date: "Yesterday, 10:15 AM",
              amount: "+ PKR 5,000",
              isDebit: false,
              icon: Icons.account_balance_wallet_rounded,
            ),
            _transactionTile(
              title: "Welcome Bonus Reward",
              date: "01 Sep 2026",
              amount: "+ PKR 500",
              isDebit: false,
              icon: Icons.card_giftcard_rounded,
            ),
          ],
        ),
      ),
    );
  }

  Widget _transactionTile({
    required String title,
    required String date,
    required String amount,
    required bool isDebit,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDebit ? const Color(0xFFEFF6FF) : const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: isDebit ? primaryBlue : const Color(0xFF16A34A), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: darkText)),
                const SizedBox(height: 2),
                Text(date, style: const TextStyle(fontSize: 11, color: subText)),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: isDebit ? darkText : const Color(0xFF16A34A),
            ),
          ),
        ],
      ),
    );
  }
}

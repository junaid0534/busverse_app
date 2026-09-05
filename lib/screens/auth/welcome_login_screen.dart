import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bus_ticket_system/database/db_helper.dart';
import 'package:bus_ticket_system/services/auth_service.dart';
import 'package:bus_ticket_system/services/supabase_service.dart';

class WelcomeLoginScreen extends StatefulWidget {
  final String userEmail;

  const WelcomeLoginScreen({super.key, required this.userEmail});

  @override
  State<WelcomeLoginScreen> createState() => _WelcomeLoginScreenState();
}

class _WelcomeLoginScreenState extends State<WelcomeLoginScreen> {
  String userName = "";
  String userPhone = "";
  int userId = 0;
  bool isWalletVisible = false;
  bool isLoading = true;

  int _currentIndex = 0;

  // Primary Theme Color: Soft Dodger Blue
  static const Color primaryBlue = Color(0xFF388AF6);
  static const Color darkNavy = Color(0xFF1E3C72);
  static const Color darkText = Color(0xFF1E293B);

  @override
  void initState() {
    super.initState();
    fetchUserData();
  }

  Future<void> fetchUserData() async {
    String email = widget.userEmail.trim();
    if (email.isEmpty) {
      email = FirebaseAuth.instance.currentUser?.email ?? AuthService.instance.currentEmail ?? "";
    }

    dynamic user;
    if (email.isNotEmpty) {
      user = await DBHelper.instance.getUserByEmail(email);
    }

    // Check last user in SQLite if still not found
    if (user == null) {
      try {
        final allUsers = await DBHelper.instance.getAllUsers();
        if (allUsers.isNotEmpty) {
          final lastUser = allUsers.last;
          user = {
            'id': lastUser.id,
            'firstName': lastUser.firstName,
            'lastName': lastUser.lastName,
            'phone': lastUser.phone,
            'email': lastUser.email,
          };
          if (email.isEmpty) email = lastUser.email;
        }
      } catch (e) {
        print("Error fetching all users in WelcomeLogin: $e");
      }
    }

    // Check Supabase if Firebase User is logged in
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? AuthService.instance.currentUid;
    if (user == null && currentUid != null) {
      try {
        final cloudProfile = await SupabaseService.instance.getUserProfile(currentUid);
        if (cloudProfile != null) {
          user = {
            'id': 1,
            'firstName': cloudProfile['first_name'] ?? 'User',
            'lastName': cloudProfile['last_name'] ?? '',
            'phone': cloudProfile['phone'] ?? '',
            'email': cloudProfile['email'] ?? email,
          };
        }
      } catch (e) {
        print("Error fetching cloud profile in WelcomeLogin: $e");
      }
    }

    if (user != null) {
      if (!mounted) return;
      setState(() {
        userId = (user['id'] is int) ? user['id'] as int : 1;
        final fName = user['firstName'] ?? '';
        final lName = user['lastName'] ?? '';
        userName = "$fName $lName".trim();
        if (userName.isEmpty) userName = "Valued Customer";
        userPhone = user['phone'] ?? "";
        isLoading = false;
      });
    } else {
      if (!mounted) return;
      setState(() {
        userName = "Valued Customer";
        userPhone = "";
        userId = 1;
        isLoading = false;
      });
    }
  }

  void _goToMyTickets() {
    String email = widget.userEmail.trim();
    if (email.isEmpty) {
      email = FirebaseAuth.instance.currentUser?.email ?? AuthService.instance.currentEmail ?? "";
    }
    Navigator.pushNamed(
      context,
      '/my_tickets',
      arguments: {'userId': userId, 'userEmail': email},
    );
  }

  void _goToMyWallet() {
    Navigator.pushNamed(context, '/my_wallet');
  }

  void _goToSupport() {
    Navigator.pushNamed(
      context,
      '/support',
      arguments: {'userId': userId},
    );
  }

  void _goToMyAccount() {
    String email = widget.userEmail.trim();
    if (email.isEmpty) {
      email = FirebaseAuth.instance.currentUser?.email ?? AuthService.instance.currentEmail ?? "";
    }
    Navigator.pushNamed(
      context,
      '/my_account',
      arguments: {'userId': userId, 'userEmail': email},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      // ================= APP BAR =================
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: darkText, size: 24),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: "Bus",
                style: TextStyle(
                  color: darkText,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  letterSpacing: 0.5,
                ),
              ),
              TextSpan(
                text: "Verse",
                style: TextStyle(
                  color: primaryBlue,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded, color: darkText, size: 24),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("No new notifications")),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),

      // ================= DRAWER =================
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(
                userName.isNotEmpty ? userName : "BusVerse Passenger",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              accountEmail: Text(
                userPhone.isNotEmpty ? '$userPhone\n${widget.userEmail}' : widget.userEmail,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, size: 36, color: primaryBlue),
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [darkNavy, primaryBlue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.home_rounded, color: primaryBlue, size: 22),
              title: const Text('Home', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.person_rounded, color: primaryBlue, size: 22),
              title: const Text('My Account', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              onTap: () {
                Navigator.pop(context);
                _goToMyAccount();
              },
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.confirmation_num_rounded, color: primaryBlue, size: 22),
              title: const Text('My Tickets', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              onTap: () {
                Navigator.pop(context);
                _goToMyTickets();
              },
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.account_balance_wallet_rounded, color: primaryBlue, size: 22),
              title: const Text('My Wallet', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              onTap: () {
                Navigator.pop(context);
                _goToMyWallet();
              },
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.local_offer_rounded, color: primaryBlue, size: 22),
              title: const Text('Promotions', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Promotions coming soon!')),
                );
              },
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.support_agent_rounded, color: primaryBlue, size: 22),
              title: const Text('Support', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              onTap: () {
                Navigator.pop(context);
                _goToSupport();
              },
            ),
            const Divider(),
            ListTile(
              dense: true,
              leading: const Icon(Icons.logout_rounded, color: Colors.red, size: 22),
              title: const Text('Logout', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14)),
              onTap: () async {
                await AuthService.instance.signOut();
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                }
              },
            ),
            const SizedBox(height: 10),
            const Text(
              'BusVerse by Junaid Movers v5.4.2',
              style: TextStyle(color: Colors.grey, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),

      // ================= DASHBOARD BODY =================
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 12),

            // 1. Sleek Bus Banner Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    "assets/images/bus_welcome.png",
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // 2. Modern User Profile & Wallet Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF2563EB), // Rich Blue
                    Color(0xFF388AF6), // Dodger Blue
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: primaryBlue.withOpacity(0.28),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        ),
                      ),
                    )
                  : Row(
                      children: [
                        // User Avatar
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
                          ),
                          child: const Icon(Icons.person, size: 28, color: primaryBlue),
                        ),

                        const SizedBox(width: 12),

                        // Name & Phone
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                userPhone.isNotEmpty ? userPhone : widget.userEmail,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.85),
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),

                        // Wallet & Topup Button
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "Wallet",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            GestureDetector(
                              onTap: () => setState(() => isWalletVisible = !isWalletVisible),
                              child: Text(
                                isWalletVisible ? "0.00 PKR" : "•••• PKR",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: _goToMyWallet,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  "Top Up",
                                  style: TextStyle(
                                    color: primaryBlue,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),

            const SizedBox(height: 16),

            // 3. Three Modern Feature Cards (Bus Tickets, Cargo Tracking, Special Booking)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildModernCard(
                      icon: Icons.directions_bus_rounded,
                      title: "Bus\nTickets",
                      onTap: () => Navigator.pushNamed(
                        context,
                        '/search_bus',
                        arguments: {'userId': userId},
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildModernCard(
                      icon: Icons.inventory_2_rounded,
                      title: "Cargo\nTracking",
                      onTap: () => Navigator.pushNamed(context, '/cargo_tracking'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildModernCard(
                      icon: Icons.local_taxi_rounded,
                      title: "Special\nBooking",
                      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Special Booking Coming Soon!")),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),

      // ================= BOTTOM NAVIGATION BAR =================
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(
            top: BorderSide(color: Color(0xFFE2E8F0), width: 0.8),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.white,
          elevation: 0,
          selectedItemColor: primaryBlue,
          unselectedItemColor: const Color(0xFF94A3B8),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 10.5),
          currentIndex: _currentIndex,
          type: BottomNavigationBarType.fixed,
          iconSize: 22,
          onTap: (index) {
            setState(() => _currentIndex = index);
            switch (index) {
              case 0:
                break;
              case 1:
                _goToMyTickets();
                break;
              case 2:
                _goToMyWallet();
                break;
              case 3:
                _goToSupport();
                break;
              case 4:
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Promotions coming soon")),
                );
            }
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: "Home"),
            BottomNavigationBarItem(icon: Icon(Icons.confirmation_num_rounded), label: "My Tickets"),
            BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_rounded), label: "My Wallet"),
            BottomNavigationBarItem(icon: Icon(Icons.support_agent_rounded), label: "Support"),
            BottomNavigationBarItem(icon: Icon(Icons.local_offer_rounded), label: "Promotions"),
          ],
        ),
      ),
    );
  }

  Widget _buildModernCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Color(0xFFF0F7FF),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 24, color: primaryBlue),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: darkText,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
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
  bool isLoading = true;
  int _currentIndex = 0;
  int _unreadNotifCount = 0;

  static const Color primaryBlue = Color(0xFF388AF6);
  static const Color darkNavy = Color(0xFF1E3C72);
  static const Color darkText = Color(0xFF1E293B);
  static const Color subText = Color(0xFF64748B);
  static const Color bgSurface = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    fetchUserData();
    _loadUnreadNotifCount();
  }

  Future<void> _loadUnreadNotifCount() async {
    try {
      final count = await DBHelper.instance.getUnreadNotificationsCount();
      if (mounted) setState(() => _unreadNotifCount = count);
    } catch (_) {}
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
      } catch (_) {}
    }

    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? AuthService.instance.currentUid;
    if (user == null && currentUid != null) {
      try {
        final cloudProfile = await SupabaseService.instance.getUserProfile(currentUid);
        if (cloudProfile != null) {
          user = {
            'id': 1,
            'firstName': cloudProfile['first_name'] ?? 'Passenger',
            'lastName': cloudProfile['last_name'] ?? '',
            'phone': cloudProfile['phone'] ?? '',
            'email': cloudProfile['email'] ?? email,
          };
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        if (user != null) {
          userId = (user['id'] is int) ? user['id'] as int : 1;
          final fName = user['firstName'] ?? '';
          final lName = user['lastName'] ?? '';
          userName = "$fName $lName".trim();
          if (userName.isEmpty) userName = "Passenger";
          userPhone = user['phone'] ?? "";
        } else {
          userName = "Passenger";
          userId = 1;
        }
        isLoading = false;
      });
    }
  }

  void _goToSearchBus() {
    Navigator.pushNamed(
      context,
      '/search_bus',
      arguments: {'userId': userId},
    );
  }

  void _goToMyTickets() async {
    String email = widget.userEmail.trim();
    if (email.isEmpty) {
      email = FirebaseAuth.instance.currentUser?.email ?? AuthService.instance.currentEmail ?? "";
    }
    await Navigator.pushNamed(
      context,
      '/my_tickets',
      arguments: {'userId': userId, 'userEmail': email},
    );
    if (mounted) setState(() => _currentIndex = 0);
  }

  void _goToMyWallet() async {
    await Navigator.pushNamed(context, '/my_wallet');
    if (mounted) setState(() => _currentIndex = 0);
  }

  void _goToSupport() async {
    await Navigator.pushNamed(
      context,
      '/support',
      arguments: {'userId': userId},
    );
    if (mounted) setState(() => _currentIndex = 0);
  }

  void _goToMyAccount() async {
    String email = widget.userEmail.trim();
    if (email.isEmpty) {
      email = FirebaseAuth.instance.currentUser?.email ?? AuthService.instance.currentEmail ?? "";
    }
    await Navigator.pushNamed(
      context,
      '/my_account',
      arguments: {'userId': userId, 'userEmail': email},
    );
    if (mounted) {
      setState(() => _currentIndex = 0);
      _loadUnreadNotifCount();
    }
  }

  void _goToNotifications() async {
    String email = widget.userEmail.trim();
    if (email.isEmpty) {
      email = FirebaseAuth.instance.currentUser?.email ?? AuthService.instance.currentEmail ?? "";
    }
    await Navigator.pushNamed(
      context,
      '/notifications',
      arguments: {'userId': userId, 'userEmail': email},
    );
    if (mounted) {
      _loadUnreadNotifCount();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgSurface,

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
          // Notification Bell with unread counter in the corner
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_none_rounded, color: darkText, size: 24),
                  onPressed: _goToNotifications,
                ),
                if (_unreadNotifCount > 0)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        _unreadNotifCount > 9 ? "9+" : "$_unreadNotifCount",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),

      // ================= DRAWER =================
      drawer: _buildDrawer(),

      // ================= DASHBOARD BODY =================
      body: RefreshIndicator(
        color: primaryBlue,
        onRefresh: () async {
          await fetchUserData();
          await _loadUnreadNotifCount();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── 1. SLEEK BUS BANNER CARD ───
              _buildBusBanner(),

              const SizedBox(height: 16),

              // ─── 2. QUICK SERVICES (SEARCH BUS 1ST, NO SUPPORT) ───
              _buildQuickServices(),

              const SizedBox(height: 20),

              // ─── 3. POPULAR DAILY ROUTES ───
              _buildPopularRoutes(),

              const SizedBox(height: 20),

              // ─── 4. PROMO & LUXURY TRAVEL CARD ───
              _buildPromoBanner(),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),

      // ================= BOTTOM NAVIGATION BAR =================
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ─── BUS WELCOME BANNER ───
  Widget _buildBusBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          "assets/images/bus_welcome.png",
          height: 135,
          width: double.infinity,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  // ─── QUICK SERVICES (SEARCH BUS 1ST, NO SUPPORT) ───
  Widget _buildQuickServices() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Quick Services",
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: darkText,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            // 1. Search Bus
            Expanded(
              child: _buildServiceTile(
                icon: Icons.directions_bus_rounded,
                title: "Search Bus",
                color: primaryBlue,
                onTap: _goToSearchBus,
              ),
            ),
            const SizedBox(width: 10),

            // 2. My Tickets
            Expanded(
              child: _buildServiceTile(
                icon: Icons.confirmation_number_rounded,
                title: "My Tickets",
                color: const Color(0xFF16A34A),
                onTap: _goToMyTickets,
              ),
            ),
            const SizedBox(width: 10),

            // 3. My Wallet
            Expanded(
              child: _buildServiceTile(
                icon: Icons.account_balance_wallet_rounded,
                title: "My Wallet",
                color: const Color(0xFF8B5CF6),
                onTap: _goToMyWallet,
              ),
            ),
            const SizedBox(width: 10),

            // 4. Cargo
            Expanded(
              child: _buildServiceTile(
                icon: Icons.local_shipping_rounded,
                title: "Cargo",
                color: const Color(0xFFF59E0B),
                onTap: () => Navigator.pushNamed(context, '/cargo_tracking'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildServiceTile({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: darkText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── POPULAR ROUTES ───
  Widget _buildPopularRoutes() {
    final List<Map<String, String>> popularList = [
      {"from": "Lahore", "to": "Islamabad", "fare": "1,950"},
      {"from": "Multan", "to": "Lahore", "fare": "1,450"},
      {"from": "Faisalabad", "to": "Islamabad", "fare": "1,800"},
      {"from": "Karachi", "to": "Hyderabad", "fare": "950"},
      {"from": "Rawalpindi", "to": "Multan", "fare": "2,100"},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Popular Routes",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: darkText,
              ),
            ),
            GestureDetector(
              onTap: _goToSearchBus,
              child: const Text(
                "Search More",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: primaryBlue,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 94,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: popularList.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final item = popularList[index];

              return Material(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: _goToSearchBus,
                  child: Container(
                    width: 175,
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Text(
                              item['from']!,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: darkText),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_forward_rounded, size: 12, color: primaryBlue),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                item['to']!,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: darkText),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "From PKR ${item['fare']}",
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: primaryBlue,
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, size: 16, color: subText),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ─── PROMO BANNER ───
  Widget _buildPromoBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.local_offer_rounded, color: Colors.amber, size: 24),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Get 15% OFF First Trip",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  "Use code JUNAID15 on any Luxury Bus booking",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── DRAWER ───
  Widget _buildDrawer() {
    return Drawer(
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
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                userName.isNotEmpty ? userName[0].toUpperCase() : "U",
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryBlue),
              ),
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
            leading: const Icon(Icons.directions_bus_rounded, color: primaryBlue, size: 22),
            title: const Text('Search Bus', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            onTap: () {
              Navigator.pop(context);
              _goToSearchBus();
            },
          ),
          ListTile(
            dense: true,
            leading: const Icon(Icons.notifications_rounded, color: primaryBlue, size: 22),
            title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            trailing: _unreadNotifCount > 0
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "$_unreadNotifCount",
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  )
                : null,
            onTap: () {
              Navigator.pop(context);
              _goToNotifications();
            },
          ),
          ListTile(
            dense: true,
            leading: const Icon(Icons.person_rounded, color: primaryBlue, size: 22),
            title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
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
              if (!mounted) return;
              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            },
          ),
        ],
      ),
    );
  }

  // ─── BOTTOM NAVIGATION BAR ───
  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 0.8),
        ),
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
              _goToMyAccount();
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.confirmation_num_rounded), label: "My Tickets"),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_rounded), label: "My Wallet"),
          BottomNavigationBarItem(icon: Icon(Icons.support_agent_rounded), label: "Support"),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: "Profile"),
        ],
      ),
    );
  }
}
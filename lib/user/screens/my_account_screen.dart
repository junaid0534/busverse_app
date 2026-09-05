import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bus_ticket_system/database/db_helper.dart';
import 'package:bus_ticket_system/services/auth_service.dart';
import 'package:bus_ticket_system/services/supabase_service.dart';

class MyAccountScreen extends StatefulWidget {
  final int userId;
  final String userEmail;

  const MyAccountScreen({
    super.key,
    required this.userId,
    required this.userEmail,
  });

  @override
  State<MyAccountScreen> createState() => _MyAccountScreenState();
}

class _MyAccountScreenState extends State<MyAccountScreen> {
  Map<String, dynamic>? user;
  int totalBookings = 0;
  bool isLoading = true;

  static const Color primaryBlue = Color(0xFF388AF6);
  static const Color darkNavy = Color(0xFF1E3C72);
  static const Color darkText = Color(0xFF1E293B);
  static const Color subText = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    fetchUser();
  }

  Future<void> fetchUser() async {
    setState(() => isLoading = true);

    String email = widget.userEmail.trim();
    if (email.isEmpty) {
      email = FirebaseAuth.instance.currentUser?.email ?? AuthService.instance.currentEmail ?? "";
    }

    dynamic userData;
    if (email.isNotEmpty) {
      userData = await DBHelper.instance.getUserByEmail(email);
    }

    if (userData == null && widget.userId > 0) {
      userData = await DBHelper.instance.getUserById(widget.userId);
    }

    // Fallback to last registered user if empty
    if (userData == null) {
      final allUsers = await DBHelper.instance.getAllUsers();
      if (allUsers.isNotEmpty) {
        final last = allUsers.last;
        userData = {
          'id': last.id,
          'firstName': last.firstName,
          'lastName': last.lastName,
          'email': last.email,
          'phone': last.phone,
          'cnic': last.cnic,
          'gender': last.gender,
          'city': last.city,
          'street': last.street,
        };
      }
    }

    // Check Supabase if Firebase User
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (userData == null && currentUid != null) {
      final cloudProfile = await SupabaseService.instance.getUserProfile(currentUid);
      if (cloudProfile != null) {
        userData = {
          'id': 1,
          'firstName': cloudProfile['first_name'] ?? 'Valued',
          'lastName': cloudProfile['last_name'] ?? 'Customer',
          'email': cloudProfile['email'] ?? email,
          'phone': cloudProfile['phone'] ?? '',
          'cnic': cloudProfile['cnic'] ?? '',
          'gender': cloudProfile['gender'] ?? 'M',
          'city': cloudProfile['city'] ?? '',
        };
      }
    }

    // Fetch booking count
    int bCount = 0;
    try {
      final uid = (userData != null && userData['id'] is int) ? userData['id'] as int : widget.userId;
      final localBookings = await DBHelper.instance.getUserBookings(uid);
      bCount = localBookings.length;
      if (currentUid != null) {
        final cloudB = await SupabaseService.instance.getUserBookings(currentUid);
        if (cloudB.length > bCount) bCount = cloudB.length;
      }
    } catch (e) {
      print("Error fetching booking count: $e");
    }

    if (mounted) {
      setState(() {
        user = userData;
        totalBookings = bCount;
        isLoading = false;
      });
    }
  }

  void _confirmLogout() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 28),
            ),
            const SizedBox(height: 14),
            const Text(
              "Log Out of BusVerse?",
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: darkText),
            ),
            const SizedBox(height: 6),
            const Text(
              "You will need to enter your email and password to access your bookings again.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: subText),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Cancel", style: TextStyle(color: darkText, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await AuthService.instance.signOut();
                      if (mounted) {
                        Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Yes, Log Out", style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text("Delete Account", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          "Are you sure you want to permanently delete your account?\nAll your booking records and profile data will be permanently wiped.",
          style: TextStyle(fontSize: 13, color: subText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: subText, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final activeId = (user != null && user!['id'] is int) ? user!['id'] as int : widget.userId;
              if (activeId > 0) {
                await DBHelper.instance.deleteUser(activeId);
              }
              await AuthService.instance.signOut();
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Account deleted successfully."),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            child: const Text("Delete Permanently"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String firstName = user?['firstName'] ?? '';
    final String lastName = user?['lastName'] ?? '';
    final String fullName = "$firstName $lastName".trim().isNotEmpty
        ? "$firstName $lastName".trim()
        : "Valued Customer";
    final String email = (user?['email'] != null && user!['email'].toString().isNotEmpty)
        ? user!['email']
        : (widget.userEmail.isNotEmpty ? widget.userEmail : "user@busverse.com");
    final String phone = user?['phone'] ?? "Not Provided";
    final String cnic = user?['cnic'] ?? "Not Provided";
    final String gender = user?['gender'] ?? "M";
    final String city = user?['city'] ?? "Lahore, Pakistan";

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
          "My Profile & Account",
          style: TextStyle(
            color: darkText,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: primaryBlue, size: 22),
            onPressed: fetchUser,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryBlue))
          : RefreshIndicator(
              color: primaryBlue,
              onRefresh: fetchUser,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                child: Column(
                  children: [
                    // ─── PROFILE HEADER CARD (GRADIENT) ───
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [darkNavy, primaryBlue],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: primaryBlue.withOpacity(0.3),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              // Avatar with Initial
                              Container(
                                width: 68,
                                height: 68,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.12),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    fullName.isNotEmpty ? fullName[0].toUpperCase() : "U",
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                      color: primaryBlue,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      fullName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      email,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.verified_rounded, color: Color(0xFF4ADE80), size: 12),
                                          SizedBox(width: 4),
                                          Text(
                                            "Verified Passenger",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          const Divider(color: Colors.white24, height: 1),
                          const SizedBox(height: 14),

                          // Edit Profile Button inside Header
                          InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () async {
                              await Navigator.pushNamed(
                                context,
                                '/edit_basic_info',
                                arguments: {
                                  'userId': user?['id'] ?? widget.userId,
                                  'userEmail': email,
                                },
                              );
                              fetchUser();
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.edit_rounded, size: 16, color: primaryBlue),
                                  SizedBox(width: 6),
                                  Text(
                                    "Edit Profile Information",
                                    style: TextStyle(
                                      color: primaryBlue,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ─── QUICK STATS SUMMARY ROW ───
                    Row(
                      children: [
                        _buildStatBox("Bookings", "$totalBookings Trips", Icons.confirmation_number_rounded, const Color(0xFF388AF6)),
                        const SizedBox(width: 10),
                        _buildStatBox("Wallet Balance", "8,500 PKR", Icons.account_balance_wallet_rounded, const Color(0xFF16A34A)),
                        const SizedBox(width: 10),
                        _buildStatBox("Tier", "Gold VIP", Icons.stars_rounded, const Color(0xFFD97706)),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // ─── PERSONAL DETAILS CARD ───
                    _buildSectionContainer(
                      title: "Personal Information",
                      icon: Icons.badge_outlined,
                      children: [
                        _buildDetailItem(Icons.phone_outlined, "Phone Number", phone),
                        _buildDetailItem(Icons.credit_card_outlined, "CNIC Number", cnic),
                        _buildDetailItem(Icons.person_outline_rounded, "Gender", gender == "F" ? "Female" : "Male"),
                        _buildDetailItem(Icons.location_city_outlined, "City / Region", city, isLast: true),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // ─── QUICK SERVICES MENU ───
                    _buildSectionContainer(
                      title: "My Activity & Shortcuts",
                      icon: Icons.dashboard_outlined,
                      children: [
                        _buildMenuTile(
                          icon: Icons.confirmation_number_outlined,
                          title: "My Bookings & Tickets",
                          subtitle: "View active and past trip e-tickets",
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              '/my_tickets',
                              arguments: {'userId': user?['id'] ?? widget.userId, 'userEmail': email},
                            );
                          },
                        ),
                        _buildMenuTile(
                          icon: Icons.account_balance_wallet_outlined,
                          title: "BusVerse Wallet",
                          subtitle: "Manage funds, top up & instant refunds",
                          onTap: () => Navigator.pushNamed(context, '/my_wallet'),
                        ),
                        _buildMenuTile(
                          icon: Icons.local_shipping_outlined,
                          title: "Cargo Tracking",
                          subtitle: "Track live courier & parcel delivery",
                          onTap: () => Navigator.pushNamed(context, '/cargo_tracking'),
                        ),
                        _buildMenuTile(
                          icon: Icons.headset_mic_outlined,
                          title: "24/7 Support & Help Desk",
                          subtitle: "Live assistance & ticket inquiries",
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              '/support',
                              arguments: {'userId': user?['id'] ?? widget.userId},
                            );
                          },
                        ),
                        _buildMenuTile(
                          icon: Icons.feedback_outlined,
                          title: "Submit Feedback or Complaint",
                          subtitle: "Share your travel experience with us",
                          isLast: true,
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              '/feedback',
                              arguments: {'userId': user?['id'] ?? widget.userId},
                            );
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // ─── ACCOUNT ACTIONS & LOGOUT ───
                    _buildSectionContainer(
                      title: "Account Security & Actions",
                      icon: Icons.shield_outlined,
                      children: [
                        _buildMenuTile(
                          icon: Icons.lock_outline_rounded,
                          title: "Change Password",
                          subtitle: "Update account login credentials",
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              '/edit_basic_info',
                              arguments: {
                                'userId': user?['id'] ?? widget.userId,
                                'userEmail': email,
                              },
                            );
                          },
                        ),
                        _buildMenuTile(
                          icon: Icons.logout_rounded,
                          title: "Log Out",
                          subtitle: "Sign out of your BusVerse account",
                          iconColor: const Color(0xFFE11D48),
                          onTap: _confirmLogout,
                        ),
                        _buildMenuTile(
                          icon: Icons.delete_forever_rounded,
                          title: "Delete Account",
                          subtitle: "Permanently erase your account and history",
                          iconColor: Colors.redAccent,
                          isLast: true,
                          onTap: _confirmDeleteAccount,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Footer Version Label
                    const Text(
                      "BusVerse Application v2.4.0 • Junaid Movers",
                      style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatBox(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
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
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: darkText),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: subText, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionContainer({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Icon(icon, size: 16, color: primaryBlue),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: darkText,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value, {bool isLast = false}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            children: [
              Icon(icon, size: 18, color: subText),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(fontSize: 12.5, color: subText, fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              Text(
                value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: darkText),
              ),
            ],
          ),
        ),
        if (!isLast) const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFF8FAFC)),
      ],
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
    bool isLast = false,
  }) {
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (iconColor ?? primaryBlue).withOpacity(0.09),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor ?? primaryBlue),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: iconColor ?? darkText,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: subText),
          ),
          trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFFCBD5E1)),
          onTap: onTap,
        ),
        if (!isLast) const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFF1F5F9)),
      ],
    );
  }
}
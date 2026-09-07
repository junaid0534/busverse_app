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
  int unreadNotifications = 0;
  bool isLoading = true;

  static const Color primaryBlue = Color(0xFF388AF6);
  static const Color darkText = Color(0xFF1E293B);
  static const Color subText = Color(0xFF64748B);
  static const Color surfaceColor = Color(0xFFF8FAFC);
  static const Color dividerColor = Color(0xFFF1F5F9);

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

    // Accurate booking count calculation
    int bCount = 0;
    try {
      final int activeUid = (userData != null && userData['id'] is int) ? userData['id'] as int : widget.userId;
      final String userEmailNormalized = (userData?['email'] ?? email).toString().trim().toLowerCase();

      List<Map<String, dynamic>> combinedTickets = [];

      final bList = await DBHelper.instance.getUserBookings(activeUid);
      for (var b in bList) {
        combinedTickets.add(b);
      }

      if (combinedTickets.isEmpty) {
        final payments = await DBHelper.instance.getPayments();
        for (var p in payments) {
          final String pEmail = (p['email'] ?? '').toString().trim().toLowerCase();
          if (pEmail == userEmailNormalized || userEmailNormalized.isEmpty || pEmail.isEmpty || activeUid == 0) {
            combinedTickets.add({
              'bookingId': p['id'],
              'busId': p['busId'],
              'seats': p['seats'],
              'travelDate': p['date'],
            });
          }
        }
      }

      if (combinedTickets.isEmpty && currentUid != null) {
        final cloudB = await SupabaseService.instance.getUserBookings(currentUid);
        for (var cb in cloudB) {
          combinedTickets.add(cb);
        }
      }

      // Deduplication
      final Set<String> seenKeys = {};
      final List<Map<String, dynamic>> deduped = [];

      for (var ticket in combinedTickets) {
        final String bId = (ticket['bookingId'] ?? ticket['id'] ?? '').toString();
        final String seatNum = (ticket['seatNumber'] ?? ticket['seats'])?.toString().replaceAll('#', '').trim() ?? '';
        final String date = (ticket['travelDate'] ?? ticket['date'] ?? ticket['bookingDate'])?.toString().split(' ')[0].split('T')[0] ?? '';

        final String seatKey = "seat-$seatNum-$date";
        final String idKey = "ref-$bId";

        if (!seenKeys.contains(seatKey) && !seenKeys.contains(idKey)) {
          seenKeys.add(seatKey);
          seenKeys.add(idKey);
          deduped.add(ticket);
        }
      }

      bCount = deduped.length;
    } catch (_) {}

    // Unread notifications count
    int notifCount = 0;
    try {
      notifCount = await DBHelper.instance.getUnreadNotificationsCount();
    } catch (_) {}

    if (mounted) {
      setState(() {
        user = userData;
        totalBookings = bCount;
        unreadNotifications = notifCount;
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
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              "Log Out",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: darkText),
            ),
            const SizedBox(height: 8),
            const Text(
              "Are you sure you want to log out of BusVerse?",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: subText),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Cancel", style: TextStyle(color: darkText, fontWeight: FontWeight.w600)),
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
                      backgroundColor: const Color(0xFFEF4444),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Log Out", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Delete Account", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: darkText)),
        content: const Text(
          "Are you sure you want to permanently delete your account? All booking records and data will be erased.",
          style: TextStyle(fontSize: 13, color: subText, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: subText, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
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
              }
            },
            child: const Text("Delete", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
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
        : (widget.userEmail.isNotEmpty ? widget.userEmail : "passenger@busverse.com");
    final String phone = (user?['phone'] != null && user!['phone'].toString().isNotEmpty)
        ? user!['phone']
        : "Not Provided";
    final String cnic = (user?['cnic'] != null && user!['cnic'].toString().isNotEmpty)
        ? user!['cnic']
        : "Not Provided";
    final String gender = user?['gender'] == "F" ? "Female" : "Male";
    final String city = (user?['city'] != null && user!['city'].toString().isNotEmpty)
        ? user!['city']
        : "Not Provided";

    return Scaffold(
      backgroundColor: surfaceColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: darkText, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "My Profile",
          style: TextStyle(
            color: darkText,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
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
                    // ─── 1. PROFILE HEADER CARD ───
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          // Avatar Circle
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: primaryBlue.withValues(alpha: 0.12),
                            ),
                            child: Center(
                              child: Text(
                                fullName.isNotEmpty ? fullName[0].toUpperCase() : "U",
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: primaryBlue,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            fullName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: darkText,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            email,
                            style: const TextStyle(
                              fontSize: 13,
                              color: subText,
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Edit Profile Pill Button
                          SizedBox(
                            height: 36,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                await Navigator.pushNamed(
                                  context,
                                  '/edit_basic_info',
                                  arguments: {'userId': user?['id'] ?? widget.userId, 'userEmail': email},
                                );
                                fetchUser();
                              },
                              icon: const Icon(Icons.edit_outlined, size: 14, color: primaryBlue),
                              label: const Text(
                                "Edit Profile",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: primaryBlue,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFBFDBFE)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ─── 2. TWO-CARD SUMMARY STATS ───
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryBox(
                            title: "Booked Trips",
                            value: "$totalBookings",
                            icon: Icons.confirmation_number_outlined,
                            iconColor: primaryBlue,
                            onTap: () async {
                              await Navigator.pushNamed(
                                context,
                                '/my_tickets',
                                arguments: {'userId': user?['id'] ?? widget.userId, 'userEmail': email},
                              );
                              fetchUser();
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildSummaryBox(
                            title: "Wallet",
                            value: "Active",
                            icon: Icons.account_balance_wallet_outlined,
                            iconColor: const Color(0xFF16A34A),
                            onTap: () => Navigator.pushNamed(context, '/my_wallet'),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ─── 3. PERSONAL DETAILS SECTION ───
                    _buildSectionContainer(
                      title: "PERSONAL DETAILS",
                      children: [
                        _buildInfoTile(Icons.phone_outlined, "Phone", phone),
                        const Divider(height: 1, color: dividerColor),
                        _buildInfoTile(Icons.badge_outlined, "CNIC", cnic),
                        const Divider(height: 1, color: dividerColor),
                        _buildInfoTile(Icons.wc_outlined, "Gender", gender),
                        const Divider(height: 1, color: dividerColor),
                        _buildInfoTile(Icons.location_on_outlined, "City", city),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ─── 4. SERVICES & ACTIVITY ───
                    _buildSectionContainer(
                      title: "SERVICES & ACTIVITY",
                      children: [
                        _buildNavTile(
                          icon: Icons.airplane_ticket_outlined,
                          title: "My Tickets",
                          subtitle: "View and manage active tickets",
                          onTap: () async {
                            await Navigator.pushNamed(
                              context,
                              '/my_tickets',
                              arguments: {'userId': user?['id'] ?? widget.userId, 'userEmail': email},
                            );
                            fetchUser();
                          },
                        ),
                        const Divider(height: 1, color: dividerColor),
                        _buildNavTile(
                          icon: Icons.notifications_none_rounded,
                          title: "Notifications",
                          subtitle: "Trip alerts & promotional offers",
                          badgeCount: unreadNotifications,
                          onTap: () async {
                            await Navigator.pushNamed(
                              context,
                              '/notifications',
                              arguments: {'userId': user?['id'] ?? widget.userId, 'userEmail': email},
                            );
                            fetchUser();
                          },
                        ),
                        const Divider(height: 1, color: dividerColor),
                        _buildNavTile(
                          icon: Icons.local_shipping_outlined,
                          title: "Cargo Tracking",
                          subtitle: "Track live courier & parcel delivery",
                          onTap: () => Navigator.pushNamed(context, '/cargo_tracking'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ─── 5. HELP & SECURITY ───
                    _buildSectionContainer(
                      title: "SUPPORT & SECURITY",
                      children: [
                        _buildNavTile(
                          icon: Icons.support_agent_rounded,
                          title: "Help & Support",
                          subtitle: "24/7 customer helpline assistance",
                          onTap: () => Navigator.pushNamed(
                            context,
                            '/support',
                            arguments: {'userId': user?['id'] ?? widget.userId},
                          ),
                        ),
                        const Divider(height: 1, color: dividerColor),
                        _buildNavTile(
                          icon: Icons.rate_review_outlined,
                          title: "Feedback & Complaints",
                          subtitle: "Submit a review or report an issue",
                          onTap: () => Navigator.pushNamed(
                            context,
                            '/feedback',
                            arguments: {'userId': user?['id'] ?? widget.userId},
                          ),
                        ),
                        const Divider(height: 1, color: dividerColor),
                        _buildNavTile(
                          icon: Icons.lock_outline_rounded,
                          title: "Change Password",
                          subtitle: "Update account security credentials",
                          onTap: () async {
                            await Navigator.pushNamed(
                              context,
                              '/edit_basic_info',
                              arguments: {'userId': user?['id'] ?? widget.userId, 'userEmail': email},
                            );
                            fetchUser();
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ─── 6. LOG OUT & DELETE ───
                    Material(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        leading: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 20),
                        title: const Text(
                          "Log Out",
                          style: TextStyle(
                            color: Color(0xFFEF4444),
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFFCBD5E1), size: 14),
                        onTap: _confirmLogout,
                      ),
                    ),

                    const SizedBox(height: 14),

                    TextButton(
                      onPressed: _confirmDeleteAccount,
                      child: const Text(
                        "Delete Account",
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    const SizedBox(height: 6),
                    const Text(
                      "BusVerse • Junaid Movers",
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFFCBD5E1),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  // ─── SUMMARY BOX ───
  Widget _buildSummaryBox({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    VoidCallback? onTap,
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
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: subText),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: darkText),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── SECTION CONTAINER ───
  Widget _buildSectionContainer({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: subText,
              letterSpacing: 0.6,
            ),
          ),
        ),
        Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(children: children),
        ),
      ],
    );
  }

  // ─── INFO TILE (Read-only Personal Info) ───
  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Icon(icon, size: 18, color: subText),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(fontSize: 13.5, color: subText, fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: darkText),
          ),
        ],
      ),
    );
  }

  // ─── NAVIGATION TILE ───
  Widget _buildNavTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Icon(icon, color: primaryBlue, size: 20),
      title: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: darkText,
            ),
          ),
          if (badgeCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "$badgeCount",
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: subText),
      ),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFFCBD5E1), size: 13),
      onTap: onTap,
    );
  }
}
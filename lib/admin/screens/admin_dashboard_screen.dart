import 'package:flutter/material.dart';
import 'package:bus_ticket_system/database/db_helper.dart';
import 'all_users_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  static const Color primaryBlue = Color(0xFF388AF6);
  static const Color darkNavy = Color(0xFF1E3C72);
  static const Color darkText = Color(0xFF1E293B);
  static const Color subText = Color(0xFF64748B);
  static const Color bgSurface = Color(0xFFF8FAFC);

  bool _isLoading = true;
  Map<String, dynamic> _stats = {
    'totalBuses': 0,
    'totalRoutes': 0,
    'totalUsers': 0,
    'totalBookings': 0,
    'totalComplaints': 0,
    'totalFeedbacks': 0,
    'todayBookings': 0,
    'totalRevenue': 0.0,
  };
  List<Map<String, dynamic>> _recentBookings = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      final statsData = await DBHelper.instance.getAdminStats();
      final recentData = await DBHelper.instance.getAllBookingsAdmin(limit: 5);

      if (mounted) {
        setState(() {
          _stats = statsData;
          _recentBookings = recentData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 22),
            SizedBox(width: 8),
            Text(
              "Logout Admin",
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: darkText),
            ),
          ],
        ),
        content: const Text(
          "Are you sure you want to log out of the Admin Control Panel?",
          style: TextStyle(fontSize: 13.5, color: subText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: subText, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            },
            child: const Text("Logout", style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int totalBuses = _stats['totalBuses'] ?? 0;
    final int totalRoutes = _stats['totalRoutes'] ?? 0;
    final int totalUsers = _stats['totalUsers'] ?? 0;
    final int totalSubAdmins = _stats['totalSubAdmins'] ?? 0;
    final int totalBookings = _stats['totalBookings'] ?? 0;
    final int totalComplaints = _stats['totalComplaints'] ?? 0;
    final int totalFeedbacks = _stats['totalFeedbacks'] ?? 0;
    final int todayBookings = _stats['todayBookings'] ?? 0;
    final double totalRevenue = (_stats['totalRevenue'] as num?)?.toDouble() ?? 0.0;

    final List<Map<String, dynamic>> adminOptions = [
      {
        'icon': Icons.directions_bus_rounded,
        'title': 'Manage Buses',
        'subtitle': '$totalBuses active buses',
        'badge': totalBuses > 0 ? '$totalBuses' : null,
        'color': const Color(0xFF388AF6),
        'onTap': () async {
          await Navigator.pushNamed(context, '/manage_buses');
          _loadDashboardData();
        },
      },
      {
        'icon': Icons.alt_route_rounded,
        'title': 'Manage Routes',
        'subtitle': '$totalRoutes intercity routes',
        'badge': totalRoutes > 0 ? '$totalRoutes' : null,
        'color': const Color(0xFF0EA5E9),
        'onTap': () async {
          await Navigator.pushNamed(context, '/manage_routes');
          _loadDashboardData();
        },
      },
      {
        'icon': Icons.receipt_long_rounded,
        'title': 'All Bookings',
        'subtitle': '$totalBookings total tickets',
        'badge': todayBookings > 0 ? '$todayBookings today' : null,
        'badgeColor': const Color(0xFF10B981),
        'color': const Color(0xFF10B981),
        'onTap': () async {
          await Navigator.pushNamed(context, '/view_all_booking');
          _loadDashboardData();
        },
      },
      {
        'icon': Icons.badge_rounded,
        'title': 'Terminal Agents',
        'subtitle': '$totalSubAdmins counter agents',
        'badge': totalSubAdmins > 0 ? '$totalSubAdmins active' : null,
        'badgeColor': const Color(0xFF388AF6),
        'color': const Color(0xFF388AF6),
        'onTap': () async {
          await Navigator.pushNamed(context, '/manage_sub_admins');
          _loadDashboardData();
        },
      },
      {
        'icon': Icons.people_alt_rounded,
        'title': 'Registered Users',
        'subtitle': '$totalUsers passenger accounts',
        'badge': totalUsers > 0 ? '$totalUsers' : null,
        'color': const Color(0xFF8B5CF6),
        'onTap': () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AllUsersScreen()),
          );
          _loadDashboardData();
        },
      },
      {
        'icon': Icons.report_problem_rounded,
        'title': 'Complaints',
        'subtitle': '$totalComplaints user issues',
        'badge': totalComplaints > 0 ? '$totalComplaints' : null,
        'badgeColor': const Color(0xFFEF4444),
        'color': const Color(0xFFEF4444),
        'onTap': () async {
          await Navigator.pushNamed(context, '/admin_complains');
          _loadDashboardData();
        },
      },
      {
        'icon': Icons.rate_review_rounded,
        'title': 'Feedbacks',
        'subtitle': '$totalFeedbacks reviews',
        'badge': totalFeedbacks > 0 ? '$totalFeedbacks' : null,
        'badgeColor': const Color(0xFFF59E0B),
        'color': const Color(0xFFF59E0B),
        'onTap': () async {
          await Navigator.pushNamed(context, '/admin_feedbacks');
          _loadDashboardData();
        },
      },
    ];

    return Scaffold(
      backgroundColor: bgSurface,

      // ================= APP BAR =================
      appBar: AppBar(
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
                text: "Verse ",
                style: TextStyle(
                  color: primaryBlue,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  letterSpacing: 0.5,
                ),
              ),
              TextSpan(
                text: "Admin",
                style: TextStyle(
                  color: subText,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: false,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: darkText, size: 22),
            tooltip: 'Refresh Stats',
            onPressed: () {
              setState(() => _isLoading = true);
              _loadDashboardData();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 22),
            tooltip: 'Logout',
            onPressed: _showLogoutDialog,
          ),
          const SizedBox(width: 8),
        ],
      ),

      // ================= BODY =================
      body: RefreshIndicator(
        color: primaryBlue,
        onRefresh: _loadDashboardData,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: primaryBlue))
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── 1. HERO ADMIN BANNER ───
                    _buildAdminHeroBanner(totalRevenue, todayBookings),

                    const SizedBox(height: 18),

                    // ─── 2. LIVE KPI STATS ROW ───
                    _buildKpiStatsRow(
                      totalBuses: totalBuses,
                      totalRoutes: totalRoutes,
                      totalBookings: totalBookings,
                      totalUsers: totalUsers,
                    ),

                    const SizedBox(height: 22),

                    // ─── 3. MANAGEMENT MENU TITLE ───
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Management Services",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: darkText,
                          ),
                        ),
                        Text(
                          "6 Modules",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: subText,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // ─── 4. GRID OF MANAGEMENT CARDS ───
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: adminOptions.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 1.55,
                      ),
                      itemBuilder: (context, index) {
                        final item = adminOptions[index];
                        return _buildAdminCard(
                          icon: item['icon'] as IconData,
                          title: item['title'] as String,
                          subtitle: item['subtitle'] as String,
                          accentColor: item['color'] as Color,
                          badge: item['badge'] as String?,
                          badgeColor: item['badgeColor'] as Color?,
                          onTap: item['onTap'] as VoidCallback,
                        );
                      },
                    ),

                    const SizedBox(height: 22),

                    // ─── 5. RECENT BOOKINGS OVERVIEW ───
                    _buildRecentBookingsSection(),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
      ),
    );
  }

  // ─── HERO ADMIN BANNER ───
  Widget _buildAdminHeroBanner(double revenue, int todayCount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [darkNavy, primaryBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.admin_panel_settings_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "BusVerse Operations Panel",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "Live fleet, routes & booking management",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.today_rounded, color: Colors.white70, size: 15),
                    const SizedBox(width: 6),
                    Text(
                      "Today's Bookings: $todayCount",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Text(
                  "Rs. ${revenue.toStringAsFixed(0)}",
                  style: const TextStyle(
                    color: Color(0xFF86EFAC),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── KPI STATS ROW ───
  Widget _buildKpiStatsRow({
    required int totalBuses,
    required int totalRoutes,
    required int totalBookings,
    required int totalUsers,
  }) {
    return Row(
      children: [
        Expanded(
          child: _buildKpiCard(
            title: "Buses",
            count: "$totalBuses",
            icon: Icons.directions_bus_rounded,
            color: const Color(0xFF388AF6),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildKpiCard(
            title: "Routes",
            count: "$totalRoutes",
            icon: Icons.alt_route_rounded,
            color: const Color(0xFF0EA5E9),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildKpiCard(
            title: "Bookings",
            count: "$totalBookings",
            icon: Icons.confirmation_num_rounded,
            color: const Color(0xFF10B981),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildKpiCard(
            title: "Users",
            count: "$totalUsers",
            icon: Icons.people_rounded,
            color: const Color(0xFF8B5CF6),
          ),
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String count,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 15),
          ),
          const SizedBox(height: 5),
          Text(
            count,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: darkText,
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: subText,
            ),
          ),
        ],
      ),
    );
  }

  // ─── MANAGEMENT CARD ───
  Widget _buildAdminCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accentColor,
    required VoidCallback onTap,
    String? badge,
    Color? badgeColor,
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(icon, size: 18, color: accentColor),
                  ),
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (badgeColor ?? accentColor).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: badgeColor ?? accentColor,
                        ),
                      ),
                    ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: darkText,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: subText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── RECENT BOOKINGS SECTION ───
  Widget _buildRecentBookingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Recent Passenger Bookings",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: darkText,
              ),
            ),
            GestureDetector(
              onTap: () async {
                await Navigator.pushNamed(context, '/view_all_booking');
                _loadDashboardData();
              },
              child: const Text(
                "View All",
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: primaryBlue,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_recentBookings.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Column(
              children: [
                Icon(Icons.confirmation_number_outlined, color: Color(0xFFCBD5E1), size: 36),
                SizedBox(height: 8),
                Text(
                  "No bookings placed yet",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: subText),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _recentBookings.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = _recentBookings[index];
              final String busName = item['busName'] ?? 'Standard Bus';
              final String from = item['fromCity'] ?? '';
              final String to = item['toCity'] ?? '';
              final String date = item['travelDate'] ?? item['bookingDate'] ?? '';
              final dynamic seat = item['seatNumber'] ?? '';
              final String passenger = ((item['firstName'] != null || item['lastName'] != null)
                      ? "${item['firstName'] ?? ''} ${item['lastName'] ?? ''}".trim()
                      : item['userEmail'] ?? 'Passenger')
                  .trim();

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.confirmation_num_rounded, color: Color(0xFF10B981), size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "$from → $to",
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: darkText,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: primaryBlue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  "Seat #$seat",
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: primaryBlue,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Text(
                                passenger.isNotEmpty ? passenger : 'Passenger',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: subText,
                                ),
                              ),
                              const Text(" • ", style: TextStyle(color: subText, fontSize: 11)),
                              Text(
                                "$busName ($date)",
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: subText,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}


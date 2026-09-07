import 'package:flutter/material.dart';
import 'package:bus_ticket_system/database/db_helper.dart';

class NotificationsScreen extends StatefulWidget {
  final int userId;
  final String userEmail;

  const NotificationsScreen({
    super.key,
    required this.userId,
    required this.userEmail,
  });

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const Color primaryBlue = Color(0xFF388AF6);
  static const Color darkText = Color(0xFF1E293B);
  static const Color subText = Color(0xFF64748B);
  static const Color cardBg = Colors.white;

  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  String _selectedFilter = 'all'; // 'all', 'booking', 'promo', 'system'

  final List<Map<String, String>> _filterTabs = [
    {'id': 'all', 'label': 'All'},
    {'id': 'booking', 'label': '🎟️ Bookings'},
    {'id': 'promo', 'label': '🎁 Offers'},
    {'id': 'system', 'label': '🛡️ Updates'},
  ];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    final db = DBHelper.instance;

    // Auto-sync real booking data so existing bookings appear immediately
    await _syncUserBookingsToNotifications();

    List<Map<String, dynamic>> list = await db.getNotifications(
      userId: widget.userId,
      userEmail: widget.userEmail,
      typeFilter: _selectedFilter == 'all' ? null : _selectedFilter,
    );

    // If empty for a new user, seed friendly starter notifications
    if (list.isEmpty && _selectedFilter == 'all') {
      final totalCount = await db.getNotifications();
      if (totalCount.isEmpty) {
        await _seedStarterNotifications();
        list = await db.getNotifications();
      }
    }

    if (mounted) {
      setState(() {
        _notifications = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _syncUserBookingsToNotifications() async {
    final db = DBHelper.instance;
    try {
      final existingNotifs = await db.getNotifications();
      final Set<String> existingBodies = existingNotifs.map((e) => (e['body'] ?? '').toString()).toSet();

      // 1. Check local bookings
      final bookings = await db.getUserBookings(widget.userId);
      for (var b in bookings) {
        final String from = b['fromCity'] ?? 'Departure';
        final String to = b['toCity'] ?? 'Destination';
        final String seat = b['seatNumber']?.toString() ?? '';
        final String date = b['travelDate']?.toString() ?? b['bookingDate']?.toString() ?? '';
        final String busName = b['busName'] ?? 'Junaid Movers';

        final String notifBody = 'Your seat #$seat on $busName ($from → $to) is confirmed for $date. Have a safe journey with BusVerse!';

        if (!existingBodies.contains(notifBody)) {
          await db.insertNotification(
            userId: widget.userId,
            userEmail: widget.userEmail,
            title: '🎟️ Booking Confirmed: $from → $to',
            body: notifBody,
            type: 'booking',
            routeFrom: from,
            routeTo: to,
          );
          existingBodies.add(notifBody);
        }
      }

      // 2. Check payments table
      final payments = await db.getPayments();
      for (var p in payments) {
        if (p['email'] == widget.userEmail || widget.userEmail.isEmpty) {
          final String seats = p['seats']?.toString() ?? '';
          final String date = p['date']?.toString() ?? '';
          final double amount = (p['amount'] is num) ? (p['amount'] as num).toDouble() : 0.0;
          final String pName = p['passengerName'] ?? 'Passenger';

          Map<String, dynamic>? bus;
          if (p['busId'] != null && p['busId'] is int) {
            bus = await db.getBusById(p['busId'] as int);
          }
          final String from = bus?['fromCity'] ?? 'Departure';
          final String to = bus?['toCity'] ?? 'Destination';
          final String busName = bus?['busName'] ?? 'Junaid Movers';

          final String notifBody = 'Dear $pName, your booking on $busName is confirmed for Seat(s) $seats on $date. Total fare: PKR ${amount.toStringAsFixed(0)}.';

          if (!existingBodies.contains(notifBody)) {
            await db.insertNotification(
              userId: widget.userId,
              userEmail: widget.userEmail,
              title: '🎟️ Booking Confirmed: $from → $to',
              body: notifBody,
              type: 'booking',
              routeFrom: from,
              routeTo: to,
            );
            existingBodies.add(notifBody);
          }
        }
      }
    } catch (e) {
      debugPrint("Error syncing user bookings to notifications: $e");
    }
  }

  Future<void> _seedStarterNotifications() async {
    final db = DBHelper.instance;
    await db.insertNotification(
      userId: widget.userId,
      userEmail: widget.userEmail,
      title: '🎉 Welcome to BusVerse by Junaid Movers!',
      body: 'Experience premium intercity luxury bus travel. Enjoy live seat booking, instant tickets and 24/7 passenger assistance.',
      type: 'system',
    );
    await db.insertNotification(
      userId: widget.userId,
      userEmail: widget.userEmail,
      title: '🎁 Exclusive 15% OFF On First Booking!',
      body: 'Use promo code JUNAID15 at checkout to enjoy 15% instant discount on any Executive or Business class journey.',
      type: 'promo',
    );
    await db.insertNotification(
      userId: widget.userId,
      userEmail: widget.userEmail,
      title: '🛡️ Safety & Refreshment Assured',
      body: 'All active buses feature sanitized seating, complimentary refreshments, high-speed WiFi, and tracked routing for your peace of mind.',
      type: 'system',
    );
  }

  Future<void> _markAsRead(int id) async {
    await DBHelper.instance.markNotificationAsRead(id);
    _loadNotifications();
  }

  Future<void> _markAllAsRead() async {
    await DBHelper.instance.markAllNotificationsAsRead(
      userId: widget.userId,
      userEmail: widget.userEmail,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("All notifications marked as read"),
          backgroundColor: Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
    _loadNotifications();
  }

  Future<void> _deleteNotification(int id) async {
    await DBHelper.instance.deleteNotification(id);
    _loadNotifications();
  }

  Future<void> _clearAll() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 24),
            SizedBox(width: 8),
            Text("Clear Notifications", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
          ],
        ),
        content: const Text(
          "Are you sure you want to delete all notifications? This action cannot be undone.",
          style: TextStyle(color: subText, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel", style: TextStyle(color: subText)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Clear All", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DBHelper.instance.clearAllNotifications();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("All notifications cleared"),
            backgroundColor: Color(0xFF1E293B),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
      _loadNotifications();
    }
  }

  String _formatTimestamp(String? iso) {
    if (iso == null || iso.isEmpty) return "Recent";
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 1) return "Just now";
      if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
      if (diff.inHours < 24) return "${diff.inHours}h ago";
      if (diff.inDays == 1) return "Yesterday";
      if (diff.inDays < 7) return "${diff.inDays}d ago";
      return "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}";
    } catch (_) {
      return "Recent";
    }
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'booking':
        return const Color(0xFF16A34A); // Emerald Green
      case 'cancellation':
        return const Color(0xFFEF4444); // Crimson Red
      case 'promo':
        return const Color(0xFF8B5CF6); // Purple
      case 'trip':
        return primaryBlue; // Dodger Blue
      case 'system':
      default:
        return const Color(0xFFF59E0B); // Amber
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'booking':
        return Icons.confirmation_number_rounded;
      case 'cancellation':
        return Icons.event_busy_rounded;
      case 'promo':
        return Icons.local_offer_rounded;
      case 'trip':
        return Icons.directions_bus_rounded;
      case 'system':
      default:
        return Icons.notifications_active_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final int unreadCount = _notifications.where((n) => (n['isRead'] ?? 0) == 0).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: darkText, size: 20),
          onPressed: () => Navigator.pop(context, true),
        ),
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Notifications",
              style: TextStyle(
                color: darkText,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            if (unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: primaryBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "$unreadCount new",
                  style: const TextStyle(
                    color: primaryBlue,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (_notifications.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: darkText),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (value) {
                if (value == 'read_all') {
                  _markAllAsRead();
                } else if (value == 'clear_all') {
                  _clearAll();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'read_all',
                  child: Row(
                    children: [
                      Icon(Icons.done_all_rounded, size: 18, color: primaryBlue),
                      SizedBox(width: 10),
                      Text("Mark all as read", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'clear_all',
                  child: Row(
                    children: [
                      Icon(Icons.delete_sweep_rounded, size: 18, color: Colors.redAccent),
                      SizedBox(width: 10),
                      Text("Clear all notifications", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.redAccent)),
                    ],
                  ),
                ),
              ],
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // ─── FILTER TABS ───
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _filterTabs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final tab = _filterTabs[index];
                  final isSelected = _selectedFilter == tab['id'];

                  return GestureDetector(
                    onTap: () {
                      if (_selectedFilter != tab['id']) {
                        setState(() => _selectedFilter = tab['id']!);
                        _loadNotifications();
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? primaryBlue : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: primaryBlue.withValues(alpha: 0.25),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          tab['label']!,
                          style: TextStyle(
                            color: isSelected ? Colors.white : subText,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // ─── NOTIFICATIONS LIST ───
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: primaryBlue))
                : _notifications.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadNotifications,
                        color: primaryBlue,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          itemCount: _notifications.length,
                          itemBuilder: (context, index) {
                            final notif = _notifications[index];
                            return _buildNotificationCard(notif);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notif) {
    final int id = notif['id'] ?? 0;
    final String title = notif['title'] ?? 'Notification';
    final String body = notif['body'] ?? '';
    final String type = notif['type'] ?? 'system';
    final String time = _formatTimestamp(notif['timestamp']);
    final bool isRead = (notif['isRead'] ?? 0) == 1;
    final String fromCity = notif['routeFrom'] ?? '';
    final String toCity = notif['routeTo'] ?? '';

    final Color accentColor = _getTypeColor(type);
    final IconData icon = _getTypeIcon(type);

    return Dismissible(
      key: ValueKey('notif-$id'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.redAccent.shade400,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Delete", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            SizedBox(width: 8),
            Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
          ],
        ),
      ),
      onDismissed: (_) => _deleteNotification(id),
      child: GestureDetector(
        onTap: () {
          if (!isRead) _markAsRead(id);
          _handleNotificationTap(type);
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isRead ? cardBg : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isRead
                  ? const Color(0xFFE2E8F0)
                  : primaryBlue.withValues(alpha: 0.35),
              width: isRead ? 1 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isRead
                    ? Colors.black.withValues(alpha: 0.02)
                    : primaryBlue.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── ICON BADGE ───
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accentColor, size: 22),
              ),
              const SizedBox(width: 12),

              // ─── CONTENT ───
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              color: darkText,
                              fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (!isRead) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: primaryBlue,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      body,
                      style: TextStyle(
                        color: isRead ? subText : const Color(0xFF334155),
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // ─── FOOTER (Route Chip + Timestamp) ───
                    Row(
                      children: [
                        if (fromCity.isNotEmpty && toCity.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.route_rounded, size: 12, color: subText),
                                const SizedBox(width: 4),
                                Text(
                                  "$fromCity → $toCity",
                                  style: const TextStyle(
                                    color: subText,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                        ] else
                          const Spacer(),

                        Row(
                          children: [
                            const Icon(Icons.access_time_rounded, size: 12, color: subText),
                            const SizedBox(width: 4),
                            Text(
                              time,
                              style: const TextStyle(color: subText, fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleNotificationTap(String type) {
    if (type.toLowerCase() == 'booking' || type.toLowerCase() == 'cancellation') {
      Navigator.pushNamed(
        context,
        '/my_tickets',
        arguments: {'userId': widget.userId, 'userEmail': widget.userEmail},
      );
    } else if (type.toLowerCase() == 'promo') {
      Navigator.pushNamed(context, '/search_bus');
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: primaryBlue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_off_outlined,
                color: primaryBlue,
                size: 42,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "No Notifications Yet",
              style: TextStyle(
                color: darkText,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "You'll receive real-time updates when you book trips, receive promotional discounts, or when trip schedules change.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: subText,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/search_bus'),
              icon: const Icon(Icons.search_rounded, size: 18, color: Colors.white),
              label: const Text("Explore Bus Trips", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

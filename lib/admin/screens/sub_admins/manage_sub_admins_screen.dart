import 'package:flutter/material.dart';
import 'package:bus_ticket_system/database/db_helper.dart';
import 'package:bus_ticket_system/admin/screens/sub_admins/add_edit_sub_admin_screen.dart';

class ManageSubAdminsScreen extends StatefulWidget {
  const ManageSubAdminsScreen({super.key});

  @override
  State<ManageSubAdminsScreen> createState() => _ManageSubAdminsScreenState();
}

class _ManageSubAdminsScreenState extends State<ManageSubAdminsScreen> {
  List<Map<String, dynamic>> subAdmins = [];
  List<Map<String, dynamic>> filteredSubAdmins = [];
  bool isLoading = true;
  String searchQuery = "";
  final TextEditingController searchController = TextEditingController();

  static const Color primaryBlue = Color(0xFF388AF6);
  static const Color darkNavy = Color(0xFF1E3C72);
  static const Color darkText = Color(0xFF1E293B);
  static const Color subText = Color(0xFF64748B);
  static const Color bgSurface = Color(0xFFF8FAFC);
  static const Color borderColor = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    fetchSubAdmins();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> fetchSubAdmins() async {
    setState(() => isLoading = true);
    try {
      final list = await DBHelper.instance.getSubAdmins();
      setState(() {
        subAdmins = list;
        _applySearch();
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching sub-admins: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _applySearch() {
    if (searchQuery.trim().isEmpty) {
      filteredSubAdmins = List.from(subAdmins);
    } else {
      final q = searchQuery.toLowerCase().trim();
      filteredSubAdmins = subAdmins.where((admin) {
        final name = "${admin['firstName'] ?? ''} ${admin['lastName'] ?? ''}".toLowerCase();
        final email = (admin['email'] ?? '').toString().toLowerCase();
        final phone = (admin['phone'] ?? '').toString().toLowerCase();
        final city = (admin['terminalCity'] ?? '').toString().toLowerCase();
        final terminal = (admin['terminalName'] ?? '').toString().toLowerCase();
        return name.contains(q) ||
            email.contains(q) ||
            phone.contains(q) ||
            city.contains(q) ||
            terminal.contains(q);
      }).toList();
    }
  }

  Future<void> _openAddEditScreen({Map<String, dynamic>? existing}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditSubAdminScreen(existing: existing),
      ),
    );
    if (result == true) {
      fetchSubAdmins();
    }
  }

  Future<void> _toggleStatus(Map<String, dynamic> admin) async {
    final id = admin['id'] as int;
    final curStatus = (admin['status'] ?? 'active').toString();
    await DBHelper.instance.toggleSubAdminStatus(id, curStatus);
    await fetchSubAdmins();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(curStatus.toLowerCase() == 'active'
              ? "Agent account suspended"
              : "Agent account activated"),
          backgroundColor: curStatus.toLowerCase() == 'active' ? Colors.orange : Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deleteAdmin(Map<String, dynamic> admin) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 22),
            SizedBox(width: 8),
            Text("Delete Agent", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Text(
            "Are you sure you want to remove ${admin['firstName']} ${admin['lastName']} from terminal management?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel", style: TextStyle(color: subText)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DBHelper.instance.deleteSubAdmin(admin['id'] as int);
      await fetchSubAdmins();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Agent deleted successfully"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = subAdmins
        .where((a) => (a['status'] ?? 'active').toString().toLowerCase() == 'active')
        .length;
    final totalCities = subAdmins
        .map((a) => a['terminalCity'] ?? '')
        .toSet()
        .where((c) => c.isNotEmpty)
        .length;

    return Scaffold(
      backgroundColor: bgSurface,
      appBar: AppBar(
        title: const Text(
          "Terminal Agents",
          style: TextStyle(
            color: darkText,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: darkText, size: 19),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: Container(
        height: 38,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: primaryBlue.withValues(alpha: 0.28),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryBlue,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.add_rounded, size: 17, color: Colors.white),
          label: const Text(
            "Add Agent",
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
          onPressed: () => _openAddEditScreen(),
        ),
      ),
      body: Column(
        children: [
          // Top KPI Banner (Column layout inside cards - 0 overflow)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Row(
              children: [
                _buildKpiMiniCard("Total Agents", "${subAdmins.length}", Icons.people_alt_outlined, primaryBlue),
                const SizedBox(width: 8),
                _buildKpiMiniCard("Active", "$activeCount", Icons.check_circle_outline, const Color(0xFF10B981)),
                const SizedBox(width: 8),
                _buildKpiMiniCard("Cities", "$totalCities", Icons.location_city_outlined, const Color(0xFF8B5CF6)),
              ],
            ),
          ),

          // Search Field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.white,
            child: TextField(
              controller: searchController,
              onChanged: (val) {
                setState(() {
                  searchQuery = val;
                  _applySearch();
                });
              },
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: "Search by name, email, terminal or city...",
                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: primaryBlue),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16, color: subText),
                        onPressed: () {
                          searchController.clear();
                          setState(() {
                            searchQuery = "";
                            _applySearch();
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: bgSurface,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: primaryBlue, width: 1.5),
                ),
              ),
            ),
          ),

          const Divider(height: 1, color: borderColor),

          // List of Agents
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: primaryBlue))
                : filteredSubAdmins.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: primaryBlue.withAlpha(20),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.badge_outlined, size: 40, color: primaryBlue),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              "No Terminal Agents Found",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: darkText,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              "Tap '+ Add Agent' to register a new agent",
                              style: TextStyle(fontSize: 12, color: subText),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: filteredSubAdmins.length,
                        itemBuilder: (context, index) {
                          final admin = filteredSubAdmins[index];
                          return _buildAdminCard(admin);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiMiniCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withAlpha(12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withAlpha(40)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: subText),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminCard(Map<String, dynamic> admin) {
    final fname = admin['firstName'] ?? '';
    final lname = admin['lastName'] ?? '';
    final email = admin['email'] ?? '';
    final phone = admin['phone'] ?? '';
    final city = admin['terminalCity'] ?? 'All Cities';
    final terminal = admin['terminalName'] ?? 'Main Terminal';
    final status = (admin['status'] ?? 'active').toString().toLowerCase();
    final isActive = status == 'active';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isActive ? borderColor : Colors.orange.withAlpha(100)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Avatar, Name, Status Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: primaryBlue.withAlpha(30),
                child: Text(
                  fname.isNotEmpty ? fname[0].toUpperCase() : "A",
                  style: const TextStyle(
                    color: primaryBlue,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            "$fname $lname",
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: darkText,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isActive
                                ? const Color(0xFF10B981).withAlpha(30)
                                : Colors.orange.withAlpha(30),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isActive ? "ACTIVE" : "SUSPENDED",
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: isActive ? const Color(0xFF10B981) : Colors.orange[800],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: const TextStyle(fontSize: 12, color: subText),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          const Divider(height: 1, color: borderColor),
          const SizedBox(height: 10),

          // Terminal details pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: bgSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on_rounded, size: 14, color: primaryBlue),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "$city • $terminal",
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: darkNavy,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (phone.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.phone_rounded, size: 12, color: subText),
                  const SizedBox(width: 4),
                  Text(
                    phone,
                    style: const TextStyle(fontSize: 11, color: subText),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Actions Row
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Toggle Status Button
              InkWell(
                onTap: () => _toggleStatus(admin),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        isActive
                            ? Icons.pause_circle_outline_rounded
                            : Icons.play_circle_outline_rounded,
                        size: 14,
                        color: isActive ? Colors.orange : Colors.green,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isActive ? "Suspend" : "Activate",
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: isActive ? Colors.orange[800] : Colors.green[800],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Edit Button
              InkWell(
                onTap: () => _openAddEditScreen(existing: admin),
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 14, color: primaryBlue),
                      SizedBox(width: 4),
                      Text(
                        "Edit",
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: primaryBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Delete Button
              InkWell(
                onTap: () => _deleteAdmin(admin),
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline_rounded, size: 14, color: Colors.red),
                      SizedBox(width: 4),
                      Text(
                        "Delete",
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.red,
                        ),
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
}

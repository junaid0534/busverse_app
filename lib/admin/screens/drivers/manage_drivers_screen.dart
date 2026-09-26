import 'package:flutter/material.dart';
import 'package:bus_ticket_system/database/db_helper.dart';
import 'add_edit_driver_screen.dart';

class ManageDriversScreen extends StatefulWidget {
  const ManageDriversScreen({super.key});

  @override
  State<ManageDriversScreen> createState() => _ManageDriversScreenState();
}

class _ManageDriversScreenState extends State<ManageDriversScreen> {
  List<Map<String, dynamic>> _drivers = [];
  bool _isLoading = true;
  String _searchQuery = "";
  String _statusFilter = "all";

  static const Color primaryBlue = Color(0xFF388AF6);
  static const Color royalBlue = Color(0xFF2563EB);
  static const Color emeraldGreen = Color(0xFF10B981);
  static const Color roseDanger = Color(0xFFEF4444);
  static const Color darkText = Color(0xFF1E293B);
  static const Color subText = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _loadDrivers();
  }

  Future<void> _loadDrivers() async {
    setState(() => _isLoading = true);
    try {
      final list = await DBHelper.instance.getDrivers();
      if (mounted) {
        setState(() {
          _drivers = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredDrivers {
    return _drivers.where((d) {
      final name = "${d['firstName'] ?? ''} ${d['lastName'] ?? ''}".toLowerCase();
      final email = (d['email'] ?? '').toString().toLowerCase();
      final phone = (d['phone'] ?? '').toString();
      final bus = (d['assignedBusNumber'] ?? '').toString().toLowerCase();

      final matchesSearch = _searchQuery.isEmpty ||
          name.contains(_searchQuery.toLowerCase()) ||
          email.contains(_searchQuery.toLowerCase()) ||
          phone.contains(_searchQuery) ||
          bus.contains(_searchQuery.toLowerCase());

      final status = (d['status'] ?? 'active').toString().toLowerCase();
      final matchesStatus = _statusFilter == 'all' || status == _statusFilter;

      return matchesSearch && matchesStatus;
    }).toList();
  }

  Future<void> _toggleStatus(Map<String, dynamic> driver) async {
    final id = driver['id'];
    final currentStatus = driver['status'] ?? 'active';
    await DBHelper.instance.toggleDriverStatus(id, currentStatus);
    _loadDrivers();
  }

  Future<void> _deleteDriver(Map<String, dynamic> driver) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Delete Driver", style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text("Are you sure you want to remove Captain ${driver['firstName']}? This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel", style: TextStyle(color: subText)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: roseDanger, elevation: 0),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DBHelper.instance.deleteDriver(driver['id']);
      _loadDrivers();
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredDrivers;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: darkText),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Fleet Captains & Drivers",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: darkText),
            ),
            Text(
              "Commercial drivers & assigned fleet buses",
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: subText),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: primaryBlue),
            onPressed: _loadDrivers,
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primaryBlue,
        elevation: 3,
        icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 20),
        label: const Text("Add New Driver", style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
        onPressed: () async {
          final res = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddEditDriverScreen()),
          );
          if (res == true) _loadDrivers();
        },
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  decoration: InputDecoration(
                    hintText: "Search by driver name, phone, or bus number...",
                    hintStyle: const TextStyle(fontSize: 13, color: subText),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20, color: subText),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Status Filters
                Row(
                  children: [
                    _buildFilterPill("all", "All Captains (${_drivers.length})"),
                    const SizedBox(width: 8),
                    _buildFilterPill("active", "Active (${_drivers.where((d) => d['status'] == 'active').length})"),
                    const SizedBox(width: 8),
                    _buildFilterPill("suspended", "Suspended (${_drivers.where((d) => d['status'] == 'suspended').length})"),
                  ],
                ),
              ],
            ),
          ),

          // Drivers List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: primaryBlue))
                : list.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.badge_outlined, size: 60, color: Colors.grey.shade300),
                            const SizedBox(height: 14),
                            const Text(
                              "No Drivers Found",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: darkText),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              "Tap '+ Add New Driver' to register a company captain.",
                              style: TextStyle(fontSize: 12, color: subText),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          final driver = list[index];
                          return _buildDriverCard(driver);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPill(String key, String label) {
    final isSelected = _statusFilter == key;
    return InkWell(
      onTap: () => setState(() => _statusFilter = key),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? primaryBlue : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : subText,
          ),
        ),
      ),
    );
  }

  Widget _buildDriverCard(Map<String, dynamic> driver) {
    final String name = "${driver['firstName'] ?? ''} ${driver['lastName'] ?? ''}".trim();
    final String email = driver['email'] ?? 'N/A';
    final String phone = driver['phone'] ?? 'N/A';
    final String license = driver['licenseNo'] ?? driver['license_no'] ?? 'HTV-Verified';
    final String busNumber = driver['assignedBusNumber'] ?? driver['assigned_bus_number'] ?? 'Unassigned';
    final String route = driver['assignedRoute'] ?? driver['assigned_route'] ?? 'General Fleet';
    final bool isActive = (driver['status'] ?? 'active').toString().toLowerCase() == 'active';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 22,
                backgroundColor: primaryBlue.withOpacity(0.1),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'D',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: primaryBlue),
                ),
              ),
              const SizedBox(width: 12),

              // Name & Email
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isNotEmpty ? "Captain $name" : "Captain",
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: darkText),
                    ),
                    const SizedBox(height: 2),
                    Text(email, style: const TextStyle(fontSize: 11.5, color: subText)),
                  ],
                ),
              ),

              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isActive ? emeraldGreen : roseDanger).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isActive ? "ACTIVE" : "SUSPENDED",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isActive ? emeraldGreen : roseDanger,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),

          // Metadata Grid (Assigned Bus, Route, License)
          Row(
            children: [
              Expanded(
                child: _buildMetaItem(Icons.directions_bus_rounded, "ASSIGNED BUS", busNumber, primaryBlue),
              ),
              Expanded(
                child: _buildMetaItem(Icons.alt_route_rounded, "ROUTE", route, royalBlue),
              ),
              Expanded(
                child: _buildMetaItem(Icons.badge_rounded, "LICENSE NO.", license, subText),
              ),
            ],
          ),

          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.phone_rounded, size: 14, color: subText),
              const SizedBox(width: 6),
              Text(phone, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: darkText)),
              const Spacer(),

              // Edit Action
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18, color: primaryBlue),
                tooltip: "Edit Driver",
                onPressed: () async {
                  final res = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AddEditDriverScreen(existingDriver: driver)),
                  );
                  if (res == true) _loadDrivers();
                },
              ),

              // Toggle Status Action
              IconButton(
                icon: Icon(
                  isActive ? Icons.block_rounded : Icons.check_circle_outline_rounded,
                  size: 18,
                  color: isActive ? roseDanger : emeraldGreen,
                ),
                tooltip: isActive ? "Suspend Driver" : "Activate Driver",
                onPressed: () => _toggleStatus(driver),
              ),

              // Delete Action
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: roseDanger),
                tooltip: "Delete Driver",
                onPressed: () => _deleteDriver(driver),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetaItem(IconData icon, String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: subText)),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: darkText),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

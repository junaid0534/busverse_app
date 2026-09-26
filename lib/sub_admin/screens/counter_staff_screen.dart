import 'package:flutter/material.dart';
import 'package:bus_ticket_system/database/db_helper.dart';

class CounterStaffScreen extends StatefulWidget {
  final String terminalCity;
  final String terminalName;

  const CounterStaffScreen({
    super.key,
    required this.terminalCity,
    required this.terminalName,
  });

  @override
  State<CounterStaffScreen> createState() => _CounterStaffScreenState();
}

class _CounterStaffScreenState extends State<CounterStaffScreen> {
  static const Color primaryBlue = Color(0xFF388AF6);
  static const Color darkText = Color(0xFF1E293B);
  static const Color subText = Color(0xFF64748B);
  static const Color bgSurface = Color(0xFFF8FAFC);
  static const Color borderColor = Color(0xFFE2E8F0);

  bool _isLoading = true;
  List<Map<String, dynamic>> _agents = [];
  String _searchQuery = "";
  final TextEditingController _searchCtrl = TextEditingController();
  final Set<int> _revealedPins = {};

  @override
  void initState() {
    super.initState();
    _loadAgents();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAgents() async {
    setState(() => _isLoading = true);
    try {
      await DBHelper.instance.ensureAgentAndShiftTables();
      final list = await DBHelper.instance.getTerminalAgents(terminalCity: widget.terminalCity);
      if (mounted) {
        setState(() {
          _agents = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredAgents {
    if (_searchQuery.trim().isEmpty) return _agents;
    final q = _searchQuery.trim().toLowerCase();
    return _agents.where((a) {
      final name = (a['name'] ?? '').toString().toLowerCase();
      final code = (a['agentCode'] ?? '').toString().toLowerCase();
      final phone = (a['phone'] ?? '').toString().toLowerCase();
      return name.contains(q) || code.contains(q) || phone.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredAgents;

    return Scaffold(
      backgroundColor: bgSurface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: darkText, size: 18),
          onPressed: () => Navigator.pop(context, true),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Counter Staff & PINs",
              style: TextStyle(color: darkText, fontSize: 16, fontWeight: FontWeight.w700),
            ),
            Text(
              "${widget.terminalCity} • ${widget.terminalName}",
              style: const TextStyle(color: subText, fontSize: 11, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: primaryBlue, size: 20),
            tooltip: "Refresh List",
            onPressed: _loadAgents,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
        label: const Text(
          "Add Counter Agent",
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        onPressed: _showRegisterAgentModal,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryBlue))
          : RefreshIndicator(
              onRefresh: _loadAgents,
              color: primaryBlue,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Info Banner
                    _buildStatsBanner(),

                    const SizedBox(height: 14),

                    // Search Bar
                    _buildSearchBar(),

                    const SizedBox(height: 16),

                    // Section Heading
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "REGISTERED COUNTER AGENTS (${filtered.length})",
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: subText,
                          ),
                        ),
                        if (_agents.isNotEmpty)
                          Text(
                            "Tap PIN to Reveal",
                            style: TextStyle(fontSize: 10.5, color: primaryBlue.withValues(alpha: 0.8), fontWeight: FontWeight.w500),
                          ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Agent Cards List or Empty State
                    if (filtered.isEmpty)
                      _buildEmptyState()
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (ctx, idx) => _buildAgentCard(filtered[idx]),
                      ),

                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
    );
  }

  // ─── TOP STATS BANNER ───
  Widget _buildStatsBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryBlue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.badge_rounded, color: primaryBlue, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Terminal Shift Personnel",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: darkText),
                ),
                const SizedBox(height: 2),
                Text(
                  "Each duty agent uses their unique 4-digit PIN for clock-in & shift takeover.",
                  style: TextStyle(fontSize: 11, color: subText.withValues(alpha: 0.9), height: 1.3),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF16A34A)),
                ),
                const SizedBox(width: 5),
                Text(
                  "${_agents.length} Active",
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: darkText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── SEARCH BAR ───
  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: TextField(
        controller: _searchCtrl,
        style: const TextStyle(fontSize: 13, color: darkText),
        onChanged: (val) => setState(() => _searchQuery = val),
        decoration: InputDecoration(
          hintText: "Search agent by name, code or phone...",
          hintStyle: const TextStyle(fontSize: 12, color: subText),
          prefixIcon: const Icon(Icons.search_rounded, color: subText, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, color: subText, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _searchQuery = "");
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        ),
      ),
    );
  }

  // ─── AGENT CARD ───
  Widget _buildAgentCard(Map<String, dynamic> agent) {
    final int agentId = agent['id'] is int ? agent['id'] as int : int.tryParse(agent['id'].toString()) ?? 0;
    final String name = agent['name'] ?? 'Unnamed Agent';
    final String code = agent['agentCode'] ?? '-';
    final String phone = agent['phone'] ?? 'N/A';
    final String pin = (agent['pin'] ?? '0000').toString();
    final bool isPinRevealed = _revealedPins.contains(agentId);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 20,
                backgroundColor: primaryBlue.withValues(alpha: 0.12),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'A',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: primaryBlue),
                ),
              ),
              const SizedBox(width: 12),

              // Name & Code
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: darkText),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: primaryBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            code,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: primaryBlue),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.phone_outlined, size: 12, color: subText),
                        const SizedBox(width: 4),
                        Text(
                          phone.isNotEmpty ? phone : "No phone added",
                          style: const TextStyle(fontSize: 11.5, color: subText),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // PIN Badge (Tap to reveal)
              InkWell(
                onTap: () {
                  setState(() {
                    if (isPinRevealed) {
                      _revealedPins.remove(agentId);
                    } else {
                      _revealedPins.add(agentId);
                    }
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPinRevealed ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                        size: 13,
                        color: isPinRevealed ? primaryBlue : subText,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isPinRevealed ? pin : "••••",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: isPinRevealed ? 1.0 : 2.0,
                          color: isPinRevealed ? primaryBlue : darkText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          const Divider(height: 1, color: borderColor),
          const SizedBox(height: 8),

          // Bottom Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Edit Button
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.edit_outlined, size: 14, color: primaryBlue),
                label: const Text("Edit", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: primaryBlue)),
                onPressed: () => _showEditAgentModal(agent),
              ),
              const SizedBox(width: 8),

              // Delete Button
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.delete_outline_rounded, size: 14, color: Colors.redAccent),
                label: const Text("Delete", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.redAccent)),
                onPressed: () => _confirmDelete(agent),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── EMPTY STATE ───
  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: primaryBlue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_off_rounded, size: 28, color: primaryBlue),
          ),
          const SizedBox(height: 14),
          Text(
            _searchQuery.isNotEmpty ? "No matching staff found" : "No Counter Staff Registered",
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: darkText),
          ),
          const SizedBox(height: 6),
          Text(
            _searchQuery.isNotEmpty
                ? "Try searching with a different agent name, code, or phone."
                : "Add counter duty staff with security PINs to enable shift clock-in & handover.",
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11.5, color: subText),
          ),
          if (_searchQuery.isEmpty) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: _showRegisterAgentModal,
              label: const Text("Register First Agent", style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
            ),
          ],
        ],
      ),
    );
  }

  // ─── REGISTER NEW AGENT MODAL ───
  void _showRegisterAgentModal() {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final pinCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: borderColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Icon(Icons.person_add_alt_1_rounded, color: primaryBlue, size: 20),
                    SizedBox(width: 8),
                    Text(
                      "Register Counter Agent",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: darkText),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  "Create a duty profile for counter staff with a 4-digit security PIN.",
                  style: TextStyle(fontSize: 11.5, color: subText),
                ),
                const SizedBox(height: 16),

                // Name Input
                _buildField("Full Name", nameCtrl, hint: "e.g. Muhammad Asif"),
                const SizedBox(height: 12),

                // Code Input
                _buildField("Agent Code", codeCtrl, hint: "e.g. AGT-101"),
                const SizedBox(height: 12),

                // Phone Input
                _buildField("Phone Number", phoneCtrl, hint: "e.g. 03001234567", keyboardType: TextInputType.phone),
                const SizedBox(height: 12),

                // PIN Input
                _buildField(
                  "4-Digit Security PIN",
                  pinCtrl,
                  hint: "e.g. 1234",
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  obscureText: true,
                ),
                const SizedBox(height: 20),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: borderColor),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text("Cancel", style: TextStyle(fontSize: 13, color: darkText)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () async {
                          final name = nameCtrl.text.trim();
                          final code = codeCtrl.text.trim();
                          final phone = phoneCtrl.text.trim();
                          final pin = pinCtrl.text.trim();

                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Please enter agent full name.")),
                            );
                            return;
                          }
                          if (pin.length < 4) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Security PIN must be exactly 4 digits.")),
                            );
                            return;
                          }

                          Navigator.pop(ctx);
                          await DBHelper.instance.addTerminalAgent(
                            agentCode: code.isNotEmpty ? code : "AGT-${DateTime.now().millisecondsSinceEpoch % 1000}",
                            name: name,
                            pin: pin,
                            phone: phone,
                            terminalCity: widget.terminalCity,
                          );

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Agent '$name' registered successfully!"),
                                backgroundColor: const Color(0xFF16A34A),
                              ),
                            );
                            _loadAgents();
                          }
                        },
                        child: const Text("Save & Register", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── EDIT AGENT MODAL ───
  void _showEditAgentModal(Map<String, dynamic> agent) {
    final nameCtrl = TextEditingController(text: agent['name'] ?? '');
    final pinCtrl = TextEditingController(text: agent['pin']?.toString() ?? '');
    final phoneCtrl = TextEditingController(text: agent['phone']?.toString() ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: borderColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.edit_rounded, color: primaryBlue, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      "Edit Agent (${agent['agentCode']})",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: darkText),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                _buildField("Full Name", nameCtrl),
                const SizedBox(height: 12),

                _buildField("Phone Number", phoneCtrl, keyboardType: TextInputType.phone),
                const SizedBox(height: 12),

                _buildField(
                  "4-Digit Security PIN",
                  pinCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  obscureText: true,
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: borderColor),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text("Cancel", style: TextStyle(fontSize: 13, color: darkText)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () async {
                          final name = nameCtrl.text.trim();
                          final pin = pinCtrl.text.trim();
                          final phone = phoneCtrl.text.trim();

                          if (name.isEmpty || pin.length < 4) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Name and 4-digit PIN are required.")),
                            );
                            return;
                          }

                          Navigator.pop(ctx);
                          final agentId = agent['id'] is int ? agent['id'] as int : int.tryParse(agent['id'].toString()) ?? 0;
                          await DBHelper.instance.updateTerminalAgent(
                            agentId: agentId,
                            name: name,
                            pin: pin,
                            phone: phone,
                          );

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Agent updated successfully!"),
                                backgroundColor: Color(0xFF16A34A),
                              ),
                            );
                            _loadAgents();
                          }
                        },
                        child: const Text("Update Agent", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── CONFIRM DELETE ───
  void _confirmDelete(Map<String, dynamic> agent) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
            SizedBox(width: 8),
            Text("Delete Counter Agent", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Text(
          "Are you sure you want to delete ${agent['name']} (${agent['agentCode']})?\n\nThis will permanently remove this agent from local storage and cloud.",
          style: const TextStyle(fontSize: 12.5, color: darkText, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: subText)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final agentId = agent['id'] is int ? agent['id'] as int : int.tryParse(agent['id'].toString()) ?? 0;
              await DBHelper.instance.deleteTerminalAgent(
                agentId,
                agentCode: agent['agentCode'] as String?,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("${agent['name']} deleted successfully!"),
                    backgroundColor: Colors.redAccent,
                  ),
                );
                _loadAgents();
              }
            },
            child: const Text("Delete", style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ─── HELPER TEXT FIELD ───
  Widget _buildField(
    String label,
    TextEditingController ctrl, {
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    int? maxLength,
    bool obscureText = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: darkText),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: ctrl,
          keyboardType: keyboardType,
          maxLength: maxLength,
          obscureText: obscureText,
          style: const TextStyle(fontSize: 13, color: darkText),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 12, color: subText),
            counterText: "",
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
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
      ],
    );
  }
}

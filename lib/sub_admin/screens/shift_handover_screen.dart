import 'package:flutter/material.dart';
import 'package:bus_ticket_system/database/db_helper.dart';
import 'shift_slip_screen.dart';

class ShiftHandoverScreen extends StatefulWidget {
  final Map<String, dynamic> activeShift;
  final List<Map<String, dynamic>> registeredAgents;
  final String terminalCity;
  final String terminalName;
  final double netDrawerCash;
  final double cashRevenue;
  final double digitalRevenue;
  final int totalTickets;

  const ShiftHandoverScreen({
    super.key,
    required this.activeShift,
    required this.registeredAgents,
    required this.terminalCity,
    required this.terminalName,
    required this.netDrawerCash,
    required this.cashRevenue,
    required this.digitalRevenue,
    required this.totalTickets,
  });

  @override
  State<ShiftHandoverScreen> createState() => _ShiftHandoverScreenState();
}

class _ShiftHandoverScreenState extends State<ShiftHandoverScreen> {
  static const Color primaryBlue = Color(0xFF388AF6);
  static const Color darkText = Color(0xFF1E293B);
  static const Color subText = Color(0xFF64748B);
  static const Color bgSurface = Color(0xFFF8FAFC);
  static const Color borderColor = Color(0xFFE2E8F0);

  late Map<String, dynamic> _selectedIncomingAgent;
  late String _nextShiftType;
  final TextEditingController _outPinCtrl = TextEditingController();
  final TextEditingController _inPinCtrl = TextEditingController();
  late final TextEditingController _countedCashCtrl;
  bool _isProcessing = false;

  String get currentAgentName => widget.activeShift['agentName'] ?? 'Agent';
  String get currentAgentCode => widget.activeShift['agentCode'] ?? 'AGT-101';
  String get currentShiftType => widget.activeShift['shiftType'] ?? 'Morning';

  @override
  void initState() {
    super.initState();
    _countedCashCtrl = TextEditingController(text: widget.netDrawerCash.toStringAsFixed(0));
    _selectedIncomingAgent = widget.registeredAgents.firstWhere(
      (a) => a['agentCode'] != currentAgentCode,
      orElse: () => widget.registeredAgents.first,
    );
    _nextShiftType = currentShiftType == "Morning"
        ? "Evening"
        : (currentShiftType == "Evening" ? "Night" : "Morning");
  }

  @override
  void dispose() {
    _outPinCtrl.dispose();
    _inPinCtrl.dispose();
    _countedCashCtrl.dispose();
    super.dispose();
  }

  Future<void> _processHandover() async {
    final outPin = _outPinCtrl.text.trim();
    final inPin = _inPinCtrl.text.trim();

    if (outPin.length < 4 || inPin.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Both Outgoing and Incoming 4-digit PINs are required.")),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // 1. Verify Outgoing PIN
      final activeAgentId = widget.activeShift['agentId'] as int? ?? widget.registeredAgents.first['id'] as int;
      final outOk = await DBHelper.instance.verifyAgentPin(activeAgentId, outPin);
      if (outOk == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Outgoing Agent PIN verification failed!"), backgroundColor: Colors.red),
          );
          setState(() => _isProcessing = false);
        }
        return;
      }

      // 2. Verify Incoming PIN
      final inOk = await DBHelper.instance.verifyAgentPin(_selectedIncomingAgent['id'] as int, inPin);
      if (inOk == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Incoming Agent PIN verification failed!"), backgroundColor: Colors.red),
          );
          setState(() => _isProcessing = false);
        }
        return;
      }

      final countedCash = double.tryParse(_countedCashCtrl.text.trim()) ?? widget.netDrawerCash;
      final currentShiftId = widget.activeShift['id'] as int? ?? 1;

      await DBHelper.instance.closeAndHandoverShift(
        currentShiftId: currentShiftId,
        closingCash: countedCash,
        cashSales: widget.cashRevenue,
        digitalSales: widget.digitalRevenue,
        ticketsCount: widget.totalTickets,
        nextAgentId: _selectedIncomingAgent['id'] as int,
        nextAgentName: _selectedIncomingAgent['name'] ?? 'Agent',
        nextAgentCode: _selectedIncomingAgent['agentCode'] ?? 'AGT-02',
        nextShiftType: _nextShiftType,
        nextOpeningFloat: countedCash,
        terminalCity: widget.terminalCity,
        terminalName: widget.terminalName,
      );

      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Handover Complete! Control transferred to ${_selectedIncomingAgent['name']}"),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );

        // Replace with Slip Screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ShiftSlipScreen(
              shiftData: {
                'terminalCity': widget.terminalCity,
                'agentName': currentAgentName,
                'agentCode': currentAgentCode,
                'shiftType': currentShiftType,
                'openingFloat': widget.activeShift['openingFloat'] ?? 5000.0,
                'totalTickets': widget.totalTickets,
                'cashRevenue': widget.cashRevenue,
                'digitalRevenue': widget.digitalRevenue,
                'netDrawerCash': countedCash,
              },
              isHandoverSummary: true,
              prevAgent: currentAgentName,
              nextAgent: _selectedIncomingAgent['name'],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error during handover: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgSurface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: darkText, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Secure Counter Handover",
          style: TextStyle(color: darkText, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Summary Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: primaryBlue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.swap_horiz_rounded, color: primaryBlue, size: 22),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(currentAgentName, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: darkText)),
                              Text("Outgoing Agent • $currentShiftType Shift", style: const TextStyle(fontSize: 11, color: subText)),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: primaryBlue.withValues(alpha: 0.3)),
                        ),
                        child: Text(currentAgentCode, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: primaryBlue)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: borderColor),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Tickets Issued This Shift:", style: TextStyle(fontSize: 12, color: subText)),
                      Text("${widget.totalTickets}", style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: darkText)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Shift Cash Sales:", style: TextStyle(fontSize: 12, color: subText)),
                      Text("PKR ${widget.cashRevenue.toStringAsFixed(0)}", style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: darkText)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Expected Cash in Drawer:", style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: darkText)),
                      Text("PKR ${widget.netDrawerCash.toStringAsFixed(0)}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF16A34A))),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Step 1: Counted Physical Cash
            _sectionHeader("1. PHYSICAL CASH RECONCILIATION"),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Actual Counted Physical Cash (PKR)", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: subText)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _countedCashCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.point_of_sale_rounded, color: primaryBlue, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: borderColor)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: borderColor)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: primaryBlue, width: 1.5)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Step 2: Outgoing Agent Verification
            _sectionHeader("2. OUTGOING AGENT VERIFICATION ($currentAgentName)"),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Enter 4-Digit Security PIN to confirm departure & cash handover", style: TextStyle(fontSize: 11, color: subText)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _outPinCtrl,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 4,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 4),
                    decoration: InputDecoration(
                      counterText: "",
                      hintText: "••••",
                      prefixIcon: const Icon(Icons.lock_outline_rounded, color: primaryBlue, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: borderColor)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: borderColor)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: primaryBlue, width: 1.5)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Step 3: Incoming Agent Selection & Verification
            _sectionHeader("3. INCOMING AGENT (NEXT ON DUTY)"),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Select Incoming Staff", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: subText)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: bgSurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderColor),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        isExpanded: true,
                        value: _selectedIncomingAgent['id'] as int,
                        items: widget.registeredAgents.map((ag) {
                          return DropdownMenuItem<int>(
                            value: ag['id'] as int,
                            child: Text("${ag['name']} (${ag['agentCode']})", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedIncomingAgent = widget.registeredAgents.firstWhere((a) => a['id'] == val);
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Next Shift Timing", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: subText)),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: bgSurface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: borderColor),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  value: _nextShiftType,
                                  items: const [
                                    DropdownMenuItem(value: "Morning", child: Text("Morning", style: TextStyle(fontSize: 12))),
                                    DropdownMenuItem(value: "Evening", child: Text("Evening", style: TextStyle(fontSize: 12))),
                                    DropdownMenuItem(value: "Night", child: Text("Night", style: TextStyle(fontSize: 12))),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) setState(() => _nextShiftType = val);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Incoming PIN", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: subText)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _inPinCtrl,
                              keyboardType: TextInputType.number,
                              obscureText: true,
                              maxLength: 4,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 4),
                              decoration: InputDecoration(
                                counterText: "",
                                hintText: "••••",
                                prefixIcon: const Icon(Icons.pin_rounded, color: primaryBlue, size: 18),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: borderColor)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: borderColor)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: primaryBlue, width: 1.5)),
                                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _isProcessing
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.verified_user_rounded, size: 18),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: _isProcessing ? null : _processHandover,
                label: Text(
                  _isProcessing ? "Verifying PINs & Transferring..." : "Verify Dual PINs & Complete Handover",
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: subText, letterSpacing: 0.5),
    );
  }
}

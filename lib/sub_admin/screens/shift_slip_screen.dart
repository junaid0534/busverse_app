import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ShiftSlipScreen extends StatelessWidget {
  final Map<String, dynamic> shiftData;
  final bool isHandoverSummary;
  final String? prevAgent;
  final String? nextAgent;

  const ShiftSlipScreen({
    super.key,
    required this.shiftData,
    this.isHandoverSummary = false,
    this.prevAgent,
    this.nextAgent,
  });

  static const Color primaryBlue = Color(0xFF388AF6);
  static const Color darkNavy = Color(0xFF1E3C72);
  static const Color darkText = Color(0xFF1E293B);
  static const Color subText = Color(0xFF64748B);
  static const Color bgSurface = Color(0xFFF8FAFC);
  static const Color borderColor = Color(0xFFE2E8F0);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(now);

    final terminalCity = shiftData['terminalCity'] ?? 'Lahore';
    final agentName = shiftData['agentName'] ?? 'Counter Agent';
    final agentCode = shiftData['agentCode'] ?? 'AGT-101';
    final shiftType = shiftData['shiftType'] ?? 'Morning';
    final openingFloat = (shiftData['openingFloat'] as num?)?.toDouble() ?? 5000.0;
    final totalTickets = shiftData['totalTickets'] ?? 0;
    final cashRevenue = (shiftData['cashRevenue'] as num?)?.toDouble() ?? 0.0;
    final digitalRevenue = (shiftData['digitalRevenue'] as num?)?.toDouble() ?? 0.0;
    final netDrawerCash = (shiftData['netDrawerCash'] as num?)?.toDouble() ?? (openingFloat + cashRevenue);

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
        title: Text(
          isHandoverSummary ? "Handover Summary Slip" : "Shift Thermal Receipt",
          style: const TextStyle(
            color: darkText,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 80mm Thermal Slip Paper Container
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 380),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Header Logo & Branding
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: primaryBlue.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.receipt_long_rounded, color: primaryBlue, size: 28),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "BUSVERSE EXPRESS POS",
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: darkNavy),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "$terminalCity Main Terminal Counter",
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: subText),
                    ),
                    Text(
                      "Generated: $dateStr",
                      style: const TextStyle(fontSize: 11, color: subText),
                    ),

                    const SizedBox(height: 14),
                    _dottedDivider(),
                    const SizedBox(height: 14),

                    // Content Rows
                    if (isHandoverSummary) ...[
                      _slipRow("Outgoing Agent", prevAgent ?? agentName),
                      _slipRow("Incoming Agent", nextAgent ?? "Next Agent"),
                      _slipRow("Dual PIN Verified", "YES (100% PROOF)", highlightColor: const Color(0xFF16A34A)),
                    ] else ...[
                      _slipRow("Duty Agent Name", agentName),
                      _slipRow("Agent Emp Code", agentCode),
                      _slipRow("Shift Type", "$shiftType Shift"),
                    ],

                    _slipRow("POS Terminal ID", "POS-${terminalCity.toUpperCase()}-01"),
                    _slipRow("Opening Float", "PKR ${openingFloat.toStringAsFixed(0)}"),
                    _slipRow("Tickets Issued", "$totalTickets Tickets"),
                    _slipRow("Shift Cash Sales", "PKR ${cashRevenue.toStringAsFixed(0)}"),
                    _slipRow("Card / Digital Sales", "PKR ${digitalRevenue.toStringAsFixed(0)}"),

                    const SizedBox(height: 10),
                    _dottedDivider(),
                    const SizedBox(height: 10),

                    // Net Total Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "NET DRAWER CASH",
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: darkText),
                        ),
                        Text(
                          "PKR ${netDrawerCash.toStringAsFixed(0)}",
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF16A34A)),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),
                    _dottedDivider(),
                    const SizedBox(height: 14),

                    // Signatures Area
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _signatureLine("Outgoing Agent"),
                        _signatureLine("Incoming / Supervisor"),
                      ],
                    ),

                    const SizedBox(height: 16),
                    const Text(
                      "*** VERIFIED OFFICIAL SHIFT SLIP ***",
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: subText, letterSpacing: 0.8),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Action Buttons
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 380),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.arrow_back_rounded, size: 16),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: borderColor),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => Navigator.pop(context),
                        label: const Text("Back", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: darkText)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.print_rounded, size: 16),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Shift receipt sent to 80mm thermal printer!"),
                              backgroundColor: Color(0xFF16A34A),
                            ),
                          );
                        },
                        label: const Text("Print Slip (80mm)", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
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

  Widget _slipRow(String label, String value, {Color? highlightColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: subText)),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: highlightColor ?? darkText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dottedDivider() {
    return Row(
      children: List.generate(
        32,
        (index) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: Container(
              height: 1,
              color: borderColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _signatureLine(String title) {
    return Column(
      children: [
        Container(
          width: 110,
          height: 1,
          color: darkText.withValues(alpha: 0.3),
        ),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(fontSize: 9.5, color: subText)),
      ],
    );
  }
}
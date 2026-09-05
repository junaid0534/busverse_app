import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bus_ticket_system/admin/models/bus_model.dart';
import 'package:bus_ticket_system/database/db_helper.dart';
import 'package:bus_ticket_system/services/supabase_service.dart';
import 'view_ticket_screen.dart';
import 'passenger_detail_screen.dart';

class PaymentScreen extends StatefulWidget {
  final BusModel bus;
  final List<int> selectedSeats;
  final String date;
  final Map<String, dynamic> passengerData;

  const PaymentScreen({
    super.key,
    required this.bus,
    required this.selectedSeats,
    required this.date,
    required this.passengerData,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentStep = 0; // 0: Order Review & Promo, 1: Select Method, 2: Enter Details & Pay

  String selectedPayment = "JazzCash";

  // Form Controllers
  final TextEditingController accountController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController promoController = TextEditingController();

  // Card Controllers
  final TextEditingController cardNumberController = TextEditingController();
  final TextEditingController cardHolderController = TextEditingController();
  final TextEditingController cardExpiryController = TextEditingController();
  final TextEditingController cardCvvController = TextEditingController();

  // Timer state (10-minute seat lock)
  Timer? _countdownTimer;
  int _secondsRemaining = 599; // 9:59

  // Promo Code State
  double _discountAmount = 0.0;
  String _appliedPromoCode = "";
  String _promoMessage = "";
  bool _isPromoApplied = false;

  // Realtime Gateway Processing Status
  int _processingStep = 0; // 0: connecting, 1: authorizing, 2: reserving, 3: success
  bool _isProcessing = false;

  // Wallet simulated balance
  final double _walletBalance = 8500.0;

  static const Color primaryBlue = Color(0xFF388AF6);
  static const Color darkNavy = Color(0xFF1E3C72);
  static const Color darkText = Color(0xFF1E293B);
  static const Color subText = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();

    if (widget.passengerData['email'] != null &&
        widget.passengerData['email'].toString().isNotEmpty) {
      emailController.text = widget.passengerData['email'].toString();
    }
    if (widget.passengerData['phone'] != null &&
        widget.passengerData['phone'].toString().isNotEmpty) {
      accountController.text = widget.passengerData['phone'].toString();
    }
    if (widget.passengerData['name'] != null &&
        widget.passengerData['name'].toString().isNotEmpty) {
      cardHolderController.text = widget.passengerData['name'].toString().toUpperCase();
    }

    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        if (mounted) {
          setState(() {
            _secondsRemaining--;
          });
        }
      } else {
        timer.cancel();
        if (mounted) {
          _showSessionExpiredDialog();
        }
      }
    });
  }

  void _showSessionExpiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.timer_off_outlined, color: Colors.redAccent),
            SizedBox(width: 8),
            Text("Session Expired", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          "Your 10-minute seat reservation hold has expired. Please re-select your seats to proceed.",
          style: TextStyle(fontSize: 13, color: subText),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text("Select Seats Again"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pageController.dispose();
    accountController.dispose();
    emailController.dispose();
    promoController.dispose();
    cardNumberController.dispose();
    cardHolderController.dispose();
    cardExpiryController.dispose();
    cardCvvController.dispose();
    super.dispose();
  }

  String _formatTimer(int totalSeconds) {
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }

  void _goToStep(int step) {
    setState(() => _currentStep = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _handleBackNavigation() {
    if (_currentStep > 0) {
      _goToStep(_currentStep - 1);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PassengerDetailScreen(
            bus: widget.bus,
            selectedSeats: widget.selectedSeats,
            date: widget.date,
            genderMap: (widget.passengerData['genderMap'] is Map)
                ? Map<int, String>.from(widget.passengerData['genderMap'])
                : null,
            userId: widget.passengerData['userId'],
          ),
        ),
      );
    }
  }

  void _applyPromo() {
    final code = promoController.text.trim().toUpperCase();
    final double rawTotal = widget.selectedSeats.length * widget.bus.fare;

    if (code.isEmpty) return;

    if (code == "BUSVERSE" || code == "JUNAID10") {
      setState(() {
        _discountAmount = rawTotal * 0.10; // 10% discount
        _appliedPromoCode = code;
        _isPromoApplied = true;
        _promoMessage = "10% Discount applied successfully!";
      });
    } else if (code == "DISCOUNT20") {
      setState(() {
        _discountAmount = rawTotal * 0.20; // 20% discount
        _appliedPromoCode = code;
        _isPromoApplied = true;
        _promoMessage = "20% Discount applied successfully!";
      });
    } else if (code == "WELCOME") {
      setState(() {
        _discountAmount = 300.0; // flat PKR 300
        _appliedPromoCode = code;
        _isPromoApplied = true;
        _promoMessage = "PKR 300 Welcome Voucher applied!";
      });
    } else {
      setState(() {
        _promoMessage = "Invalid promo code. Try 'BUSVERSE' or 'WELCOME'";
        _isPromoApplied = false;
        _discountAmount = 0.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final double rawTotal = widget.selectedSeats.length * widget.bus.fare;
    final double finalPayable = (rawTotal - _discountAmount).clamp(0.0, double.infinity);

    final List<String> stepTitles = [
      "Review & Summary",
      "Payment Method",
      "Pay & Confirm",
    ];

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _handleBackNavigation();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          centerTitle: true,
          title: Text(
            stepTitles[_currentStep],
            style: const TextStyle(
              color: darkText,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: darkText, size: 20),
            onPressed: _handleBackNavigation,
          ),
        ),
        body: Column(
          children: [
            // ─── STEP PROGRESS HEADER INDICATOR ───
            _buildStepIndicator(),

            // ─── MULTI-STEP PAGE VIEW ───
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  // Step 1: Order Breakdown & Promo
                  _buildStep1OrderSummary(rawTotal, finalPayable),

                  // Step 2: Payment Gateway Selection
                  _buildStep2SelectPayment(finalPayable),

                  // Step 3: Payment Details & Authorization
                  _buildStep3PaymentDetails(finalPayable),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── STEP PROGRESS BAR ───
  Widget _buildStepIndicator() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          _stepNode(0, "Summary"),
          _stepDivider(0),
          _stepNode(1, "Method"),
          _stepDivider(1),
          _stepNode(2, "Payment"),
        ],
      ),
    );
  }

  Widget _stepNode(int stepIndex, String title) {
    final bool isCompleted = _currentStep > stepIndex;
    final bool isCurrent = _currentStep == stepIndex;

    Color circleColor = isCompleted
        ? const Color(0xFF16A34A)
        : (isCurrent ? primaryBlue : const Color(0xFFE2E8F0));
    Color textColor = isCurrent ? primaryBlue : (isCompleted ? const Color(0xFF16A34A) : subText);

    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: circleColor,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : Text(
                    "${stepIndex + 1}",
                    style: TextStyle(
                      color: isCurrent ? Colors.white : subText,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
            color: textColor,
          ),
        ),
      ],
    );
  }

  Widget _stepDivider(int stepIndex) {
    final bool isPassed = _currentStep > stepIndex;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        height: 2,
        color: isPassed ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0),
      ),
    );
  }

  // =========================================================================
  // ─── STEP 1 SCREEN: ORDER SUMMARY & PROMO CODE ───
  // =========================================================================
  Widget _buildStep1OrderSummary(double rawTotal, double finalPayable) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ⏱️ Seat Hold Countdown Timer Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _secondsRemaining < 120
                    ? [const Color(0xFFFEE2E2), const Color(0xFFFFEDD5)]
                    : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _secondsRemaining < 120 ? const Color(0xFFFCA5A5) : const Color(0xFF93C5FD),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lock_clock_rounded,
                  color: _secondsRemaining < 120 ? Colors.redAccent : primaryBlue,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Seats ${widget.selectedSeats.map((s) => "#$s").join(", ")} held for you",
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: _secondsRemaining < 120 ? Colors.red.shade900 : const Color(0xFF1E40AF),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Text(
                    _formatTimer(_secondsRemaining),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'monospace',
                      color: _secondsRemaining < 120 ? Colors.redAccent : primaryBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // 🚌 Trip Details Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: primaryBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.directions_bus_rounded, color: primaryBlue, size: 18),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "${widget.bus.fromCity} → ${widget.bus.toCity}",
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: darkText),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        widget.bus.busClass,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: subText),
                      ),
                    ),
                  ],
                ),
                const Divider(color: Color(0xFFF1F5F9), height: 20),
                _summaryRow("Travel Date & Time", "${widget.date} • ${widget.bus.time}"),
                const SizedBox(height: 6),
                _summaryRow("Selected Seats (${widget.selectedSeats.length})", widget.selectedSeats.map((s) => "Seat #$s").join(", ")),
                const SizedBox(height: 6),
                _summaryRow("Primary Passenger", widget.passengerData["name"] ?? "Valued Passenger"),
                const SizedBox(height: 6),
                _summaryRow("CNIC Number", widget.passengerData["cnic"] ?? "N/A"),
                const SizedBox(height: 6),
                _summaryRow("Contact Phone", widget.passengerData["phone"] ?? "N/A"),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // 🎟️ Promo Code Box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.discount_outlined, size: 16, color: primaryBlue),
                    SizedBox(width: 6),
                    Text(
                      "Apply Promo / Discount Voucher",
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: darkText),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: promoController,
                        textCapitalization: TextCapitalization.characters,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1.1),
                        decoration: InputDecoration(
                          hintText: "Enter BUSVERSE or WELCOME",
                          hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8), letterSpacing: 0),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _applyPromo,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      child: const Text("Apply", style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                if (_promoMessage.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    _promoMessage,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _isPromoApplied ? const Color(0xFF16A34A) : Colors.redAccent,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 14),

          // 💳 Fare Breakdown Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                _summaryRow("Fare per Seat", "PKR ${widget.bus.fare.toStringAsFixed(0)}"),
                const SizedBox(height: 6),
                _summaryRow("Total Seats Fare (${widget.selectedSeats.length}x)", "PKR ${rawTotal.toStringAsFixed(0)}"),
                if (_isPromoApplied) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Promo Discount ($_appliedPromoCode)", style: const TextStyle(fontSize: 12, color: Color(0xFF16A34A), fontWeight: FontWeight.w600)),
                      Text("- PKR ${_discountAmount.toStringAsFixed(0)}", style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF16A34A))),
                    ],
                  ),
                ],
                const Divider(color: Color(0xFFF1F5F9), height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Total Payable", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: darkText)),
                    Text(
                      "PKR ${finalPayable.toStringAsFixed(0)}",
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: primaryBlue),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 🚀 Continue to Step 2 Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () => _goToStep(1),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Continue to Payment Method", style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // =========================================================================
  // ─── STEP 2 SCREEN: SELECT PAYMENT METHOD ───
  // =========================================================================
  Widget _buildStep2SelectPayment(double finalPayable) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Total Amount Banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Payable Amount", style: TextStyle(fontSize: 11.5, color: subText, fontWeight: FontWeight.w600)),
                    Text("Total for Booking", style: TextStyle(fontSize: 13, color: darkText, fontWeight: FontWeight.w700)),
                  ],
                ),
                Text(
                  "PKR ${finalPayable.toStringAsFixed(0)}",
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: primaryBlue),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          const Text(
            "Choose Payment Gateway",
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: darkText),
          ),
          const SizedBox(height: 10),

          _paymentOptionCard(
            title: "JazzCash",
            subtitle: "Instant Mobile Account / MPIN Authorization",
            icon: Icons.flash_on_rounded,
            badgeText: "INSTANT",
            badgeColor: const Color(0xFFDC2626),
            color: const Color(0xFFDC2626),
          ),
          _paymentOptionCard(
            title: "Easypaisa",
            subtitle: "Live Mobile Wallet & Push Prompt",
            icon: Icons.account_balance_wallet_rounded,
            badgeText: "POPULAR",
            badgeColor: const Color(0xFF059669),
            color: const Color(0xFF059669),
          ),
          _paymentOptionCard(
            title: "Credit / Debit Card",
            subtitle: "Visa, MasterCard, PayPak (3D Secure)",
            icon: Icons.credit_card_rounded,
            badgeText: "256-BIT SSL",
            badgeColor: const Color(0xFF2563EB),
            color: const Color(0xFF2563EB),
          ),
          _paymentOptionCard(
            title: "BusVerse Wallet",
            subtitle: "Available Balance: PKR ${_walletBalance.toStringAsFixed(0)}",
            icon: Icons.account_balance_wallet_outlined,
            badgeText: "1-CLICK",
            badgeColor: primaryBlue,
            color: primaryBlue,
          ),
          _paymentOptionCard(
            title: "Cash at Terminal Counter",
            subtitle: "Pay in-person 30 mins before departure",
            icon: Icons.storefront_rounded,
            badgeText: "COUNTER",
            badgeColor: const Color(0xFF475569),
            color: const Color(0xFF475569),
          ),

          const SizedBox(height: 24),

          // Action Buttons: Back + Continue
          Row(
            children: [
              Expanded(
                flex: 1,
                child: OutlinedButton(
                  onPressed: () => _goToStep(0),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text("Back", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: darkText)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () => _goToStep(2),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Continue", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      SizedBox(width: 6),
                      Icon(Icons.arrow_forward_rounded, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // =========================================================================
  // ─── STEP 3 SCREEN: ENTER PAYMENT DETAILS & PAY ───
  // =========================================================================
  Widget _buildStep3PaymentDetails(double finalPayable) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selected Method Header Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF93C5FD)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.verified_rounded, color: primaryBlue, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      "Method: $selectedPayment",
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E40AF)),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => _goToStep(1),
                  child: const Text("Change", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: primaryBlue)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Dynamic form for chosen method
          _buildDynamicPaymentForm(finalPayable),

          const SizedBox(height: 16),

          // SSL Assurance
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shield_rounded, color: Color(0xFF059669), size: 16),
                SizedBox(width: 6),
                Text(
                  "State Bank & 256-Bit SSL Encrypted Gateway",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: subText),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Final Confirm & Pay Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : () => _initiateRealtimePayment(finalPayable),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                elevation: 2,
                shadowColor: primaryBlue.withOpacity(0.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isProcessing
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock_rounded, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          "Pay PKR ${finalPayable.toStringAsFixed(0)} & Confirm",
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ─── DYNAMIC PAYMENT FORM ───
  Widget _buildDynamicPaymentForm(double totalAmount) {
    if (selectedPayment == "Credit / Debit Card") {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInteractiveCardPreview(),
            const SizedBox(height: 16),

            const Text("Card Number", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: darkText)),
            const SizedBox(height: 5),
            TextField(
              controller: cardNumberController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(16),
                _CardNumberInputFormatter(),
              ],
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1.2),
              decoration: _inputDecoration(hint: "0000 0000 0000 0000", icon: Icons.credit_card_rounded),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Expiry (MM/YY)", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: darkText)),
                      const SizedBox(height: 5),
                      TextField(
                        controller: cardExpiryController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                          _CardExpiryInputFormatter(),
                        ],
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                        decoration: _inputDecoration(hint: "MM/YY", icon: Icons.calendar_month_rounded),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("CVV / CVC", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: darkText)),
                      const SizedBox(height: 5),
                      TextField(
                        controller: cardCvvController,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                        decoration: _inputDecoration(hint: "123", icon: Icons.shield_rounded),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            const Text("Cardholder Name", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: darkText)),
            const SizedBox(height: 5),
            TextField(
              controller: cardHolderController,
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
              decoration: _inputDecoration(hint: "NAME AS ON CARD", icon: Icons.person_rounded),
            ),

            const SizedBox(height: 12),
            _buildEmailField(),
          ],
        ),
      );
    } else if (selectedPayment == "BusVerse Wallet") {
      final bool hasSufficient = _walletBalance >= totalAmount;
      final double remaining = _walletBalance - totalAmount;

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [darkNavy, primaryBlue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("BusVerse In-App Wallet", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                      Icon(Icons.wallet_rounded, color: Colors.white, size: 20),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text("PKR ${_walletBalance.toStringAsFixed(0)}", style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  const Divider(color: Colors.white24, height: 1),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Balance after deduction:", style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                      Text(
                        hasSufficient ? "PKR ${remaining.toStringAsFixed(0)}" : "Insufficient Balance",
                        style: TextStyle(
                          color: hasSufficient ? const Color(0xFF86EFAC) : Colors.amberAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _buildEmailField(),
          ],
        ),
      );
    } else if (selectedPayment == "Cash at Terminal Counter") {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: primaryBlue, size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Your seats will be reserved. Please pay cash at the Junaid Movers departure counter at least 30 minutes before bus departure.",
                      style: TextStyle(fontSize: 12, color: darkText, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text("Contact Mobile Number for SMS Ticket", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: darkText)),
            const SizedBox(height: 5),
            TextField(
              controller: accountController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
              decoration: _inputDecoration(hint: "03001234567", icon: Icons.phone_iphone_rounded),
            ),
            const SizedBox(height: 12),
            _buildEmailField(),
          ],
        ),
      );
    } else {
      // JazzCash or Easypaisa
      final bool isJazz = selectedPayment == "JazzCash";

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (isJazz ? const Color(0xFFDC2626) : const Color(0xFF059669)).withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: (isJazz ? const Color(0xFFDC2626) : const Color(0xFF059669)).withOpacity(0.2),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.bolt_rounded,
                    color: isJazz ? const Color(0xFFDC2626) : const Color(0xFF059669),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "A real-time prompt will appear on your $selectedPayment App to authorize PKR ${totalAmount.toStringAsFixed(0)}.",
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isJazz ? const Color(0xFF991B1B) : const Color(0xFF065F46),
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            Text(
              "$selectedPayment Registered Mobile Number",
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: darkText),
            ),
            const SizedBox(height: 5),
            TextField(
              controller: accountController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
              decoration: _inputDecoration(hint: "03XXXXXXXXX", icon: Icons.phone_android_rounded),
            ),

            const SizedBox(height: 14),
            _buildEmailField(),
          ],
        ),
      );
    }
  }

  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Email Address for Official PDF E-Ticket",
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: darkText),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
          decoration: _inputDecoration(
            hint: "Enter your email for receipt & e-ticket",
            icon: Icons.email_outlined,
          ),
        ),
      ],
    );
  }

  // ─── LIVE VIRTUAL CARD PREVIEW WIDGET ───
  Widget _buildInteractiveCardPreview() {
    final String cardNum = cardNumberController.text.isEmpty ? "•••• •••• •••• ••••" : cardNumberController.text;
    final String holder = cardHolderController.text.isEmpty ? "CARDHOLDER NAME" : cardHolderController.text;
    final String expiry = cardExpiryController.text.isEmpty ? "MM/YY" : cardExpiryController.text;

    final String cleanNum = cardNumberController.text.replaceAll(' ', '');
    String cardBrand = "CARD";
    if (cleanNum.startsWith('4')) {
      cardBrand = "VISA";
    } else if (cleanNum.startsWith('5')) {
      cardBrand = "MASTERCARD";
    } else if (cleanNum.startsWith('6')) {
      cardBrand = "PAYPAK";
    }

    return Container(
      height: 175,
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E3A8A), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 36,
                height: 26,
                decoration: BoxDecoration(
                  color: const Color(0xFFFBBF24),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFD97706), width: 1.2),
                ),
                child: const Icon(Icons.contactless_rounded, size: 16, color: Color(0xFF78350F)),
              ),
              Text(
                cardBrand,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          Text(
            cardNum,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.2,
              fontFamily: 'monospace',
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("CARD HOLDER", style: TextStyle(color: Colors.white60, fontSize: 8.5, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    holder,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text("EXPIRES", style: TextStyle(color: Colors.white60, fontSize: 8.5, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    expiry,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── REALTIME GATEWAY EXECUTION MODAL ───
  Future<void> _initiateRealtimePayment(double totalAmount) async {
    if (_isProcessing) return;

    if (selectedPayment != "BusVerse Wallet") {
      if (accountController.text.trim().isEmpty && cardNumberController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please provide required payment details"), backgroundColor: Colors.redAccent),
        );
        return;
      }
    }
    if (emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your email for ticket delivery"), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _isProcessing = true);

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
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
                    decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 20),

                  if (_processingStep < 3)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: primaryBlue.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(color: primaryBlue, strokeWidth: 3),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Color(0xFFDCFCE7),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 42),
                    ),

                  const SizedBox(height: 16),

                  Text(
                    _processingStep < 3 ? "Processing Real-Time Payment" : "Payment & Booking Confirmed!",
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: darkText),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _processingStep < 3
                        ? "Please do not close the app while we communicate with $selectedPayment gateway"
                        : "Your seats are confirmed. Generating your digital boarding pass...",
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: subText),
                  ),

                  const SizedBox(height: 22),

                  _buildStepItem(0, "Connecting to $selectedPayment Gateway", _processingStep),
                  const SizedBox(height: 10),
                  _buildStepItem(1, "Authorizing PKR ${totalAmount.toStringAsFixed(0)} Transaction", _processingStep),
                  const SizedBox(height: 10),
                  _buildStepItem(2, "Reserving Seats with Supabase Cloud DB", _processingStep),
                  const SizedBox(height: 10),
                  _buildStepItem(3, "Issuing Digital E-Ticket & Boarding Pass", _processingStep),

                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );

    final String passengerName = widget.passengerData["name"] ?? "Passenger";
    final String passengerCnic = widget.passengerData["cnic"] ?? "";
    final String passengerPhone = widget.passengerData["phone"] ?? accountController.text.trim();
    final String email = emailController.text.trim().isNotEmpty
        ? emailController.text.trim()
        : (widget.passengerData["email"] ?? "");
    final String seatsStr = widget.selectedSeats.join(",");
    final int userId = (widget.passengerData["userId"] is int) ? widget.passengerData["userId"] : 0;
    final Map<int, String> genderMap = (widget.passengerData["genderMap"] is Map)
        ? Map<int, String>.from(widget.passengerData["genderMap"])
        : <int, String>{};
    final String primaryGender = widget.passengerData["gender"] ??
        (genderMap.isNotEmpty ? genderMap.values.first : "M");

    await Future.delayed(const Duration(milliseconds: 900));
    if (mounted) setState(() => _processingStep = 1);

    await Future.delayed(const Duration(milliseconds: 900));
    if (mounted) setState(() => _processingStep = 2);

    // 1. Insert Payment in Supabase
    try {
      await SupabaseService.instance.insertPayment(
        busId: widget.bus.id ?? 0,
        seats: seatsStr,
        amount: totalAmount,
        date: widget.date,
        passengerName: passengerName,
        passengerCnic: passengerCnic,
        passengerPhone: passengerPhone,
        paymentMethod: selectedPayment,
        accountNumber: accountController.text.trim().isNotEmpty
            ? accountController.text.trim()
            : (cardNumberController.text.isNotEmpty ? "CARD-****" : "WALLET"),
        email: email,
      );
    } catch (e) {
      print("Supabase payment exception: $e");
    }

    // 2. Reserve / Block Seats in Supabase Bookings Table
    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid ?? "guest_user";
      final Map<int, String> seatGenders = {};
      for (var s in widget.selectedSeats) {
        seatGenders[s] = genderMap[s] ?? primaryGender;
      }
      await SupabaseService.instance.createBooking(
        firebaseUid: currentUid,
        userEmail: email.isNotEmpty ? email : "guest@busverse.com",
        busId: widget.bus.id ?? 0,
        seatNumbers: widget.selectedSeats,
        seatGenders: seatGenders,
        bookingDate: widget.date,
      );
    } catch (e) {
      print("Supabase booking exception: $e");
    }

    // 3. Insert Payment in SQLite Payments Table
    try {
      await DBHelper.instance.insertPayment(
        busId: widget.bus.id ?? 0,
        seats: widget.selectedSeats,
        passengerName: passengerName,
        passengerEmail: email,
        paymentMethod: selectedPayment,
        accountNumber: accountController.text.trim().isNotEmpty
            ? accountController.text.trim()
            : "ONLINE",
        date: widget.date,
        amount: totalAmount,
        passengerCnic: passengerCnic,
        passengerPhone: passengerPhone,
      );
    } catch (e) {
      print("SQLite payment exception: $e");
    }

    // 4. Reserve / Block Seats in SQLite Bookings Table
    try {
      await DBHelper.instance.bookSeats(
        busId: widget.bus.id ?? 0,
        seats: widget.selectedSeats.map((s) => s.toString()).toList(),
        gender: primaryGender,
        date: widget.date,
        userId: userId,
      );
    } catch (e) {
      print("SQLite bookSeats exception: $e");
    }

    if (mounted) setState(() => _processingStep = 3);
    await Future.delayed(const Duration(milliseconds: 1000));

    if (!mounted) return;
    Navigator.pop(context); // Close bottom sheet

    final String travelDate = (widget.bus.date.isNotEmpty && widget.bus.date != "0000-00-00")
        ? widget.bus.date
        : widget.date;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ViewTicketScreen(
          ticketData: {
            "passenger": {
              "name": passengerName,
              "cnic": passengerCnic,
              "phone": passengerPhone,
              "email": email,
            },
            "passengerName": passengerName,
            "passengerCnic": passengerCnic,
            "passengerPhone": passengerPhone,
            "bus": widget.bus,
            "seats": widget.selectedSeats,
            "date": travelDate,
            "travelDate": travelDate,
            "paymentMethod": selectedPayment,
            "fromCity": widget.bus.fromCity,
            "toCity": widget.bus.toCity,
            "time": widget.bus.time,
            "totalFare": totalAmount,
          },
        ),
      ),
    );
  }

  Widget _buildStepItem(int stepIndex, String title, int currentStep) {
    bool isCompleted = currentStep > stepIndex;
    bool isCurrent = currentStep == stepIndex;

    return Row(
      children: [
        if (isCompleted)
          const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 18)
        else if (isCurrent)
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(color: primaryBlue, strokeWidth: 2),
          )
        else
          const Icon(Icons.radio_button_unchecked_rounded, color: Color(0xFFCBD5E1), size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isCurrent || isCompleted ? FontWeight.w700 : FontWeight.w500,
              color: isCompleted ? const Color(0xFF16A34A) : (isCurrent ? darkText : subText),
            ),
          ),
        ),
      ],
    );
  }

  Widget _paymentOptionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required String badgeText,
    required Color badgeColor,
    required Color color,
  }) {
    final bool isSelected = selectedPayment == title;

    return GestureDetector(
      onTap: () => setState(() => selectedPayment = title),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF0F7FF) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? primaryBlue : const Color(0xFFE2E8F0),
            width: isSelected ? 1.6 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected ? primaryBlue.withOpacity(0.1) : Colors.black.withOpacity(0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? primaryBlue : darkText,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: badgeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: subText),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: isSelected ? primaryBlue : const Color(0xFFCBD5E1),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({required String hint, required IconData icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
      prefixIcon: Icon(icon, size: 18, color: primaryBlue),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: primaryBlue, width: 1.5),
      ),
    );
  }

  Widget _summaryRow(String title, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 12, color: subText)),
        Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: darkText)),
      ],
    );
  }
}

// ─── CUSTOM INPUT FORMATTERS ───
class _CardNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text.replaceAll(' ', '');
    var buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      var nonZeroIndex = i + 1;
      if (nonZeroIndex % 4 == 0 && nonZeroIndex != text.length) {
        buffer.write(' ');
      }
    }
    var string = buffer.toString();
    return newValue.copyWith(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}

class _CardExpiryInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text.replaceAll('/', '');
    var buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      var nonZeroIndex = i + 1;
      if (nonZeroIndex % 2 == 0 && nonZeroIndex != text.length) {
        buffer.write('/');
      }
    }
    var string = buffer.toString();
    return newValue.copyWith(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:bus_ticket_system/admin/models/bus_model.dart';
import 'package:bus_ticket_system/database/db_helper.dart';
import 'package:bus_ticket_system/services/supabase_service.dart';
import 'package:intl/intl.dart';

class AddEditBusScreen extends StatefulWidget {
  final BusModel? bus;

  const AddEditBusScreen({super.key, this.bus});

  @override
  State<AddEditBusScreen> createState() => _AddEditBusScreenState();
}

class _AddEditBusScreenState extends State<AddEditBusScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController fromController;
  late final TextEditingController toController;
  late final TextEditingController viaController;
  late final TextEditingController dateController;
  late final TextEditingController timeController;
  late final TextEditingController fareController;
  late final TextEditingController discountController;
  late final TextEditingController discountLabelController;
  late final TextEditingController busNumberController;
  late final TextEditingController driverController;

  String busClass = "Executive";
  int totalSeats = 40;
  bool refreshment = false;
  bool isSaving = false;

  static const Color primaryBlue = Color(0xFF388AF6);
  static const Color darkNavy = Color(0xFF1E3C72);
  static const Color darkText = Color(0xFF1E293B);
  static const Color subText = Color(0xFF64748B);
  static const Color bgSurface = Color(0xFFF8FAFC);
  static const Color borderColor = Color(0xFFE2E8F0);

  final List<String> citySuggestions = [
    "Lahore",
    "Islamabad",
    "Rawalpindi",
    "Karachi",
    "Faisalabad",
    "Multan",
    "Peshawar",
    "Quetta",
    "Sialkot",
    "Gujranwala",
    "Bahawalpur",
    "Sargodha",
    "Hyderabad",
    "Abbottabad",
    "Sahiwal",
    "Rahim Yar Khan",
    "Sukkur",
    "Mardan",
    "Gujrat",
    "Murree",
  ];

  final List<Map<String, dynamic>> busClasses = const [
    {"name": "Executive", "icon": Icons.star_rounded, "color": Color(0xFF388AF6)},
    {"name": "Luxury", "icon": Icons.diamond_rounded, "color": Color(0xFF8B5CF6)},
    {"name": "Business", "icon": Icons.business_center_rounded, "color": Color(0xFF10B981)},
    {"name": "Gold", "icon": Icons.workspace_premium_rounded, "color": Color(0xFFF59E0B)},
    {"name": "Standard", "icon": Icons.directions_bus_rounded, "color": Color(0xFF64748B)},
  ];

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    fromController = TextEditingController();
    toController = TextEditingController();
    viaController = TextEditingController();
    dateController = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(now),
    );
    timeController = TextEditingController(
      text: DateFormat('hh:mm a').format(now),
    );
    fareController = TextEditingController();
    discountController = TextEditingController();
    discountLabelController = TextEditingController();
    busNumberController = TextEditingController();
    driverController = TextEditingController();

    if (widget.bus != null) {
      final b = widget.bus!;
      fromController.text = b.fromCity;
      toController.text = b.toCity;
      viaController.text = b.routeVia;
      dateController.text = b.date;
      timeController.text = b.time;
      busClass = b.busClass.isNotEmpty ? b.busClass : "Executive";
      totalSeats = b.seats > 0 ? b.seats : 40;
      fareController.text = b.fare > 0 ? b.fare.toStringAsFixed(0) : "";
      discountController.text = b.discount > 0 ? b.discount.toString() : "";
      discountLabelController.text = b.discountLabel;
      refreshment = b.refreshment;
      busNumberController.text = b.busNumber;
      driverController.text = b.driverName;
    }

    fromController.addListener(_onFieldChanged);
    toController.addListener(_onFieldChanged);
    fareController.addListener(_onFieldChanged);
    discountController.addListener(_onFieldChanged);
    discountLabelController.addListener(_onFieldChanged);
    dateController.addListener(_onFieldChanged);
    timeController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    fromController.dispose();
    toController.dispose();
    viaController.dispose();
    dateController.dispose();
    timeController.dispose();
    fareController.dispose();
    discountController.dispose();
    discountLabelController.dispose();
    busNumberController.dispose();
    driverController.dispose();
    super.dispose();
  }

  void _swapCities() {
    final temp = fromController.text;
    fromController.text = toController.text;
    toController.text = temp;
    setState(() {});
  }

  void _setDatePreset(int daysFromToday) {
    final target = DateTime.now().add(Duration(days: daysFromToday));
    dateController.text = DateFormat('yyyy-MM-dd').format(target);
    setState(() {});
  }

  Future<void> _pickDate() async {
    final initialDate = DateTime.tryParse(dateController.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: primaryBlue,
              onPrimary: Colors.white,
              onSurface: darkText,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      setState(() {});
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: primaryBlue,
              onPrimary: Colors.white,
              onSurface: darkText,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      timeController.text = picked.format(context);
      setState(() {});
    }
  }

  Future<void> _saveBus() async {
    if (!_formKey.currentState!.validate()) return;

    if (fromController.text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select Departure City")),
      );
      return;
    }

    if (toController.text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select Destination City")),
      );
      return;
    }

    setState(() => isSaving = true);

    final date = DateTime.tryParse(dateController.text) ?? DateTime.now();
    final dayName = DateFormat('EEEE').format(date);

    final double fare = double.tryParse(fareController.text.trim()) ?? 0.0;
    final int discount = int.tryParse(discountController.text.trim()) ?? 0;

    final bus = BusModel(
      id: widget.bus?.id,
      busName: "BusVerse",
      routeName: "${fromController.text.trim()} to ${toController.text.trim()}",
      fromCity: fromController.text.trim(),
      toCity: toController.text.trim(),
      routeVia: viaController.text.trim(),
      date: dateController.text.trim(),
      day: dayName,
      time: timeController.text.trim(),
      busClass: busClass,
      seats: totalSeats,
      fare: fare,
      originalFare: fare > 0 && discount > 0 ? fare + discount : fare,
      discount: discount,
      discountLabel: discountLabelController.text.trim(),
      refreshment: refreshment,
      busNumber: busNumberController.text.trim().isNotEmpty
          ? busNumberController.text.trim()
          : "BV-${(1000 + DateTime.now().millisecond % 9000)}",
      driverName: driverController.text.trim().isNotEmpty
          ? driverController.text.trim()
          : "Assigned Captain",
      createdAt: widget.bus?.createdAt ?? DateTime.now().toIso8601String(),
    );

    // 1. Save / Update to Supabase (Cloud)
    try {
      if (widget.bus == null) {
        final supabaseId = await SupabaseService.instance.insertBus(bus);
        if (supabaseId != null) {
          bus.id = supabaseId;
        }
      } else {
        await SupabaseService.instance.updateBus(bus);
      }
    } catch (e) {
      debugPrint("Supabase bus save exception: $e");
    }

    // 2. Save / Update to Local SQLite
    try {
      if (widget.bus == null) {
        await DBHelper.instance.insertBus(bus);
      } else {
        await DBHelper.instance.updateBus(bus.id!, bus);
      }
    } catch (e) {
      debugPrint("SQLite bus save exception: $e");
    }

    if (!mounted) return;
    setState(() => isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              widget.bus == null
                  ? "Bus registered successfully!"
                  : "Bus schedule updated!",
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.bus != null;

    return Scaffold(
      backgroundColor: bgSurface,
      appBar: AppBar(
        title: Text(
          isEdit ? "Edit Bus Schedule" : "Add New Bus Schedule",
          style: const TextStyle(
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
        actions: [
          if (!isEdit)
            TextButton(
              onPressed: () {
                fromController.clear();
                toController.clear();
                viaController.clear();
                fareController.clear();
                discountController.clear();
                discountLabelController.clear();
                busNumberController.clear();
                driverController.clear();
                setState(() {
                  busClass = "Executive";
                  refreshment = false;
                  totalSeats = 40;
                });
              },
              child: const Text(
                "Reset",
                style: TextStyle(
                  color: subText,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Live Passenger Preview Ticket Card
              _buildLivePreviewCard(),

              const SizedBox(height: 16),

              // SECTION 1: Route Selection
              _buildSectionCard(
                title: "Route & Journey",
                icon: Icons.alt_route_rounded,
                badgeText: "Step 1",
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Column(
                        children: [
                          _buildAutoCompleteCity(
                            controller: fromController,
                            label: "Origin / From City *",
                            hint: "Select origin (e.g. Lahore)",
                            icon: Icons.trip_origin_rounded,
                            iconColor: const Color(0xFF10B981),
                          ),
                          const SizedBox(height: 12),
                          _buildAutoCompleteCity(
                            controller: toController,
                            label: "Destination / To City *",
                            hint: "Select destination (e.g. Islamabad)",
                            icon: Icons.location_on_rounded,
                            iconColor: const Color(0xFFEF4444),
                          ),
                        ],
                      ),
                      PositionToCenterRightSwapButton(
                        onSwap: _swapCities,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildInputField(
                    controller: viaController,
                    label: "Via Highway / Route (Optional)",
                    hint: "e.g. Motorway M-2, GT Road Express",
                    icon: Icons.route_rounded,
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // SECTION 2: Date & Time Schedule
              _buildSectionCard(
                title: "Schedule & Timing",
                icon: Icons.calendar_month_rounded,
                badgeText: "Step 2",
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _pickDate,
                          borderRadius: BorderRadius.circular(10),
                          child: IgnorePointer(
                            child: _buildInputField(
                              controller: dateController,
                              label: "Departure Date",
                              hint: "YYYY-MM-DD",
                              icon: Icons.calendar_today_rounded,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: _pickTime,
                          borderRadius: BorderRadius.circular(10),
                          child: IgnorePointer(
                            child: _buildInputField(
                              controller: timeController,
                              label: "Departure Time",
                              hint: "hh:mm AM/PM",
                              icon: Icons.access_time_filled_rounded,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text(
                        "Quick Date:",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: subText,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildPresetChip("Today", 0),
                      const SizedBox(width: 6),
                      _buildPresetChip("Tomorrow", 1),
                      const SizedBox(width: 6),
                      _buildPresetChip("+2 Days", 2),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // SECTION 3: Bus Class & Capacity
              _buildSectionCard(
                title: "Bus Category & Seating",
                icon: Icons.airline_seat_recline_extra_rounded,
                badgeText: "Step 3",
                children: [
                  const Text(
                    "Select Bus Class",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: darkText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: busClasses.map((item) {
                      final name = item["name"] as String;
                      final icon = item["icon"] as IconData;
                      final color = item["color"] as Color;
                      final selected = busClass.toLowerCase() == name.toLowerCase();

                      return InkWell(
                        onTap: () => setState(() => busClass = name),
                        borderRadius: BorderRadius.circular(10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected ? primaryBlue : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selected ? primaryBlue : borderColor,
                              width: selected ? 1.5 : 1,
                            ),
                            boxShadow: selected
                                ? [
                                    BoxShadow(
                                      color: primaryBlue.withAlpha(60),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    )
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                icon,
                                size: 15,
                                color: selected ? Colors.white : color,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                name,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: selected ? Colors.white : darkText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Total Passenger Capacity",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: darkText,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "Standard seating layout for this bus",
                              style: TextStyle(fontSize: 11, color: subText),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: bgSurface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          children: [
                            _buildCapacityBtn(30),
                            const SizedBox(width: 4),
                            _buildCapacityBtn(40),
                            const SizedBox(width: 4),
                            _buildCapacityBtn(45),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // SECTION 4: Pricing & Discounts
              _buildSectionCard(
                title: "Fare & Promotional Offers",
                icon: Icons.payments_rounded,
                badgeText: "Step 4",
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildInputField(
                          controller: fareController,
                          label: "Ticket Fare (PKR) *",
                          hint: "e.g. 2500",
                          icon: Icons.currency_exchange_rounded,
                          keyboardType: TextInputType.number,
                          required: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildInputField(
                          controller: discountController,
                          label: "Discount (PKR, Opt)",
                          hint: "e.g. 300",
                          icon: Icons.local_offer_rounded,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildInputField(
                    controller: discountLabelController,
                    label: "Discount Promo Label (Optional)",
                    hint: "e.g. Early Bird 15% OFF, Weekend Promo",
                    icon: Icons.stars_rounded,
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // SECTION 5: Bus & Driver Details
              _buildSectionCard(
                title: "Vehicle & Staff Information",
                icon: Icons.directions_bus_filled_rounded,
                badgeText: "Step 5",
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildInputField(
                          controller: busNumberController,
                          label: "Bus Reg. Number (Opt)",
                          hint: "e.g. LE-1234 / BV-901",
                          icon: Icons.pin_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildInputField(
                          controller: driverController,
                          label: "Driver / Captain Name",
                          hint: "e.g. Muhammad Aslam",
                          icon: Icons.person_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: bgSurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: refreshment
                                ? primaryBlue.withAlpha(30)
                                : Colors.grey.withAlpha(25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.fastfood_rounded,
                            size: 18,
                            color: refreshment ? primaryBlue : subText,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Refreshment Included",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: darkText,
                                ),
                              ),
                              Text(
                                refreshment
                                    ? "Complimentary snacks & water provided"
                                    : "No refreshments included on this route",
                                style: const TextStyle(fontSize: 11, color: subText),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: refreshment,
                          activeThumbColor: primaryBlue,
                          onChanged: (v) => setState(() => refreshment = v),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 22),

              // SAVE BUTTON
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: isSaving ? null : _saveBus,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: primaryBlue.withAlpha(150),
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isEdit ? Icons.save_rounded : Icons.add_circle_rounded,
                              size: 19,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isEdit ? "Update Bus Schedule" : "Register Bus Schedule",
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPresetChip(String label, int days) {
    final targetStr = DateFormat('yyyy-MM-dd').format(
      DateTime.now().add(Duration(days: days)),
    );
    final isSelected = dateController.text == targetStr;

    return InkWell(
      onTap: () => _setDatePreset(days),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? primaryBlue.withAlpha(30) : bgSurface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? primaryBlue : borderColor,
            width: isSelected ? 1 : 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: isSelected ? primaryBlue : subText,
          ),
        ),
      ),
    );
  }

  Widget _buildCapacityBtn(int seats) {
    final isSelected = totalSeats == seats;
    return InkWell(
      onTap: () => setState(() => totalSeats = seats),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? primaryBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          "$seats Seats",
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : darkText,
          ),
        ),
      ),
    );
  }

  /// Live Ticket Preview Card
  Widget _buildLivePreviewCard() {
    final from = fromController.text.trim().isNotEmpty ? fromController.text.trim() : "From City";
    final to = toController.text.trim().isNotEmpty ? toController.text.trim() : "To City";
    final time = timeController.text.trim().isNotEmpty ? timeController.text.trim() : "Departure Time";
    final date = dateController.text.trim().isNotEmpty ? dateController.text.trim() : "Date";
    final fare = fareController.text.trim().isNotEmpty ? "Rs. ${fareController.text.trim()}" : "Rs. 0";
    final discount = discountController.text.trim().isNotEmpty ? int.tryParse(discountController.text.trim()) ?? 0 : 0;
    final discountLabel = discountLabelController.text.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: darkNavy.withAlpha(60),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(40),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.directions_bus_rounded, color: Colors.white, size: 14),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "BusVerse Fleet",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(50),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  busClass.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Route row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      from,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      time,
                      style: TextStyle(
                        color: Colors.white.withAlpha(200),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 1.5,
                      color: Colors.white.withAlpha(120),
                    ),
                    const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                    Container(
                      width: 20,
                      height: 1.5,
                      color: Colors.white.withAlpha(120),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      to,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      date,
                      style: TextStyle(
                        color: Colors.white.withAlpha(200),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          Divider(color: Colors.white.withAlpha(40), height: 1),
          const SizedBox(height: 10),

          // Footer info row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (discount > 0)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        discountLabel.isNotEmpty ? discountLabel : "-Rs. $discount",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 9.5,
                        ),
                      ),
                    ),
                  if (refreshment)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.fastfood_rounded, size: 10, color: Colors.white),
                          SizedBox(width: 3),
                          Text(
                            "Snacks",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 9.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              Text(
                fare,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required String badgeText,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 6,
            offset: const Offset(0, 2),
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
                      color: primaryBlue.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 16, color: primaryBlue),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: darkText,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: bgSurface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: borderColor),
                ),
                child: Text(
                  badgeText,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: subText,
                  ),
                ),
              ),
            ],
          ),
          const Divider(color: Color(0xFFF1F5F9), height: 18, thickness: 1),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: darkText,
          ),
        ),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: darkText,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              fontSize: 12,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Icon(icon, size: 17, color: primaryBlue),
            filled: true,
            fillColor: bgSurface,
            isDense: true,
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
          validator: required
              ? (val) => val == null || val.trim().isEmpty ? "Required" : null
              : null,
        ),
      ],
    );
  }

  Widget _buildAutoCompleteCity({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required Color iconColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: darkText,
          ),
        ),
        const SizedBox(height: 5),
        Autocomplete<String>(
          initialValue: TextEditingValue(text: controller.text),
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              return citySuggestions;
            }
            return citySuggestions.where((String city) {
              return city.toLowerCase().contains(textEditingValue.text.toLowerCase());
            });
          },
          onSelected: (String selection) {
            controller.text = selection;
            setState(() {});
          },
          fieldViewBuilder: (
            BuildContext context,
            TextEditingController fieldTextEditingController,
            FocusNode fieldFocusNode,
            VoidCallback onFieldSubmitted,
          ) {
            if (fieldTextEditingController.text != controller.text && controller.text.isNotEmpty) {
              fieldTextEditingController.text = controller.text;
            }
            fieldTextEditingController.addListener(() {
              if (controller.text != fieldTextEditingController.text) {
                controller.text = fieldTextEditingController.text;
              }
            });

            return TextFormField(
              controller: fieldTextEditingController,
              focusNode: fieldFocusNode,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: darkText,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w400,
                ),
                prefixIcon: Icon(icon, size: 17, color: iconColor),
                filled: true,
                fillColor: bgSurface,
                isDense: true,
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
              validator: (val) => val == null || val.trim().isEmpty ? "Required" : null,
            );
          },
        ),
      ],
    );
  }
}

/// Floating swap button positioned between origin and destination inputs
class PositionToCenterRightSwapButton extends StatelessWidget {
  final VoidCallback onSwap;

  const PositionToCenterRightSwapButton({super.key, required this.onSwap});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 12,
      child: Material(
        color: Colors.white,
        elevation: 2,
        shape: const CircleBorder(
          side: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onSwap,
          child: const Padding(
            padding: EdgeInsets.all(7),
            child: Icon(
              Icons.swap_vert_rounded,
              size: 18,
              color: Color(0xFF388AF6),
            ),
          ),
        ),
      ),
    );
  }
}
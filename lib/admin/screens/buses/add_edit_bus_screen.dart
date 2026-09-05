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

  String busClass = "Gold";
  bool refreshment = false;

  static const Color primaryBlue = Color(0xFF388AF6);
  static const Color darkText = Color(0xFF1E293B);
  static const Color subText = Color(0xFF64748B);

  List<String> citySuggestions = [
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

  @override
  void initState() {
    super.initState();

    fromController = TextEditingController();
    toController = TextEditingController();
    viaController = TextEditingController();
    dateController = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );
    timeController = TextEditingController(
      text: DateFormat('hh:mm a').format(DateTime.now()),
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
      busClass = b.busClass;
      fareController.text = b.fare > 0 ? b.fare.toStringAsFixed(0) : "";
      discountController.text = b.discount > 0 ? b.discount.toString() : "";
      discountLabelController.text = b.discountLabel;
      refreshment = b.refreshment;
      busNumberController.text = b.busNumber;
      driverController.text = b.driverName;
    }
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
    if (picked != null) {
      timeController.text = picked.format(context);
    }
  }

  Future<void> _saveBus() async {
    if (!_formKey.currentState!.validate()) return;

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
      seats: 40,
      fare: fare,
      originalFare: fare > 0 && discount > 0 ? fare + discount : fare,
      discount: discount,
      discountLabel: discountLabelController.text.trim(),
      refreshment: refreshment,
      busNumber: busNumberController.text.trim(),
      driverName: driverController.text.trim(),
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
      print("Supabase bus save exception: $e");
    }

    // 2. Save / Update to Local SQLite
    try {
      if (widget.bus == null) {
        await DBHelper.instance.insertBus(bus);
      } else {
        await DBHelper.instance.updateBus(bus.id!, bus);
      }
    } catch (e) {
      print("SQLite bus save exception: $e");
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.bus == null
              ? "Bus registered successfully!"
              : "Bus schedule updated!"),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.bus != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          isEdit ? "Edit Bus Schedule" : "Register New Bus",
          style: const TextStyle(
            color: darkText,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: darkText, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section 1: Route details
              _buildSectionCard(
                title: "Route Details",
                icon: Icons.route_rounded,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildAutoCompleteCity(
                          controller: fromController,
                          label: "From City",
                          hint: "e.g. Lahore",
                          icon: Icons.trip_origin_rounded,
                          iconColor: primaryBlue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildAutoCompleteCity(
                          controller: toController,
                          label: "To City",
                          hint: "e.g. Islamabad",
                          icon: Icons.location_on_rounded,
                          iconColor: Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildInputField(
                    controller: viaController,
                    label: "Via Route (Optional)",
                    hint: "e.g. Motorway M-2 / GT Road",
                    icon: Icons.alt_route_rounded,
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Section 2: Schedule & Bus Class
              _buildSectionCard(
                title: "Schedule & Type",
                icon: Icons.schedule_rounded,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _pickDate,
                          child: AbsorbPointer(
                            child: _buildInputField(
                              controller: dateController,
                              label: "Date",
                              hint: "YYYY-MM-DD",
                              icon: Icons.calendar_month_rounded,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: _pickTime,
                          child: AbsorbPointer(
                            child: _buildInputField(
                              controller: timeController,
                              label: "Time",
                              hint: "hh:mm AM/PM",
                              icon: Icons.access_time_rounded,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Bus Class",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: darkText),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: ["Gold", "Business", "Executive"].map((c) {
                      final selected = busClass == c;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(c),
                          selected: selected,
                          selectedColor: primaryBlue,
                          backgroundColor: const Color(0xFFF8FAFC),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: selected ? Colors.white : subText,
                          ),
                          onSelected: (val) {
                            if (val) setState(() => busClass = c);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Section 3: Pricing & Offers
              _buildSectionCard(
                title: "Pricing & Discounts",
                icon: Icons.payments_rounded,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildInputField(
                          controller: fareController,
                          label: "Fare (PKR) *",
                          hint: "e.g. 2500",
                          icon: Icons.attach_money_rounded,
                          keyboardType: TextInputType.number,
                          required: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildInputField(
                          controller: discountController,
                          label: "Discount PKR (Opt)",
                          hint: "e.g. 300",
                          icon: Icons.discount_rounded,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildInputField(
                    controller: discountLabelController,
                    label: "Discount Tag (Optional)",
                    hint: "e.g. Promo 15% OFF",
                    icon: Icons.local_offer_rounded,
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Section 4: Additional details
              _buildSectionCard(
                title: "Bus & Driver Info",
                icon: Icons.directions_bus_rounded,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildInputField(
                          controller: busNumberController,
                          label: "Bus Number (Opt)",
                          hint: "e.g. LE-1234",
                          icon: Icons.confirmation_number_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildInputField(
                          controller: driverController,
                          label: "Driver Name (Opt)",
                          hint: "e.g. Muhammad Ali",
                          icon: Icons.person_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      "Refreshment Included",
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: darkText),
                    ),
                    subtitle: const Text(
                      "Snacks & drinks provided onboard",
                      style: TextStyle(fontSize: 11, color: subText),
                    ),
                    value: refreshment,
                    activeColor: primaryBlue,
                    onChanged: (v) => setState(() => refreshment = v),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _saveBus,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(isEdit ? Icons.check_circle_rounded : Icons.add_circle_rounded, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        isEdit ? "Update Bus Schedule" : "Register Bus Schedule",
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
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
            children: [
              Icon(icon, size: 18, color: primaryBlue),
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
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: darkText),
        ),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: darkText),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w400),
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
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: darkText),
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
              controller.text = fieldTextEditingController.text;
            });

            return TextFormField(
              controller: fieldTextEditingController,
              focusNode: fieldFocusNode,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: darkText),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w400),
                prefixIcon: Icon(icon, size: 18, color: iconColor),
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
              ),
              validator: (val) => val == null || val.trim().isEmpty ? "Required" : null,
            );
          },
        ),
      ],
    );
  }
}
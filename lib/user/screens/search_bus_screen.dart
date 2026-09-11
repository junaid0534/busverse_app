import 'package:flutter/material.dart';
import 'package:bus_ticket_system/database/db_helper.dart';
import 'package:bus_ticket_system/admin/models/bus_model.dart';
import 'package:bus_ticket_system/services/supabase_service.dart';
import 'package:bus_ticket_system/user/screens/available_buses_screen.dart';
import 'package:bus_ticket_system/user/screens/no_bus_found_screen.dart';

class SearchBusScreen extends StatefulWidget {
  const SearchBusScreen({super.key});

  @override
  State<SearchBusScreen> createState() => _SearchBusScreenState();
}

class _SearchBusScreenState extends State<SearchBusScreen> {
  final TextEditingController fromController = TextEditingController();
  final TextEditingController toController = TextEditingController();
  final TextEditingController dateController = TextEditingController();

  DateTime? selectedDate;
  String selectedBusType = "All Types";

  // Predefined & DB loaded cities list for auto-complete suggestions
  List<String> allCities = [
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

  final List<String> busTypes = ["All Types", "Gold", "Business", "Executive"];

  static const Color primaryBlue = Color(0xFF388AF6);
  static const Color darkText = Color(0xFF1E293B);
  static const Color subText = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    selectedDate = DateTime.now();
    _formatAndSetDate(selectedDate!);
    _loadDbCities();
  }

  @override
  void dispose() {
    fromController.dispose();
    toController.dispose();
    dateController.dispose();
    super.dispose();
  }

  void _formatAndSetDate(DateTime d) {
    dateController.text =
        "${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}";
  }

  Future<void> _loadDbCities() async {
    final db = DBHelper.instance;
    final fromList = await db.getAllFromCities();
    final toList = await db.getAllToCities();

    final Set<String> citySet = Set.from(allCities);
    citySet.addAll(fromList);
    citySet.addAll(toList);

    if (!mounted) return;
    setState(() {
      allCities = citySet.toList()..sort();
      if (fromController.text.isEmpty && fromList.isNotEmpty) {
        fromController.text = fromList.first;
      }
      if (toController.text.isEmpty && toList.isNotEmpty) {
        toController.text = toList.length > 1 ? toList[1] : toList.first;
      }
    });
  }

  void _swapCities() {
    setState(() {
      final temp = fromController.text;
      fromController.text = toController.text;
      toController.text = temp;
    });
  }

  Future<void> pickDate() async {
    DateTime today = DateTime.now();
    DateTime lastAllowed = today.add(const Duration(days: 9));

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? today,
      firstDate: today,
      lastDate: lastAllowed,
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
      setState(() {
        selectedDate = picked;
        _formatAndSetDate(picked);
      });
    }
  }

  Future<void> searchBus(int userId) async {
    final String fromCity = fromController.text.trim();
    final String toCity = toController.text.trim();

    if (fromCity.isEmpty || toCity.isEmpty || selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter Departure, Destination and Date"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (fromCity.toLowerCase() == toCity.toLowerCase()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Departure and Destination cannot be the same city"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final String formattedDate =
        "${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}";

    List<BusModel> filteredBuses = [];

    // 1. Try Supabase Live Cloud Search
    try {
      filteredBuses = await SupabaseService.instance.searchBuses(
        fromCity: fromCity,
        toCity: toCity,
        date: formattedDate,
        busClass: selectedBusType == "All Types" ? null : selectedBusType,
      );
    } catch (e) {
      print("Supabase search exception: $e");
    }

    // 2. Fallback to SQLite (Local DB) if Supabase returns empty or offline
    if (filteredBuses.isEmpty) {
      final db = DBHelper.instance;
      final rawBuses = await db.getBusesByRouteAndType(
        fromCity,
        toCity,
        selectedBusType == "All Types" ? null : selectedBusType,
      );
      final List<BusModel> localBuses =
          rawBuses.map((e) => BusModel.fromMap(e)).toList();
      filteredBuses =
          localBuses.where((bus) => bus.date == formattedDate && !bus.isExpired).toList();
    }

    // Final safety check: remove any expired buses
    filteredBuses = filteredBuses.where((bus) => !bus.isExpired).toList();

    if (!mounted) return;

    if (filteredBuses.isEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NoBusFoundScreen(
            fromCity: fromCity,
            toCity: toCity,
            selectedDate: selectedDate!,
            busClass: selectedBusType,
            userId: userId,
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AvailableBusesUserScreen(
          buses: filteredBuses,
          selectedDate: selectedDate!,
          userId: userId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final int currentUserId = args?['userId'] ?? 1;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: darkText, size: 19),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Search Bus",
          style: TextStyle(
            color: darkText,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── ROUTE SELECTION (INPUT WITH AUTOCOMPLETE) ───
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Column(
                    children: [
                      // From City Autocomplete Input
                      _buildCityInputField(
                        label: "From",
                        hint: "Enter or select Departure City",
                        controller: fromController,
                        icon: Icons.trip_origin_rounded,
                        iconColor: primaryBlue,
                      ),

                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 36),
                        child: Divider(color: Color(0xFFF1F5F9), height: 20, thickness: 1),
                      ),

                      // To City Autocomplete Input
                      _buildCityInputField(
                        label: "To",
                        hint: "Enter or select Destination City",
                        controller: toController,
                        icon: Icons.location_on_rounded,
                        iconColor: Colors.redAccent,
                      ),
                    ],
                  ),

                  // Swap Button
                  Positioned(
                    right: 8,
                    top: 36,
                    child: GestureDetector(
                      onTap: _swapCities,
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F7FF),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFD0E3FF), width: 1),
                        ),
                        child: const Icon(
                          Icons.swap_vert_rounded,
                          color: primaryBlue,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ─── DATE SELECTION CARD ───
            GestureDetector(
              onTap: pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F7FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.calendar_month_rounded, color: primaryBlue, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Travel Date",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: subText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dateController.text.isEmpty ? "Select Date" : dateController.text,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: darkText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down_rounded, color: subText, size: 20),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ─── BUS TYPE FILTER ───
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
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
                  const Text(
                    "Bus Type",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: subText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: busTypes.map((type) {
                      final isSelected = selectedBusType == type;
                      return GestureDetector(
                        onTap: () => setState(() => selectedBusType = type),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? primaryBlue : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isSelected ? primaryBlue : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Text(
                            type,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              color: isSelected ? Colors.white : subText,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ─── SEARCH BUTTON ───
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () => searchBus(currentUserId),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_rounded, size: 18),
                    SizedBox(width: 8),
                    Text(
                      "Search Buses",
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // City Input with Live Autocomplete Suggestions
  Widget _buildCityInputField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    required Color iconColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: subText,
                ),
              ),
              Autocomplete<String>(
                initialValue: TextEditingValue(text: controller.text),
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return allCities;
                  }
                  return allCities.where((String city) {
                    return city
                        .toLowerCase()
                        .contains(textEditingValue.text.toLowerCase());
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
                  // Sync controllers
                  if (fieldTextEditingController.text != controller.text && controller.text.isNotEmpty) {
                    fieldTextEditingController.text = controller.text;
                  }
                  fieldTextEditingController.addListener(() {
                    controller.text = fieldTextEditingController.text;
                  });

                  return TextField(
                    controller: fieldTextEditingController,
                    focusNode: fieldFocusNode,
                    style: const TextStyle(
                      color: darkText,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      border: InputBorder.none,
                    ),
                  );
                },
                optionsViewBuilder: (
                  BuildContext context,
                  AutocompleteOnSelected<String> onSelected,
                  Iterable<String> options,
                ) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4.0,
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white,
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.75,
                        constraints: const BoxConstraints(maxHeight: 180),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          shrinkWrap: true,
                          itemCount: options.length,
                          separatorBuilder: (context, index) => const Divider(
                            height: 1,
                            color: Color(0xFFF1F5F9),
                          ),
                          itemBuilder: (BuildContext context, int index) {
                            final String option = options.elementAt(index);
                            return InkWell(
                              onTap: () => onSelected(option),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.location_city_rounded,
                                      size: 16,
                                      color: primaryBlue,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      option,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: darkText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
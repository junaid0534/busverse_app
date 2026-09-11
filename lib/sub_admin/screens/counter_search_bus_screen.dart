import 'package:flutter/material.dart';
import 'package:bus_ticket_system/admin/models/bus_model.dart';
import 'package:bus_ticket_system/database/db_helper.dart';
import 'package:bus_ticket_system/services/supabase_service.dart';
import 'package:bus_ticket_system/sub_admin/screens/counter_available_buses_screen.dart';

class CounterSearchBusScreen extends StatefulWidget {
  final Map<String, dynamic>? userProfile;

  const CounterSearchBusScreen({super.key, this.userProfile});

  @override
  State<CounterSearchBusScreen> createState() => _CounterSearchBusScreenState();
}

class _CounterSearchBusScreenState extends State<CounterSearchBusScreen> {
  final TextEditingController _toCityCtrl = TextEditingController();
  final TextEditingController _dateCtrl = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String _selectedBusType = "All Types";
  bool _isSearching = false;
  late List<DateTime> next7Days;

  static const Color primaryBlue = Color(0xFF388AF6);
  static const Color darkText = Color(0xFF1E293B);
  static const Color subText = Color(0xFF64748B);

  // Predefined & DB loaded cities list
  List<String> allCities = [
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
    "Lahore",
  ];

  final List<String> busTypes = ["All Types", "Gold", "Business", "Executive"];

  String get terminalCity => widget.userProfile?['terminalCity'] ?? 'Lahore';
  String get terminalName => widget.userProfile?['terminalName'] ?? 'Main Terminal Counter';
  String get agentName {
    final fn = widget.userProfile?['firstName'] ?? 'Terminal';
    final ln = widget.userProfile?['lastName'] ?? 'Agent';
    return "$fn $ln".trim();
  }

  @override
  void initState() {
    super.initState();
    next7Days = List.generate(7, (i) => DateTime.now().add(Duration(days: i)));
    _formatAndSetDate(_selectedDate);
    _loadDbCities();
  }

  @override
  void dispose() {
    _toCityCtrl.dispose();
    _dateCtrl.dispose();
    super.dispose();
  }

  void _formatAndSetDate(DateTime d) {
    _dateCtrl.text =
        "${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}";
  }

  String _formatDateKey(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}-'
        '${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')}';
  }

  String _dayName(DateTime dt) {
    const names = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return names[dt.weekday % 7];
  }

  String _monthShort(DateTime d) {
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return m[d.month - 1];
  }

  Future<void> _loadDbCities() async {
    final db = DBHelper.instance;
    final toList = await db.getAllToCities();

    final Set<String> citySet = Set.from(allCities);
    citySet.addAll(toList);
    // Remove terminal origin from destination options
    citySet.removeWhere((c) => c.toLowerCase() == terminalCity.toLowerCase());

    if (!mounted) return;
    setState(() {
      allCities = citySet.toList()..sort();
      if (_toCityCtrl.text.isEmpty && allCities.isNotEmpty) {
        _toCityCtrl.text = allCities.first;
      }
    });
  }

  Future<void> _pickDate() async {
    DateTime today = DateTime.now();
    DateTime lastAllowed = today.add(const Duration(days: 6));

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isAfter(lastAllowed) ? today : _selectedDate,
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
        _selectedDate = picked;
        _formatAndSetDate(picked);
      });
    }
  }

  Future<void> _searchBuses() async {
    final String toCity = _toCityCtrl.text.trim();

    if (toCity.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select or enter a Destination City"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (terminalCity.toLowerCase() == toCity.toLowerCase()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Departure and Destination cannot be the same city"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSearching = true);

    final String formattedDate = _formatDateKey(_selectedDate);

    List<BusModel> resultBuses = [];

    // 1. Live Supabase Search
    try {
      resultBuses = await SupabaseService.instance.searchBuses(
        fromCity: terminalCity,
        toCity: toCity,
        date: formattedDate,
        busClass: _selectedBusType == "All Types" ? null : _selectedBusType,
      );
    } catch (e) {
      debugPrint("Supabase search exception: $e");
    }

    // 2. Fallback to Local SQLite DB
    if (resultBuses.isEmpty) {
      final db = DBHelper.instance;
      final rawBuses = await db.getBusesByRouteAndType(
        terminalCity,
        toCity,
        _selectedBusType == "All Types" ? null : _selectedBusType,
      );
      final List<BusModel> localBuses =
          rawBuses.map((e) => BusModel.fromMap(e)).toList();
      resultBuses =
          localBuses.where((bus) => bus.date == formattedDate && !bus.isExpired).toList();
    }

    // Filter out expired
    resultBuses = resultBuses.where((b) => !b.isExpired).toList();

    if (!mounted) return;
    setState(() => _isSearching = false);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CounterAvailableBusesScreen(
          buses: resultBuses,
          fromCity: terminalCity,
          toCity: toCity,
          selectedDate: _selectedDate,
          userProfile: widget.userProfile,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            // ─── 1. ROUTE SELECTION CARD (FROM FIXED + TO AUTOCOMPLETE) ───
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(5),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // FROM: Fixed Terminal City & Counter
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Icon(Icons.trip_origin_rounded, color: primaryBlue, size: 18),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "From (Terminal Origin)",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: subText,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFFBFDBFE)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.lock_rounded, size: 10, color: primaryBlue),
                                      SizedBox(width: 3),
                                      Text(
                                        "FIXED",
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600,
                                          color: primaryBlue,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "$terminalCity - $terminalName",
                              style: const TextStyle(
                                color: darkText,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 36),
                    child: Divider(color: Color(0xFFF1F5F9), height: 20, thickness: 1),
                  ),

                  // TO: Autocomplete / Selectable Destination City
                  _buildDestinationInputField(
                    label: "To",
                    hint: "Enter or select Destination City",
                    controller: _toCityCtrl,
                    icon: Icons.location_on_rounded,
                    iconColor: Colors.redAccent,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ─── 2. HORIZONTAL DATE PICKER (ROW OF 7 DAYS CARDS) ───
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(5),
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
                      const Row(
                        children: [
                          Icon(Icons.calendar_month_rounded, color: primaryBlue, size: 16),
                          SizedBox(width: 6),
                          Text(
                            "Select Travel Date",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: subText,
                            ),
                          ),
                        ],
                      ),
                      InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "${_dayName(_selectedDate)}, ${_selectedDate.day} ${_monthShort(_selectedDate)}",
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: primaryBlue,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.edit_calendar_rounded, size: 13, color: primaryBlue),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 60,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: next7Days.length,
                      itemBuilder: (context, i) {
                        final d = next7Days[i];
                        final bool active = _formatDateKey(d) == _formatDateKey(_selectedDate);
                        final bool isToday = _formatDateKey(d) == _formatDateKey(DateTime.now());

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedDate = d;
                              _formatAndSetDate(d);
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 50,
                            margin: EdgeInsets.only(right: i == next7Days.length - 1 ? 0 : 8),
                            decoration: BoxDecoration(
                              color: active
                                  ? primaryBlue
                                  : (isToday ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC)),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: active
                                    ? primaryBlue
                                    : (isToday ? primaryBlue.withAlpha(80) : const Color(0xFFE2E8F0)),
                                width: active ? 1.5 : 1,
                              ),
                              boxShadow: active
                                  ? [
                                      BoxShadow(
                                        color: primaryBlue.withAlpha(70),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  isToday ? "Today" : _dayName(d),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                                    color: active ? Colors.white70 : (isToday ? primaryBlue : subText),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "${d.day}",
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: active ? Colors.white : darkText,
                                  ),
                                ),
                                Text(
                                  _monthShort(d),
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w400,
                                    color: active ? Colors.white70 : subText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ─── 3. BUS TYPE FILTER (1 ROW, 4 CARDS) ───
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(5),
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
                  Row(
                    children: busTypes.map((type) {
                      final isSelected = _selectedBusType == type;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedBusType = type),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2.5),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? primaryBlue : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected ? primaryBlue : const Color(0xFFE2E8F0),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              type,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                color: isSelected ? Colors.white : darkText,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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

            // ─── 4. SEARCH BUTTON ───
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: _isSearching ? null : _searchBuses,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isSearching
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Row(
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

  // Autocomplete Destination Input matching user app style
  Widget _buildDestinationInputField({
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
                  FocusScope.of(context).unfocus();
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
                              onTap: () {
                                onSelected(option);
                                FocusScope.of(context).unfocus();
                              },
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

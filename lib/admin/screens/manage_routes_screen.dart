// lib/admin/screens/manage_routes_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:bus_ticket_system/database/db_helper.dart';

/// ---------------------------
/// RouteModel (Option C)
/// ---------------------------
class RouteModel {
  int? id;
  String busNo;
  String fromCity;
  String toCity;
  String via;
  String date; // yyyy-MM-dd
  String time; // hh:mm a
  String busType;
  bool refreshment;
  String routeName;
  int seats;
  double fare;
  double originalFare;
  double discount;
  int distanceKm;
  String estimatedTime;
  int busesAssigned; // optional, default 0

  RouteModel({
    this.id,
    required this.busNo,
    required this.fromCity,
    required this.toCity,
    this.via = '',
    required this.date,
    required this.time,
    this.busType = 'Gold',
    this.refreshment = false,
    required this.routeName,
    required this.seats,
    required this.fare,
    this.originalFare = 0.0,
    this.discount = 0.0,
    this.distanceKm = 0,
    this.estimatedTime = '',
    this.busesAssigned = 0,
  });

  factory RouteModel.fromMap(Map<String, dynamic> m) {
    return RouteModel(
      id: m['id'] as int?,
      busNo: (m['busNo'] ?? '').toString(),
      fromCity: (m['fromCity'] ?? '').toString(),
      toCity: (m['toCity'] ?? '').toString(),
      via: (m['via'] ?? '').toString(),
      date: (m['date'] ?? '').toString(),
      time: (m['time'] ?? '').toString(),
      busType: (m['busType'] ?? '').toString(),
      refreshment: (m['refreshment'] == 1 || m['refreshment'] == true),
      routeName: (m['routeName'] ?? '').toString(),
      seats: (m['seats'] is int) ? m['seats'] : int.tryParse('${m['seats']}') ?? 0,
      fare: (m['fare'] is num) ? (m['fare'] as num).toDouble() : double.tryParse('${m['fare']}') ?? 0.0,
      originalFare: (m['originalFare'] is num) ? (m['originalFare'] as num).toDouble() : double.tryParse('${m['originalFare']}') ?? 0.0,
      discount: (m['discount'] is num) ? (m['discount'] as num).toDouble() : double.tryParse('${m['discount']}') ?? 0.0,
      distanceKm: (m['distanceKm'] is int) ? m['distanceKm'] : int.tryParse('${m['distanceKm']}') ?? 0,
      estimatedTime: (m['estimatedTime'] ?? '').toString(),
      busesAssigned: (m['busesAssigned'] is int) ? m['busesAssigned'] : int.tryParse('${m['busesAssigned']}') ?? 0,
    );
  }

  Map<String, dynamic> toMapForDb() {
    // This map matches the keys expected by your DBHelper.addRoute/updateRoute
    return {
      if (id != null) 'id': id,
      'busNo': busNo,
      'fromCity': fromCity,
      'toCity': toCity,
      'via': via,
      'date': date,
      'time': time,
      'busType': busType,
      'refreshment': refreshment ? 1 : 0,
      'routeName': routeName,
      'seats': seats,
      'fare': fare,
      'originalFare': originalFare,
      'discount': discount,
      // Extra fields (if you later add in DB) — harmless for now
      'distanceKm': distanceKm,
      'estimatedTime': estimatedTime,
      'busesAssigned': busesAssigned,
    };
  }
}

/// ---------------------------
/// ManageRoutesScreen
/// ---------------------------
class ManageRoutesScreen extends StatefulWidget {
  const ManageRoutesScreen({super.key});

  @override
  State<ManageRoutesScreen> createState() => _ManageRoutesScreenState();
}

class _ManageRoutesScreenState extends State<ManageRoutesScreen> {
  List<RouteModel> _routes = [];
  List<RouteModel> _filtered = [];
  bool _loading = false;
  String _search = '';
  String _sortBy = 'date'; // or 'fare'
  // ignore: unused_field
  final _dateFormat = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    setState(() => _loading = true);
    try {
      final list = await DBHelper.instance.getRoutes();
      final models = list.map((m) => RouteModel.fromMap(m)).toList();
      _routes = models;
      _applyFilters();
    } catch (e) {
      // show snackbar but do not crash
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load routes: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilters() {
    _filtered = _routes.where((r) {
      final q = _search.toLowerCase().trim();
      if (q.isEmpty) return true;
      return r.routeName.toLowerCase().contains(q) ||
          r.fromCity.toLowerCase().contains(q) ||
          r.toCity.toLowerCase().contains(q) ||
          r.busNo.toLowerCase().contains(q);
    }).toList();

    if (_sortBy == 'date') {
      _filtered.sort((a, b) {
        try {
          final da = DateTime.tryParse(a.date) ?? DateTime(2100);
          final db = DateTime.tryParse(b.date) ?? DateTime(2100);
          if (da != db) return da.compareTo(db);
          return a.time.compareTo(b.time);
        } catch (_) {
          return 0;
        }
      });
    } else if (_sortBy == 'fare') {
      _filtered.sort((a, b) => a.fare.compareTo(b.fare));
    }

    setState(() {});
  }

  Future<void> _showAddEdit([RouteModel? route]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AddEditRouteScreen(route: route)),
    );
    if (changed == true) await _loadRoutes();
  }

  Future<void> _deleteRoute(RouteModel r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Route'),
        content: Text('Delete route "${r.routeName}" from ${r.fromCity} → ${r.toCity}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      try {
        await DBHelper.instance.deleteRoute(r.id!);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Route deleted')));
        await _loadRoutes();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search by route, from, to or bus no',
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              onChanged: (v) {
                _search = v;
                _applyFilters();
              },
            ),
          ),
          const SizedBox(width: 10),
          DropdownButton<String>(
            value: _sortBy,
            items: const [
              DropdownMenuItem(value: 'date', child: Text('Sort: Date')),
              DropdownMenuItem(value: 'fare', child: Text('Sort: Fare')),
            ],
            onChanged: (v) {
              if (v == null) return;
              _sortBy = v;
              _applyFilters();
            },
          )
        ],
      ),
    );
  }

  Widget _buildCard(RouteModel r) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Left : summary
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.routeName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Text('${r.fromCity} → ${r.toCity}', style: const TextStyle(fontSize: 14)),
                    if (r.via.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text('via ${r.via}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    ]
                  ]),
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(Icons.directions_bus, size: 16, color: Colors.grey.shade700),
                    const SizedBox(width: 6),
                    Text('Bus: ${r.busNo}', style: const TextStyle(fontSize: 13)),
                    const SizedBox(width: 12),
                    Icon(Icons.event_seat, size: 16, color: Colors.grey.shade700),
                    const SizedBox(width: 6),
                    Text('${r.seats} seats', style: const TextStyle(fontSize: 13)),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Text('Fare: PKR ${r.fare.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    if (r.discount > 0)
                      Text('(${r.discount.toStringAsFixed(0)} off)', style: const TextStyle(color: Colors.red)),
                  ]),
                ],
              ),
            ),

            // Right : meta + actions
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${r.date} ${r.time}', style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 8),
                Text('${r.distanceKm} km • ${r.estimatedTime}', style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showAddEdit(r),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteRoute(r),
                    ),
                  ],
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Routes'),
        backgroundColor: Colors.teal,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEdit(),
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _loadRoutes,
        child: Column(
          children: [
            _buildTopBar(),
            if (_loading) const LinearProgressIndicator(),
            Expanded(
              child: _filtered.isEmpty && !_loading
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 80),
                        Center(child: Text('No routes found', style: TextStyle(color: Colors.grey.shade700))),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: _filtered.length,
                      itemBuilder: (ctx, i) => _buildCard(_filtered[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ---------------------------
/// AddEditRouteScreen (in-file)
/// ---------------------------
class AddEditRouteScreen extends StatefulWidget {
  final RouteModel? route;
  const AddEditRouteScreen({super.key, this.route});

  @override
  State<AddEditRouteScreen> createState() => _AddEditRouteScreenState();
}

class _AddEditRouteScreenState extends State<AddEditRouteScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController busNoCtrl;
  late TextEditingController fromCtrl;
  late TextEditingController toCtrl;
  late TextEditingController viaCtrl;
  late TextEditingController dateCtrl;
  late TextEditingController timeCtrl;
  late TextEditingController routeNameCtrl;
  late TextEditingController seatsCtrl;
  late TextEditingController fareCtrl;
  late TextEditingController originalFareCtrl;
  late TextEditingController discountCtrl;
  late TextEditingController distanceCtrl;
  late TextEditingController estTimeCtrl;
  late TextEditingController busesAssignedCtrl;

  String busType = 'Gold';
  bool refreshment = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    busNoCtrl = TextEditingController(text: widget.route?.busNo ?? '');
    fromCtrl = TextEditingController(text: widget.route?.fromCity ?? '');
    toCtrl = TextEditingController(text: widget.route?.toCity ?? '');
    viaCtrl = TextEditingController(text: widget.route?.via ?? '');
    dateCtrl = TextEditingController(text: widget.route?.date ?? DateFormat('yyyy-MM-dd').format(now));
    timeCtrl = TextEditingController(text: widget.route?.time ?? DateFormat('hh:mm a').format(now));
    routeNameCtrl = TextEditingController(text: widget.route?.routeName ?? '');
    seatsCtrl = TextEditingController(text: widget.route?.seats.toString() ?? '0');
    fareCtrl = TextEditingController(text: widget.route?.fare.toString() ?? '0');
    originalFareCtrl = TextEditingController(text: widget.route?.originalFare.toString() ?? '0');
    discountCtrl = TextEditingController(text: widget.route?.discount.toString() ?? '0');
    distanceCtrl = TextEditingController(text: widget.route?.distanceKm.toString() ?? '0');
    estTimeCtrl = TextEditingController(text: widget.route?.estimatedTime ?? '');
    busesAssignedCtrl = TextEditingController(text: widget.route?.busesAssigned.toString() ?? '0');
    busType = widget.route?.busType ?? 'Gold';
    refreshment = widget.route?.refreshment ?? false;
  }

  @override
  void dispose() {
    busNoCtrl.dispose();
    fromCtrl.dispose();
    toCtrl.dispose();
    viaCtrl.dispose();
    dateCtrl.dispose();
    timeCtrl.dispose();
    routeNameCtrl.dispose();
    seatsCtrl.dispose();
    fareCtrl.dispose();
    originalFareCtrl.dispose();
    discountCtrl.dispose();
    distanceCtrl.dispose();
    estTimeCtrl.dispose();
    busesAssignedCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = DateTime.tryParse(dateCtrl.text) ?? DateTime.now();
    final picked = await showDatePicker(context: context, initialDate: d, firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime.now().add(const Duration(days: 365 * 2)));
    if (picked != null) dateCtrl.text = DateFormat('yyyy-MM-dd').format(picked);
  }

  Future<void> _pickTime() async {
    final parts = timeCtrl.text.split(RegExp(r'[:\s]'));
    TimeOfDay initial = TimeOfDay.now();
    try {
      if (parts.length >= 2) {
        final h = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        initial = TimeOfDay(hour: h, minute: m);
      }
    } catch (_) {}
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) timeCtrl.text = picked.format(context);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final model = RouteModel(
      id: widget.route?.id,
      busNo: busNoCtrl.text.trim(),
      fromCity: fromCtrl.text.trim(),
      toCity: toCtrl.text.trim(),
      via: viaCtrl.text.trim(),
      date: dateCtrl.text.trim(),
      time: timeCtrl.text.trim(),
      busType: busType,
      refreshment: refreshment,
      routeName: routeNameCtrl.text.trim(),
      seats: int.tryParse(seatsCtrl.text.trim()) ?? 0,
      fare: double.tryParse(fareCtrl.text.trim()) ?? 0.0,
      originalFare: double.tryParse(originalFareCtrl.text.trim()) ?? 0.0,
      discount: double.tryParse(discountCtrl.text.trim()) ?? 0.0,
      distanceKm: int.tryParse(distanceCtrl.text.trim()) ?? 0,
      estimatedTime: estTimeCtrl.text.trim(),
      busesAssigned: int.tryParse(busesAssignedCtrl.text.trim()) ?? 0,
    );

    try {
      if (widget.route == null) {
        await DBHelper.instance.insertRoute(model.toMapForDb());

        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Route added')));
      } else {
        await DBHelper.instance.updateRoute(model.id!, model.toMapForDb());
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Route updated')));
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(TextEditingController c, String label, {TextInputType? keyboard}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        keyboardType: keyboard,
        decoration: InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
        validator: (v) {
          if (label == 'Route Name' || label == 'From City' || label == 'To City' || label == 'Bus No') {
            if (v == null || v.trim().isEmpty) return 'Required';
          }
          return null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.route != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit Route' : 'Add Route'), backgroundColor: Colors.teal),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(children: [
            _field(busNoCtrl, 'Bus No'),
            _field(routeNameCtrl, 'Route Name'),
            Row(children: [
              Expanded(child: _field(fromCtrl, 'From City')),
              const SizedBox(width: 12),
              Expanded(child: _field(toCtrl, 'To City')),
            ]),
            _field(viaCtrl, 'Via (optional)'),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: dateCtrl,
                  readOnly: true,
                  onTap: _pickDate,
                  decoration: InputDecoration(labelText: 'Date', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), suffixIcon: const Icon(Icons.calendar_today)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: timeCtrl,
                  readOnly: true,
                  onTap: _pickTime,
                  decoration: InputDecoration(labelText: 'Time', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), suffixIcon: const Icon(Icons.access_time)),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: busType,
              items: const [
                DropdownMenuItem(value: 'Gold', child: Text('Gold')),
                DropdownMenuItem(value: 'Business', child: Text('Business')),
                DropdownMenuItem(value: 'Executive', child: Text('Executive')),
              ],
              onChanged: (v) => setState(() => busType = v ?? 'Gold'),
              decoration: InputDecoration(labelText: 'Bus Type', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _field(seatsCtrl, 'Seats', keyboard: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: _field(distanceCtrl, 'Distance (km)', keyboard: TextInputType.number)),
            ]),
            Row(children: [
              Expanded(child: _field(fareCtrl, 'Fare (PKR)', keyboard: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: _field(originalFareCtrl, 'Original Fare', keyboard: TextInputType.number)),
            ]),
            _field(discountCtrl, 'Discount (amount)', keyboard: TextInputType.number),
            _field(estTimeCtrl, 'Estimated Time (e.g. 3h 20m)'),
            _field(busesAssignedCtrl, 'Buses Assigned', keyboard: TextInputType.number),
            const SizedBox(height: 8),
            Row(children: [
              const Text('Refreshment', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 12),
              Switch(value: refreshment, onChanged: (v) => setState(() => refreshment = v)),
            ]),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                child: _saving ? const CircularProgressIndicator(color: Colors.white) : Text(isEdit ? 'Save Changes' : 'Add Route'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

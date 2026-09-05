import 'package:flutter/material.dart';
import 'package:bus_ticket_system/database/db_helper.dart';

class AddEditRouteScreen extends StatefulWidget {
  final Map<String, dynamic>? route;

  const AddEditRouteScreen({super.key, this.route});

  @override
  State<AddEditRouteScreen> createState() => _AddEditRouteScreenState();
}

class _AddEditRouteScreenState extends State<AddEditRouteScreen> {
  final _formKey = GlobalKey<FormState>();

  final routeNameController = TextEditingController();
  final fromCityController = TextEditingController();
  final toCityController = TextEditingController();
  final viaController = TextEditingController();

  final seatsController = TextEditingController();
  final fareController = TextEditingController();
  final originalFareController = TextEditingController();
  final discountController = TextEditingController();

  final dateController = TextEditingController();
  final timeController = TextEditingController();
  final busNoController = TextEditingController();

  @override
  void initState() {
    super.initState();

    if (widget.route != null) {
      final r = widget.route!;
      routeNameController.text = r["routeName"] ?? "";
      fromCityController.text = r["fromCity"] ?? "";
      toCityController.text = r["toCity"] ?? "";
      viaController.text = r["via"] ?? "";
      seatsController.text = r["seats"].toString();
      fareController.text = r["fare"].toString();
      originalFareController.text = r["originalFare"].toString();
      discountController.text = r["discount"].toString();
      dateController.text = r["date"] ?? "";
      timeController.text = r["time"] ?? "";
      busNoController.text = r["busNo"] ?? "";
    }
  }

  Future<void> saveRoute() async {
    if (!_formKey.currentState!.validate()) return;

    final data = {
      "routeName": routeNameController.text.trim(),
      "fromCity": fromCityController.text.trim(),
      "toCity": toCityController.text.trim(),
      "via": viaController.text.trim(),
      "seats": int.tryParse(seatsController.text) ?? 0,
      "fare": double.tryParse(fareController.text) ?? 0,
      "originalFare": double.tryParse(originalFareController.text) ?? 0,
      "discount": int.tryParse(discountController.text) ?? 0,
      "date": dateController.text.trim(),
      "time": timeController.text.trim(),
      "busNo": busNoController.text.trim(),
    };

    if (widget.route == null) {
      await DBHelper.instance.insertRoute(data);
    } else {
      await DBHelper.instance.updateRoute(widget.route!["id"], data);
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.route != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? "Edit Route" : "Add Route"),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              textField(routeNameController, "Route Name"),
              textField(fromCityController, "From City"),
              textField(toCityController, "To City"),
              textField(viaController, "Via"),

              Row(
                children: [
                  Expanded(child: textField(seatsController, "Seats", number: true)),
                  const SizedBox(width: 10),
                  Expanded(child: textField(fareController, "Fare (PKR)", number: true)),
                ],
              ),

              Row(
                children: [
                  Expanded(child: textField(originalFareController, "Original Fare", number: true)),
                  const SizedBox(width: 10),
                  Expanded(child: textField(discountController, "Discount (optional)", number: true)),
                ],
              ),

              textField(dateController, "Date"),
              textField(timeController, "Time"),
              textField(busNoController, "Bus No."),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  onPressed: saveRoute,
                  child: Text(isEdit ? "Save Changes" : "Add Route"),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget textField(TextEditingController c, String label, {bool number = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: c,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        validator: (v) => v!.isEmpty ? "Required" : null,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}

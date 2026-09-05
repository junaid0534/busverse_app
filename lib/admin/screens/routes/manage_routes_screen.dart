// ignore: unused_import
import 'package:bus_ticket_system/admin/screens/manage_routes_screen.dart' hide AddEditRouteScreen;
import 'package:flutter/material.dart';
import 'package:bus_ticket_system/database/db_helper.dart';
import 'add_edit_route_screen.dart';


class ManageRoutesScreen extends StatefulWidget {
  const ManageRoutesScreen({super.key});

  @override
  State<ManageRoutesScreen> createState() => _ManageRoutesScreenState();
}

class _ManageRoutesScreenState extends State<ManageRoutesScreen> {
  List<Map<String, dynamic>> routes = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadRoutes();
  }

  Future<void> loadRoutes() async {
    setState(() => loading = true);
    routes = await DBHelper.instance.getRoutes();
    setState(() => loading = false);
  }

  Future<void> deleteRoute(int id) async {
    await DBHelper.instance.deleteRoute(id);
    loadRoutes();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Route deleted")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Routes"),
        backgroundColor: Colors.blue,
      ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddEditRouteScreen()),
          );
          loadRoutes();
        },
      ),

      body: loading
          ? const Center(child: CircularProgressIndicator())
          : routes.isEmpty
              ? const Center(
                  child: Text(
                    "No Routes Added Yet",
                    style: TextStyle(fontSize: 18),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: loadRoutes,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: routes.length,
                    itemBuilder: (context, index) {
                      final r = routes[index];

                      return Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        margin: const EdgeInsets.only(bottom: 14),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Route Title
                              Row(
                                children: [
                                  Text(
                                    "${r['fromCity']} → ${r['toCity']}",
                                    style: const TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black12,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      r["busNo"],
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 6),

                              // Route Name
                              Text(
                                r["routeName"] ?? "",
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.grey.shade700,
                                ),
                              ),

                              const SizedBox(height: 8),

                              // Fare, Seats Row
                              Row(
                                children: [
                                  const Icon(Icons.event_seat, size: 18),
                                  const SizedBox(width: 4),
                                  Text("Seats: ${r['seats']}"),

                                  const SizedBox(width: 20),

                                  const Icon(Icons.attach_money, size: 18),
                                  const SizedBox(width: 4),
                                  Text("Fare: ${r['fare']} PKR"),
                                ],
                              ),

                              const SizedBox(height: 8),

                              // Discount Badge
                              if ((r['discount'] ?? 0) > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    "Discount: ${r['discount']} PKR",
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),

                              const SizedBox(height: 10),

                              // Date + Time Row
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 18),
                                  const SizedBox(width: 4),
                                  Text(r["date"]),
                                  const SizedBox(width: 20),
                                  const Icon(Icons.access_time, size: 18),
                                  const SizedBox(width: 4),
                                  Text(r["time"]),
                                ],
                              ),

                              const SizedBox(height: 12),

                              // Edit / Delete Buttons
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () async {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => AddEditRouteScreen(
                                              route: r,
                                            ),
                                          ),
                                        );
                                        loadRoutes();
                                      },
                                      icon: const Icon(Icons.edit),
                                      label: const Text("Edit"),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () =>
                                          deleteRoute(r["id"] as int),
                                      icon: const Icon(Icons.delete),
                                      label: const Text("Delete"),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

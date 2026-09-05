class RouteModel {
  int? id;
  String routeName;
  String fromCity;
  String toCity;
  String viaCity;

  RouteModel({
    this.id,
    required this.routeName,
    required this.fromCity,
    required this.toCity,
    required this.viaCity,
  });

  Map<String, dynamic> toMap() {
    final map = {
      "routeName": routeName,
      "fromCity": fromCity,
      "toCity": toCity,
      "viaCity": viaCity,
    };

    if (id != null) map["id"] = id as String;

    return map;
  }

  factory RouteModel.fromMap(Map<String, dynamic> m) {
    return RouteModel(
      id: m["id"],
      routeName: m["routeName"],
      fromCity: m["fromCity"],
      toCity: m["toCity"],
      viaCity: m["viaCity"],
    );
  }
}

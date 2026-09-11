class UserModel {
  int? id;
  String firstName;
  String lastName;
  String email;
  String phone;
  String cnic;
  String gender;
  String password;
  String? street;
  String? city;
  String? region;
  String? zip;
  String role; // 'user', 'sub_admin', 'super_admin'
  String? terminalName; // e.g. "Kalma Chowk Terminal"
  String? terminalCity; // e.g. "Lahore"
  String status; // 'active', 'suspended'

  UserModel({
    this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.cnic,
    required this.gender,
    required this.password,
    this.street,
    this.city,
    this.region,
    this.zip,
    this.role = 'user',
    this.terminalName,
    this.terminalCity,
    this.status = 'active',
  });

  // Convert object -> Map (for database)
  Map<String, dynamic> toMap() {
    return {
      "id": id,
      "firstName": firstName.trim(),
      "lastName": lastName.trim(),
      "email": email.toLowerCase().trim(),
      "phone": phone.trim(),
      "cnic": cnic.trim(),
      "gender": gender,
      "password": password.trim(),
      "street": street?.trim(),
      "city": city?.trim(),
      "region": region?.trim(),
      "zip": zip?.trim(),
      "role": role,
      "terminalName": terminalName?.trim(),
      "terminalCity": terminalCity?.trim(),
      "status": status,
    };
  }

  // Convert database row -> object
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map["id"],
      firstName: map["firstName"] ?? "",
      lastName: map["lastName"] ?? "",
      email: map["email"] ?? "",
      phone: map["phone"] ?? "",
      cnic: map["cnic"] ?? "",
      gender: map["gender"] ?? "M",
      password: map["password"] ?? "",
      street: map["street"],
      city: map["city"],
      region: map["region"],
      zip: map["zip"],
      role: map["role"] ?? "user",
      terminalName: map["terminalName"],
      terminalCity: map["terminalCity"],
      status: map["status"] ?? "active",
    );
  }
}

class User {
  final int id;
  final String name;
  final String enrollNumber;
  final String year;
  final String section;
  final String batch;
  final String role;
  final bool isOnline;
  final DateTime? lastActive;
  final String? ipAddress; // Added IP address field

  User({
    required this.id,
    required this.name,
    required this.enrollNumber,
    required this.year,
    required this.section,
    required this.batch,
    required this.role,
    this.isOnline = false,
    this.lastActive,
    this.ipAddress,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      enrollNumber: json['enrollNumber'] ?? json['enroll_number'],
      year: json['year'],
      section: json['section'],
      batch: json['batch'],
      role: json['role'],
      isOnline: json['isOnline'] ?? json['is_online'] ?? false,
      lastActive: json['lastActive'] != null 
          ? DateTime.tryParse(json['lastActive'].toString())
          : json['last_active'] != null 
              ? DateTime.tryParse(json['last_active'].toString())
              : null,
      ipAddress: json['ipAddress'] ?? json['ip_address'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'enrollNumber': enrollNumber,
      'year': year,
      'section': section,
      'batch': batch,
      'role': role,
      'isOnline': isOnline,
      'lastActive': lastActive?.toIso8601String(),
      'ipAddress': ipAddress,
    };
  }
}
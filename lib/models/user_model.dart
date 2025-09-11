class User {
  final int id;
  final String name;
  final String enrollNumber;
  final String year;
  final String section;
  final String batch;
  final String role;
  final bool isOnline;

  User({
    required this.id,
    required this.name,
    required this.enrollNumber,
    required this.year,
    required this.section,
    required this.batch,
    required this.role,
    this.isOnline = false,
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
    };
  }
}
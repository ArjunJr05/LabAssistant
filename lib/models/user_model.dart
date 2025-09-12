class User {
  final int id;
  final String name;
  final String enrollNumber;
  final String year;
  final String section;
  final String batch;
  final String role;
  final bool isOnline;
  final DateTime? lastActive; // Added this field

  User({
    required this.id,
    required this.name,
    required this.enrollNumber,
    required this.year,
    required this.section,
    required this.batch,
    required this.role,
    this.isOnline = false,
    this.lastActive, // Added this parameter
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
              : null, // Added parsing for lastActive field
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
      'lastActive': lastActive?.toIso8601String(), // Added lastActive to JSON
    };
  }

  // copyWith method for immutable updates
  User copyWith({
    int? id,
    String? name,
    String? enrollNumber,
    String? year,
    String? section,
    String? batch,
    String? role,
    bool? isOnline,
    DateTime? lastActive,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      enrollNumber: enrollNumber ?? this.enrollNumber,
      year: year ?? this.year,
      section: section ?? this.section,
      batch: batch ?? this.batch,
      role: role ?? this.role,
      isOnline: isOnline ?? this.isOnline,
      lastActive: lastActive ?? this.lastActive,
    );
  }
}
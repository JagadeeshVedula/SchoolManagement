class Staff {
  final int id;
  final String name;
  final String qualification;
  final String mobile;
  final DateTime? createdAt;

  Staff({
    required this.id,
    required this.name,
    required this.qualification,
    required this.mobile,
    this.createdAt,
  });

  factory Staff.fromJson(Map<String, dynamic> json) {
    return Staff(
      id: json['id'] as int? ?? 0,
      name: json['Name'] as String? ?? '',
      qualification: json['Qualification'] as String? ?? '',
      mobile: json['Mobile'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'Name': name,
      'Qualification': qualification,
      'Mobile': mobile,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}

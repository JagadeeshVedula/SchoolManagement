class Staff {
  final int id;
  final String name;
  final String qualification;
  final String mobile;
  final String? salary;
  final String? staffType;
  final DateTime? createdAt;

  Staff({
    required this.id,
    required this.name,
    required this.qualification,
    required this.mobile,
    this.salary,
    this.staffType,
    this.createdAt,
  });

  factory Staff.fromJson(Map<String, dynamic> json) {
    return Staff(
      id: json['id'] as int? ?? 0,
      name: json['Name'] as String? ?? '',
      qualification: json['Qualification'] as String? ?? '',
      mobile: json['Mobile'] as String? ?? '',
      salary: json['Salary'] as String? ?? '',
      staffType: json['StaffType'] as String?,
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
      'Salary': salary,
      'StaffType': staffType,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}

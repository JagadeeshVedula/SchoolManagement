class Student {
  final int? id;
  final String name;
  final String className;
  final String fatherName;
  final String motherName;
  final String parentMobile;

  Student({
    this.id,
    required this.name,
    required this.className,
    required this.fatherName,
    required this.motherName,
    required this.parentMobile,
  });

  // Convert JSON from Supabase to Student object
  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'] as int?,
      name: json['Name'] as String? ?? '',
      className: json['Class'] as String? ?? '',
      fatherName: json['Father Name'] as String? ?? '',
      motherName: json['Mother Name'] as String? ?? '',
      parentMobile: json['Parent Mobile'] as String? ?? '',
    );
  }

  // Convert Student object to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'Name': name,
      'Class': className,
      'Father Name': fatherName,
      'Mother Name': motherName,
      'Parent Mobile': parentMobile,
    };
  }
}

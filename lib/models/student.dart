class Student {
  final int? id;
  final String name;
  final String className;
  final String fatherName;
  final String motherName;
  final String parentMobile;
  final double schoolFeeConcession;
  final double tuitionFeeConcession;
  final String? address;
  final String? gender;
  final String? busRoute;
  final String? busNo;
  final String? busFeeFacility;
  final String? hostelFacility;

  Student({
    this.id,
    required this.name,
    required this.className,
    required this.fatherName,
    required this.motherName,
    required this.parentMobile,
    this.schoolFeeConcession = 0.0,
    this.tuitionFeeConcession = 0.0,
    this.address,
    this.gender,
    this.busRoute,
    this.busNo,
    this.busFeeFacility,
    this.hostelFacility,
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
      schoolFeeConcession: double.tryParse((json['School Fee Concession'] as dynamic).toString()) ?? 0.0,
      tuitionFeeConcession: double.tryParse((json['Tuition Fee Concession'] as dynamic).toString()) ?? 0.0,
      address: json['ADDRESS'] as String?,
      gender: json['GENDER'] as String?,
      busRoute: json['Route'] as String?,
      busNo: json['BusNo'] as String?,
      busFeeFacility: json['Bus Facility'] as String?,
      hostelFacility: json['Hostel Facility'] as String?,
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
      'School Fee Concession': schoolFeeConcession,
      'Tuition Fee Concession': tuitionFeeConcession,
      'ADDRESS': address,
      'GENDER': gender,
      'Route': busRoute,
      'BusNo': busNo,
      'Bus Facility': busFeeFacility,
      'Hostel Facility': hostelFacility,
    };
  }
}

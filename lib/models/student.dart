class Student {
  final int? id;
  final String name;
  final String className;
  final String fatherName;
  final String motherName;
  final String parentMobile;
  final double schoolFeeConcession;
  final double busFeeConcession;
  final double hostelFeeConcession;
  final double tuitionFeeConcession;
  final String? address;
  final String? gender;
  final String? busRoute;
  final String? busNo;
  final String? busFacility;
  final String? hostelFacility;
  final String? doj;

  Student({
    this.id,
    required this.name,
    required this.className,
    required this.fatherName,
    required this.motherName,
    required this.parentMobile,
    this.schoolFeeConcession = 0.0,
    this.busFeeConcession = 0.0,
    this.hostelFeeConcession = 0.0,
    this.tuitionFeeConcession = 0.0,
    this.address,
    this.gender,
    this.busRoute,
    this.busNo,
    this.busFacility,
    this.hostelFacility,
    this.doj,
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
      busFeeConcession: double.tryParse((json['Bus Fee Concession'] as dynamic).toString()) ?? 0.0,
      hostelFeeConcession: double.tryParse((json['Hostel Fee Concession'] as dynamic).toString()) ?? 0.0,
      tuitionFeeConcession: double.tryParse((json['Tuition Fee Concession'] as dynamic).toString()) ?? 0.0,
      address: json['ADDRESS'] as String?,
      gender: json['GENDER'] as String?,
      busRoute: json['Route'] as String?,
      busNo: json['BusNo'] as String?,
      busFacility: json['Bus Facility'] as String?,
      hostelFacility: json['Hostel Facility'] as String?,
      doj: json['DOJ'] as String?,
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
      'Bus Fee Concession': busFeeConcession,
      'Hostel Fee Concession': hostelFeeConcession,
      'Tuition Fee Concession': tuitionFeeConcession,
      'ADDRESS': address,
      'GENDER': gender,
      'Route': busRoute,
      'BusNo': busNo,
      'Bus Facility': busFacility,
      'Hostel Facility': hostelFacility,
      'DOJ': doj,
    };
  }

  Student copyWith({
    int? id,
    String? name,
    String? className,
    String? fatherName,
    String? motherName,
    String? parentMobile,
    double? schoolFeeConcession,
    double? busFeeConcession,
    double? hostelFeeConcession,
    double? tuitionFeeConcession,
    String? address,
    String? gender,
    String? busRoute,
    String? busNo,
    String? busFacility,
    String? hostelFacility,
    String? doj,
  }) {
    return Student(
      id: id ?? this.id,
      name: name ?? this.name,
      className: className ?? this.className,
      fatherName: fatherName ?? this.fatherName,
      motherName: motherName ?? this.motherName,
      parentMobile: parentMobile ?? this.parentMobile,
      schoolFeeConcession: schoolFeeConcession ?? this.schoolFeeConcession,
      busFeeConcession: busFeeConcession ?? this.busFeeConcession,
      hostelFeeConcession: hostelFeeConcession ?? this.hostelFeeConcession,
      tuitionFeeConcession: tuitionFeeConcession ?? this.tuitionFeeConcession,
      address: address ?? this.address,
      gender: gender ?? this.gender,
      busRoute: busRoute ?? this.busRoute,
      busNo: busNo ?? this.busNo,
      busFacility: busFacility ?? this.busFacility,
      hostelFacility: hostelFacility ?? this.hostelFacility,
      doj: doj ?? this.doj,
    );
  }
}

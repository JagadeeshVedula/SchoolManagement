class Performance {
  final int? id;
  final String studentName;
  final String assessment;
  final String? teluguMarks;
  final String? englishMarks;
  final String? hindiMarks;
  final String? mathsMarks;
  final String? scienceMarks;
  final String? socialMarks;
  final String? computersMarks;

  Performance({
    this.id,
    required this.studentName,
    required this.assessment,
    this.teluguMarks,
    this.englishMarks,
    this.hindiMarks,
    this.mathsMarks,
    this.scienceMarks,
    this.socialMarks,
    this.computersMarks,
  });

  // Convert JSON from Supabase to Performance object
  factory Performance.fromJson(Map<String, dynamic> json) {
    return Performance(
      id: json['id'] as int?,
      studentName: json['Student Name'] as String? ?? '',
      assessment: json['Assessment'] as String? ?? '',
      teluguMarks: json['Telugu Marks'] as String?,
      englishMarks: json['English Marks'] as String?,
      hindiMarks: json['Hindi Marks'] as String?,
      mathsMarks: json['Maths Marks'] as String?,
      scienceMarks: json['Science Marks'] as String?,
      socialMarks: json['Social Marks'] as String?,
      computersMarks: json['Computers Marks'] as String?,
    );
  }

  // Convert Performance object to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'Student Name': studentName,
      'Assessment': assessment,
      'Telugu Marks': teluguMarks,
      'English Marks': englishMarks,
      'Hindi Marks': hindiMarks,
      'Maths Marks': mathsMarks,
      'Science Marks': scienceMarks,
      'Social Marks': socialMarks,
      'Computers Marks': computersMarks,
    };
  }
}

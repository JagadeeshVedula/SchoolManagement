class Performance {
  final int? id;
  final String studentName;
  final String subject;
  final String marks;
  final String grade;
  final String remarks;

  Performance({
    this.id,
    required this.studentName,
    required this.subject,
    required this.marks,
    required this.grade,
    required this.remarks,
  });

  // Convert JSON from Supabase to Performance object
  factory Performance.fromJson(Map<String, dynamic> json) {
    String pick(List<String> keys) {
      for (var k in keys) {
        if (json.containsKey(k)) {
          final v = json[k];
          if (v != null) return v.toString();
        }
      }
      // fallback: search any key containing the keyword
      for (var entry in json.entries) {
        final key = entry.key.toString().toLowerCase();
        for (var k in keys) {
          if (key.contains(k.toLowerCase().replaceAll(' ', ''))) {
            final v = entry.value;
            if (v != null) return v.toString();
          }
        }
      }
      return '';
    }

    return Performance(
      id: json['id'] as int?,
      studentName: pick(['Student Name', 'student_name', 'student name', 'student']),
      subject: pick(['Subject', 'Subject Name', 'SubjectName', 'subject', 'subject_name']),
      marks: pick(['Marks', 'marks', 'marks_obtained', 'mark']),
      grade: pick(['Grade', 'grade']),
      remarks: pick(['Remarks', 'remarks', 'note']),
    );
  }

  // Convert Performance object to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'Student Name': studentName,
      'Subject': subject,
      'Marks': marks,
      'Grade': grade,
      'Remarks': remarks,
    };
  }
}

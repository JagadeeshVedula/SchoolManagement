import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:school_management/models/student.dart';
import 'package:school_management/models/performance.dart';
import 'package:school_management/services/supabase_service.dart';
import 'package:school_management/screens/edit_student_screen.dart';

class StudentDetailScreen extends StatefulWidget {
  final Student student;

  const StudentDetailScreen({super.key, required this.student});

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  late Future<List<String>> _assessmentsFuture;
  String? _selectedAssessment;
  bool _isAbsent = false;
  late Future<List<Performance>> _performanceFuture;
  late Student _currentStudent;

  @override
  void initState() {
    super.initState();
    _currentStudent = widget.student;
    _assessmentsFuture = SupabaseService.getAssessmentsForStudent(_currentStudent.name);
    _performanceFuture = Future.value([]);
  }

  Future<void> _refreshStudentData() async {
    final students = await SupabaseService.getStudentsByParentMobile(_currentStudent.parentMobile);
    final updated = students.firstWhere((s) => s.id == _currentStudent.id, orElse: () => _currentStudent);
    setState(() {
      _currentStudent = updated;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentStudent.name,
          style: GoogleFonts.poppins(),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditStudentScreen(student: _currentStudent),
                ),
              );
              if (result == true) {
                _refreshStudentData();
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Student Photo
            if (_currentStudent.photoUrl != null && _currentStudent.photoUrl!.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 16),
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF800000), width: 2),
                  image: DecorationImage(
                    image: NetworkImage(_currentStudent.photoUrl!),
                    fit: BoxFit.cover,
                  ),
                ),
              )
            else
              Container(
                margin: const EdgeInsets.only(top: 16),
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF800000).withOpacity(0.1),
                  border: Border.all(color: const Color(0xFF800000), width: 2),
                ),
                child: const Icon(Icons.person, size: 60, color: Color(0xFF800000)),
              ),
            // Student Information Card
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF800000).withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF800000).withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Student Information',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow('Name:', _currentStudent.name),
                  if (_currentStudent.rollNo != null && _currentStudent.rollNo!.isNotEmpty)
                    _buildInfoRow('Admsn No:', _currentStudent.rollNo!),
                  _buildInfoRow('Class:', _currentStudent.className),
                  _buildInfoRow('Father Name:', _currentStudent.fatherName),
                  _buildInfoRow('Mother Name:', _currentStudent.motherName),
                  _buildInfoRow('Parent Mobile:', _currentStudent.parentMobile),
                  if (_currentStudent.doj != null && _currentStudent.doj!.isNotEmpty)
                    _buildInfoRow('Joining Date:', _currentStudent.doj!),
                  if (_currentStudent.aadhar != null && _currentStudent.aadhar!.isNotEmpty)
                    _buildInfoRow('Aadhar No:', _currentStudent.aadhar!),
                  if (_currentStudent.apaar != null && _currentStudent.apaar!.isNotEmpty)
                    _buildInfoRow('Apaar ID:', _currentStudent.apaar!),
                  _buildInfoRow('Address:', _currentStudent.address ?? 'N/A'),
                  if (_currentStudent.gender != null && _currentStudent.gender!.isNotEmpty)
                    _buildInfoRow('Gender:', _currentStudent.gender!),
                  if (_currentStudent.schoolFeeConcession > 0)
                    _buildInfoRow('School Fee Concession:', 'Rs.${_currentStudent.schoolFeeConcession.toStringAsFixed(2)}'),
                  if (_currentStudent.tuitionFeeConcession > 0)
                    _buildInfoRow('Tuition Fee Concession:', 'Rs.${_currentStudent.tuitionFeeConcession.toStringAsFixed(2)}'),
                  if (_currentStudent.busRoute != null && _currentStudent.busRoute!.isNotEmpty)
                    _buildInfoRow('Bus Route:', _currentStudent.busRoute!),
                  if (_currentStudent.busNo != null && _currentStudent.busNo!.isNotEmpty)
                    _buildInfoRow('Bus Number:', _currentStudent.busNo!),
                  if (_currentStudent.busFacility != null && _currentStudent.busFacility!.isNotEmpty)
                    _buildInfoRow('Bus Facility:', _currentStudent.busFacility!),
                  if (_currentStudent.hostelFacility != null && _currentStudent.hostelFacility!.isNotEmpty)
                    _buildInfoRow('Hostel Facility:', _currentStudent.hostelFacility!),
                ],
              ),
            ),


            // Performance Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Academic Performance',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            // Assessment selector and Performance Data (filtered by Assessment)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: FutureBuilder<List<String>>(
                future: _assessmentsFuture,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const SizedBox(height: 56, child: Center(child: CircularProgressIndicator()));
                  }

                  if (snap.hasError) {
                    return Text('Error loading assessments: ${snap.error}');
                  }

                  final assessments = snap.data ?? [];
                  if (assessments.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text('No assessments found', style: GoogleFonts.inter(color: Colors.grey)),
                    );
                  }

                  // If not selected yet, pick the first
                  _selectedAssessment ??= assessments.first;

                  return Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _selectedAssessment,
                            underline: const SizedBox(),
                            items: assessments.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedAssessment = val;
                                _performanceFuture = SupabaseService.getStudentPerformanceByAssessment(_currentStudent.name, _selectedAssessment!);
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _performanceFuture = SupabaseService.getStudentPerformanceByAssessment(_currentStudent.name, _selectedAssessment!);
                          });
                        },
                        child: Text('Load', style: GoogleFonts.inter()),
                      ),
                    ],
                  );
                },
              ),
            ),

            FutureBuilder<List<Performance>>(
              future: _performanceFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Error loading performance: ${snapshot.error}',
                      style: GoogleFonts.inter(color: Colors.red),
                    ),
                  );
                }

                final performances = snapshot.data ?? [];

                if (performances.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'No performance data available for this assessment',
                      style: GoogleFonts.inter(color: Colors.grey),
                    ),
                  );
                }

                // Display subject name and grade for each record
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: performances.length,
                    itemBuilder: (context, index) {
                      final perf = performances[index];
                      final subjectMarks = [
                        if (perf.teluguMarks != null && perf.teluguMarks!.isNotEmpty) 'Telugu: ${perf.teluguMarks}',
                        if (perf.englishMarks != null && perf.englishMarks!.isNotEmpty) 'English: ${perf.englishMarks}',
                        if (perf.hindiMarks != null && perf.hindiMarks!.isNotEmpty) 'Hindi: ${perf.hindiMarks}',
                        if (perf.mathsMarks != null && perf.mathsMarks!.isNotEmpty) 'Maths: ${perf.mathsMarks}',
                        if (perf.scienceMarks != null && perf.scienceMarks!.isNotEmpty) 'Science: ${perf.scienceMarks}',
                        if (perf.socialMarks != null && perf.socialMarks!.isNotEmpty) 'Social: ${perf.socialMarks}',
                        if (perf.computersMarks != null && perf.computersMarks!.isNotEmpty) 'Computers: ${perf.computersMarks}',
                      ];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Assessment: ${perf.assessment}',
                                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF800000)),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                children: subjectMarks.map((mark) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.green[50],
                                      border: Border.all(color: Colors.green[300]!),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      mark,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.green[800],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w400,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

}

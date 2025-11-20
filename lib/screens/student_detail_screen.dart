import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:school_management/models/student.dart';
import 'package:school_management/models/performance.dart';
import 'package:school_management/services/supabase_service.dart';

class StudentDetailScreen extends StatefulWidget {
  final Student student;

  const StudentDetailScreen({super.key, required this.student});

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  late Future<List<String>> _assessmentsFuture;
  String? _selectedAssessment;
  late Future<List<Performance>> _performanceFuture;

  @override
  void initState() {
    super.initState();
    _assessmentsFuture = SupabaseService.getAssessmentsForStudent(widget.student.name);
    _performanceFuture = Future.value([]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.student.name,
          style: GoogleFonts.poppins(),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Student Information Card
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
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
                  _buildInfoRow('Name:', widget.student.name),
                  _buildInfoRow('Class:', widget.student.className),
                  _buildInfoRow('Father Name:', widget.student.fatherName),
                  _buildInfoRow('Mother Name:', widget.student.motherName),
                  _buildInfoRow('Parent Mobile:', widget.student.parentMobile),
                  _buildInfoRow('Address:', widget.student.address ?? 'N/A'),
                  if (widget.student.gender != null && widget.student.gender!.isNotEmpty)
                    _buildInfoRow('Gender:', widget.student.gender!),
                  if (widget.student.schoolFeeConcession > 0)
                    _buildInfoRow('School Fee Concession:', '₹${widget.student.schoolFeeConcession.toStringAsFixed(2)}'),
                  if (widget.student.tuitionFeeConcession > 0)
                    _buildInfoRow('Tuition Fee Concession:', '₹${widget.student.tuitionFeeConcession.toStringAsFixed(2)}'),
                  if (widget.student.busRoute != null && widget.student.busRoute!.isNotEmpty)
                    _buildInfoRow('Bus Route:', widget.student.busRoute!),
                  if (widget.student.busNo != null && widget.student.busNo!.isNotEmpty)
                    _buildInfoRow('Bus Number:', widget.student.busNo!),
                  if (widget.student.busFeeFacility != null && widget.student.busFeeFacility!.isNotEmpty)
                    _buildInfoRow('Bus Facility:', widget.student.busFeeFacility!),
                  if (widget.student.hostelFacility != null && widget.student.hostelFacility!.isNotEmpty)
                    _buildInfoRow('Hostel Facility:', widget.student.hostelFacility!),
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
                                _performanceFuture = SupabaseService.getStudentPerformanceByAssessment(widget.student.name, _selectedAssessment!);
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _performanceFuture = SupabaseService.getStudentPerformanceByAssessment(widget.student.name, _selectedAssessment!);
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
                                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.blue[800]),
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

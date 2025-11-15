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
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          title: Text(
                            perf.subject.isNotEmpty ? perf.subject : 'Subject',
                            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 6),
                              Text('Marks: ${perf.marks}', style: GoogleFonts.inter(color: Colors.grey[700])),
                              if (perf.remarks.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text('Remarks: ${perf.remarks}', style: GoogleFonts.inter(color: Colors.grey[600])),
                              ],
                            ],
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _getGradeColor(perf.grade),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(perf.grade.isNotEmpty ? perf.grade : '-', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
                          ),
                          isThreeLine: perf.remarks.isNotEmpty,
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

  Color _getGradeColor(String grade) {
    switch (grade.toUpperCase()) {
      case 'A':
        return Colors.green;
      case 'B':
        return Colors.blue;
      case 'C':
        return Colors.orange;
      case 'D':
        return Colors.red;
      case 'F':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }
}

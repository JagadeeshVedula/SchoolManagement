import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:school_management/models/student.dart';
import 'package:school_management/models/performance.dart';
import 'package:school_management/services/supabase_service.dart';

class StudentDetailScreen extends StatefulWidget {
  final Student student;
  final String? initialView; // 'data' or 'performance'
  final bool isParentView;

  const StudentDetailScreen({
    super.key, 
    required this.student, 
    this.initialView,
    this.isParentView = false,
  });

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  late Future<List<String>> _assessmentsFuture;
  String? _selectedAssessment;
  bool _isAbsent = false;
  late Future<List<Performance>> _performanceFuture;
  late Future<List<Map<String, dynamic>>> _homeworkFuture;

  @override
  void initState() {
    super.initState();
    _assessmentsFuture = SupabaseService.getAssessmentsForStudent(widget.student.name);
    _performanceFuture = Future.value([]);
    
    // If initial view is performance, load the first assessment automatically
    if (widget.initialView == 'performance' || widget.initialView == null) {
      _assessmentsFuture.then((assessments) {
        if (assessments.isNotEmpty && mounted) {
          setState(() {
            _selectedAssessment = assessments.first;
            _performanceFuture = SupabaseService.getStudentPerformanceByAssessment(widget.student.name, _selectedAssessment!);
          });
        }
      });
    }

    if (widget.initialView == 'homework' || widget.initialView == null) {
      final today = DateFormat('dd-MM-yyyy').format(DateTime.now());
      _homeworkFuture = SupabaseService.getHomeworkByClassAndDate(widget.student.className, today);
    } else {
      _homeworkFuture = Future.value([]);
    }
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
            const SizedBox(height: 20),
            // Student Profile Photo
            if (widget.initialView == null || widget.initialView == 'data')
            Center(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.blue[100]!, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                  image: widget.student.photoUrl != null && widget.student.photoUrl!.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(widget.student.photoUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: widget.student.photoUrl == null || widget.student.photoUrl!.isEmpty
                    ? Icon(Icons.person, size: 60, color: Colors.blue[200])
                    : null,
              ),
            ),
            const SizedBox(height: 10),
            if (widget.initialView == null || widget.initialView == 'data')
            Text(
              widget.student.name,
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E293B),
              ),
            ),
            if (widget.initialView == null || widget.initialView == 'data')
            Text(
              'Class: ${widget.student.className}',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),

            // Student Information Card
            if (widget.initialView == null || widget.initialView == 'data')
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
                  if (widget.student.doj != null && widget.student.doj!.isNotEmpty)
                    _buildInfoRow('Joining Date:', widget.student.doj!),
                  _buildInfoRow('Address:', widget.student.address ?? 'N/A'),
                  if (widget.student.gender != null && widget.student.gender!.isNotEmpty)
                    _buildInfoRow('Gender:', widget.student.gender!),
                  if (widget.student.schoolFeeConcession > 0)
                    _buildInfoRow('School Fee Concession:', 'Rs.${widget.student.schoolFeeConcession.toStringAsFixed(2)}'),
                  if (widget.student.tuitionFeeConcession > 0)
                    _buildInfoRow('Tuition Fee Concession:', 'Rs.${widget.student.tuitionFeeConcession.toStringAsFixed(2)}'),
                  if (widget.student.busRoute != null && widget.student.busRoute!.isNotEmpty)
                    _buildInfoRow('Bus Route:', widget.student.busRoute!),
                  if (widget.student.busNo != null && widget.student.busNo!.isNotEmpty)
                    _buildInfoRow('Bus Number:', widget.student.busNo!),
                  if (widget.student.busFacility != null && widget.student.busFacility!.isNotEmpty)
                    _buildInfoRow('Bus Facility:', widget.student.busFacility!),
                  if (widget.student.hostelFacility != null && widget.student.hostelFacility!.isNotEmpty)
                    _buildInfoRow('Hostel Facility:', widget.student.hostelFacility!),
                ],
              ),
            ),
            // Absent Checkbox - HIDE FOR PARENTS
            if (!widget.isParentView)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: CheckboxListTile(
                    title: Text('Is Absent Today', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    value: _isAbsent,
                    onChanged: (bool? value) {
                      setState(() {
                        _isAbsent = value ?? false;
                      });
                      if (_isAbsent) {
                        _sendAbsenceNotification();
                      }
                    },
                    activeColor: Colors.orange,
                    controlAffinity: ListTileControlAffinity.leading,
                    secondary: const Icon(Icons.sms),
                  ),
                ),
              ),

            // Performance Section
            if (widget.initialView == null || widget.initialView == 'performance')
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
            if (widget.initialView == null || widget.initialView == 'performance')
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

            if (widget.initialView == null || widget.initialView == 'performance')
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

                return Column(
                  children: performances.map((perf) => _buildPerformanceCard(perf)).toList(),
                );
              },
            ),

            // Homework Section
            if (widget.initialView == null || widget.initialView == 'homework')
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.assignment, color: Color(0xFF8B5CF6), size: 28),
                        const SizedBox(width: 12),
                        Text(
                          'Today\'s Homework',
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      DateFormat('MMMM dd, yyyy').format(DateTime.now()),
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: _homeworkFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: CircularProgressIndicator(),
                          ));
                        }
                        if (snapshot.hasError) {
                          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                        }
                        final homeworkList = snapshot.data ?? [];
                        if (homeworkList.isEmpty) {
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.sentiment_satisfied_alt, size: 64, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                Text(
                                  'No homework assigned for today!',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        final homework = homeworkList.first;
                        // Expected keys: TELUGU, HINDI, ENGLISH, MATHS, SCIENCE, SOCIAL, COMPUTERS
                        final subjects = [
                          {'name': 'Telugu', 'key': 'TELUGU', 'color': Color(0xFFEF4444)},
                          {'name': 'Hindi', 'key': 'HINDI', 'color': Color(0xFFF59E0B)},
                          {'name': 'English', 'key': 'ENGLISH', 'color': Color(0xFF3B82F6)},
                          {'name': 'Maths', 'key': 'MATHS', 'color': Color(0xFF10B981)},
                          {'name': 'Science', 'key': 'SCIENCE', 'color': Color(0xFF6366F1)},
                          {'name': 'Social', 'key': 'SOCIAL', 'color': Color(0xFFEC4899)},
                          {'name': 'Computers', 'key': 'COMPUTERS', 'color': Color(0xFF8B5CF6)},
                        ];

                        return Column(
                          children: subjects.map((sub) {
                            final work = homework[sub['key']] as String? ?? '';
                            if (work.isEmpty || work == 'N/A') return const SizedBox();

                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: (sub['color'] as Color).withOpacity(0.05),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: (sub['color'] as Color).withOpacity(0.2)),
                                boxShadow: [
                                  BoxShadow(
                                    color: (sub['color'] as Color).withOpacity(0.03),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: sub['color'] as Color,
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(19),
                                        bottomRight: Radius.circular(20),
                                      ),
                                    ),
                                    child: Text(
                                      sub['name'] as String,
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Text(
                                      work,
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        height: 1.5,
                                        color: const Color(0xFF1E293B),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceCard(Performance perf) {
    // Parse marks and prepare data for the chart
    final List<Map<String, dynamic>> subjectData = [
      {'name': 'Telugu', 'marks': double.tryParse(perf.teluguMarks ?? '0') ?? 0},
      {'name': 'English', 'marks': double.tryParse(perf.englishMarks ?? '0') ?? 0},
      {'name': 'Hindi', 'marks': double.tryParse(perf.hindiMarks ?? '0') ?? 0},
      {'name': 'Maths', 'marks': double.tryParse(perf.mathsMarks ?? '0') ?? 0},
      {'name': 'Science', 'marks': double.tryParse(perf.scienceMarks ?? '0') ?? 0},
      {'name': 'Social', 'marks': double.tryParse(perf.socialMarks ?? '0') ?? 0},
      {'name': 'Computers', 'marks': double.tryParse(perf.computersMarks ?? '0') ?? 0},
    ].where((sub) => (sub['marks'] as num) > 0).toList();

    if (subjectData.isEmpty) return const SizedBox();

    double total = 0;
    for (var sub in subjectData) {
      total += sub['marks'] as num;
    }
    final avg = total / subjectData.length;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Score Summary
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue[600],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      perf.assessment,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Overall Average: ${avg.toStringAsFixed(1)}%',
                      style: GoogleFonts.inter(
                        color: Colors.blue[100],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${total.toInt()} Total',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Custom Bar Chart
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Subject-wise Analysis',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.blueGrey[900],
                  ),
                ),
                const SizedBox(height: 20),
                ...subjectData.map((sub) => _buildStatBar(sub['name'], (sub['marks'] as num).toDouble())),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBar(String label, double score) {
    // Determine color based on score
    Color color;
    if (score >= 90) color = const Color(0xFF10B981); // Emerald
    else if (score >= 75) color = const Color(0xFF3B82F6); // Blue
    else if (score >= 50) color = const Color(0xFFF59E0B); // Amber
    else color = const Color(0xFFEF4444); // Red

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.blueGrey[800],
                ),
              ),
              Text(
                '${score.toInt()}/100',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Stack(
            children: [
              Container(
                height: 10,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    height: 10,
                    width: constraints.maxWidth * (score / 100),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color.withOpacity(0.7), color],
                      ),
                      borderRadius: BorderRadius.circular(5),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ],
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

  void _sendAbsenceNotification() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final mobileNumber = widget.student.parentMobile;
    if (mobileNumber.isEmpty) {
      scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Parent mobile number is not available.'), backgroundColor: Colors.red));
      return;
    }

    final currentDate = DateFormat('dd-MM-yyyy').format(DateTime.now());
    final message = "your ward is abscent for school on '$currentDate' thanks from Nalanda school";

    final success = await SupabaseService.sendSms(mobileNumber, message);

    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(success ? 'Absence notification sent successfully.' : 'Failed to send SMS.'),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }
}

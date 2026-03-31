import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:school_management/models/student.dart';
import 'package:school_management/services/supabase_service.dart';

class StaffStudentDetailsScreen extends StatefulWidget {
  final String staffName;

  const StaffStudentDetailsScreen({super.key, required this.staffName});

  @override
  State<StaffStudentDetailsScreen> createState() => _StaffStudentDetailsScreenState();
}

class _StaffStudentDetailsScreenState extends State<StaffStudentDetailsScreen> {
  bool _isLoading = true;
  List<String> _classes = [];
  String? _selectedClass;
  List<Student> _students = [];
  Map<String, List<Map<String, dynamic>>> _feesMap = {};

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isLoading = true);
    try {
      final classes = await SupabaseService.getClassesForStaff(widget.staffName);
      setState(() {
        _classes = classes;
        if (_classes.isNotEmpty) {
          _selectedClass = _classes.first;
        }
      });
      if (_selectedClass != null) {
        await _fetchStudentsForClass(_selectedClass!);
      }
    } catch (e) {
      print('Error fetching initial data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchStudentsForClass(String className) async {
    setState(() => _isLoading = true);
    try {
      final students = await SupabaseService.getStudentsByClass(className);
      final studentNames = students.map((s) => s.name).toList();
      Map<String, List<Map<String, dynamic>>> feesMap = {};
      if (studentNames.isNotEmpty) {
        feesMap = await SupabaseService.getFeesForStudents(studentNames);
      }
      setState(() {
        _students = students;
        _feesMap = feesMap;
      });
    } catch (e) {
      print('Error fetching students: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  double _calculateTotalPaid(String studentName) {
    final fees = _feesMap[studentName] ?? [];
    double total = 0.0;
    for (final fee in fees) {
      total += double.tryParse(fee['AMOUNT']?.toString() ?? '0') ?? 0.0;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Student Details',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue[800],
        elevation: 2,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue[50]!, Colors.cyan[50]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: _isLoading && _classes.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _classes.isEmpty
                ? Center(
                    child: Text(
                      'No classes assigned to you.',
                      style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[700]),
                    ),
                  )
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: DropdownButtonFormField<String>(
                          value: _selectedClass,
                          decoration: InputDecoration(
                            labelText: 'Select Class',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items: _classes.map((c) {
                            return DropdownMenuItem(value: c, child: Text(c));
                          }).toList(),
                          onChanged: (value) {
                            if (value != null && value != _selectedClass) {
                              setState(() {
                                _selectedClass = value;
                              });
                              _fetchStudentsForClass(value);
                            }
                          },
                        ),
                      ),
                      Expanded(
                        child: _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : _students.isEmpty
                                ? Center(
                                    child: Text(
                                      'No students found in $_selectedClass',
                                      style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[700]),
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    itemCount: _students.length,
                                    itemBuilder: (context, index) {
                                      final student = _students[index];
                                      final totalPaid = _calculateTotalPaid(student.name);
                                      return Card(
                                        elevation: 2,
                                        margin: const EdgeInsets.only(bottom: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: ExpansionTile(
                                          leading: CircleAvatar(
                                            backgroundColor: Colors.blue[100],
                                            child: Text(
                                              student.name.isNotEmpty
                                                  ? student.name.substring(0, 1).toUpperCase()
                                                  : '?',
                                              style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          title: Text(
                                            student.name,
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          subtitle: Text(
                                            'Total Paid: ₹${totalPaid.toStringAsFixed(2)}',
                                            style: GoogleFonts.inter(
                                              color: Colors.green[700],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(16),
                                              color: Colors.grey[50],
                                              width: double.infinity,
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text('Contact Details', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.blue[900])),
                                                  const SizedBox(height: 8),
                                                  Text('Father Name: ${student.fatherName}', style: GoogleFonts.inter(fontSize: 13)),
                                                  Text('Mother Name: ${student.motherName}', style: GoogleFonts.inter(fontSize: 13)),
                                                  Text('Parent Mobile: ${student.parentMobile}', style: GoogleFonts.inter(fontSize: 13)),
                                                  const Divider(),
                                                  Text('Fee Structure', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.blue[900])),
                                                  const SizedBox(height: 8),
                                                  Text('School Concession: ₹${student.schoolFeeConcession.toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 13)),
                                                  Text('Bus Concession: ₹${student.busFeeConcession.toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 13)),
                                                  const Divider(),
                                                  Text('Fee Payments', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.blue[900])),
                                                  const SizedBox(height: 8),
                                                  ...(_feesMap[student.name] ?? []).map((fee) {
                                                    return Padding(
                                                      padding: const EdgeInsets.only(bottom: 8.0),
                                                      child: Row(
                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                        children: [
                                                          Expanded(
                                                            child: Column(
                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                              children: [
                                                                Text(fee['FEE TYPE']?.toString() ?? 'Unknown Fee', style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13)),
                                                                Text('${fee['TERM MONTH'] ?? ''} - ${fee['TERM YEAR'] ?? ''}', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[600])),
                                                              ],
                                                            ),
                                                          ),
                                                          Text(
                                                            '₹${double.tryParse(fee['AMOUNT']?.toString() ?? '0')?.toStringAsFixed(2) ?? '0.00'}',
                                                            style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.green[700]),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  }).toList(),
                                                  if ((_feesMap[student.name] ?? []).isEmpty)
                                                    Text('No fee records found.', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600])),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

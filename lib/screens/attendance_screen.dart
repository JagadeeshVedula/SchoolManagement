import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:school_management/services/supabase_service.dart';
import 'package:school_management/models/student.dart';

class AttendanceScreen extends StatefulWidget {
  final String staffName;

  const AttendanceScreen({super.key, required this.staffName});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  List<String> _classes = [];
  String? _selectedClass;
  DateTime _selectedDate = DateTime.now();
  List<Student> _students = [];
  Map<String, String> _attendanceMap = {}; // Student Name -> Status (Present/Absent)

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
        await _fetchStudentsAndAttendance();
      }
    } catch (e) {
      print('Error fetching initial data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchStudentsAndAttendance() async {
    if (_selectedClass == null) return;

    setState(() => _isLoading = true);
    try {
      final dateStr = DateFormat('dd-MM-yyyy').format(_selectedDate);
      
      // Fetch students and existing attendance in parallel
      final results = await Future.wait([
        SupabaseService.getStudentsByClass(_selectedClass!),
        SupabaseService.getAttendance(_selectedClass!, dateStr),
      ]);

      final students = results[0] as List<Student>;
      final existingAttendance = results[1] as List<Map<String, dynamic>>;

      // Create a map from existing attendance
      final Map<String, String> existingMap = {};
      for (var record in existingAttendance) {
        existingMap[record['STUDENT_NAME']] = record['STATUS'];
      }

      setState(() {
        _students = students;
        _attendanceMap = {};
        for (var student in _students) {
          // Default to "Present" if no record exists
          _attendanceMap[student.name] = existingMap[student.name] ?? 'Present';
        }
      });
    } catch (e) {
      print('Error fetching students/attendance: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAttendance() async {
    if (_selectedClass == null || _students.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final dateStr = DateFormat('dd-MM-yyyy').format(_selectedDate);
      final List<Map<String, dynamic>> attendanceData = [];

      for (var student in _students) {
        attendanceData.add({
          'STUDENT_NAME': student.name,
          'CLASS': _selectedClass,
          'DATE': dateStr,
          'STATUS': _attendanceMap[student.name] ?? 'Present',
          'STAFF': widget.staffName,
        });
      }

      final success = await SupabaseService.saveAttendance(attendanceData);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Attendance saved successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to save attendance'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error saving attendance: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue[800]!,
              onPrimary: Colors.white,
              onSurface: Colors.blue[900]!,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _fetchStudentsAndAttendance();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Student Attendance',
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
        child: Column(
          children: [
            // Filters Section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        value: _selectedClass,
                        decoration: InputDecoration(
                          labelText: 'Select Class',
                          prefixIcon: const Icon(Icons.class_, color: Colors.blue),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: _classes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedClass = value);
                            _fetchStudentsAndAttendance();
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: () => _selectDate(context),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Date',
                            prefixIcon: const Icon(Icons.calendar_today, color: Colors.blue),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            DateFormat('dd-MM-yyyy').format(_selectedDate),
                            style: GoogleFonts.poppins(fontSize: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Students List
            Expanded(
              child: _isLoading && _students.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _classes.isEmpty
                      ? Center(
                          child: Text(
                            'No classes assigned to you.',
                            style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[700]),
                          ),
                        )
                      : Stack(
                          children: [
                            ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                              itemCount: _students.length,
                              itemBuilder: (context, index) {
                                final student = _students[index];
                                final status = _attendanceMap[student.name] ?? 'Present';

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 2,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                student.name,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.blue[900],
                                                ),
                                              ),
                                              Text(
                                                'Parent: ${student.fatherName}',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            _buildAttendanceRadio(student.name, 'Present', Colors.green),
                                            const SizedBox(width: 8),
                                            _buildAttendanceRadio(student.name, 'Absent', Colors.red),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                            if (_isLoading)
                              Container(
                                color: Colors.black.withOpacity(0.1),
                                child: const Center(child: CircularProgressIndicator()),
                              ),
                          ],
                        ),
            ),
          ],
        ),
      ),
      bottomSheet: _students.isEmpty
          ? null
          : Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveAttendance,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[800],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'Save Attendance',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
    );
  }

  Widget _buildAttendanceRadio(String studentName, String status, Color color) {
    bool isSelected = _attendanceMap[studentName] == status;
    return GestureDetector(
      onTap: () {
        setState(() {
          _attendanceMap[studentName] = status;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? color : Colors.transparent,
                border: Border.all(color: Colors.grey[400]!),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              status,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? color : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:school_management/models/student.dart';
import 'package:school_management/services/supabase_service.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  Map<String, List<String>> _classesAndSections = {};
  String? _selectedClass;
  String? _selectedSection;
  String? _classTeacher;
  bool _isLoadingDropdowns = true;

  List<Student> _students = [];
  bool _isLoadingStudents = false;

  // Set of student IDs who are marked ABSENT
  Set<int> _absentStudentIds = {};
  bool _isSubmitting = false;

  bool _isHoliday = false;
  final TextEditingController _holidayReasonController = TextEditingController();
  bool _isSavingHoliday = false;

  @override
  void initState() {
    super.initState();
    _loadClassesAndSections();
  }

  Future<void> _loadClassesAndSections() async {
    setState(() {
      _isLoadingDropdowns = true;
    });
    try {
      final data = await SupabaseService.getUniqueClassesAndSections();
      setState(() {
        _classesAndSections = data;
        _isLoadingDropdowns = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading classes: $e')),
        );
      }
      setState(() {
        _isLoadingDropdowns = false;
      });
    }
  }

  Future<void> _onClassOrSectionChanged() async {
    _classTeacher = null;
    _students = [];
    _absentStudentIds.clear();
    
    if (_selectedClass != null && _selectedSection != null) {
      final className = '$_selectedClass-$_selectedSection';
      final teacher = await SupabaseService.getClassTeacher(className);
      setState(() {
        _classTeacher = teacher;
      });
    } else {
      setState(() {});
    }
  }

  Future<void> _showStudents() async {
    if (_selectedClass == null || _selectedSection == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both class and section.')),
      );
      return;
    }

    setState(() {
      _isLoadingStudents = true;
      _students = [];
      _absentStudentIds.clear();
    });

    try {
      final className = '$_selectedClass-$_selectedSection';
      final students = await SupabaseService.getStudentsByClass(className);
      setState(() {
        _students = students;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading students: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingStudents = false;
        });
      }
    }
  }

  Future<void> _submitAttendance() async {
    if (_students.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Attendance'),
        content: Text('Submit attendance for ${_students.length} students? Individuals checked will be marked ABSENT, others PRESENT.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Submit')),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSubmitting = true);

    try {
      final today = DateFormat('dd-MM-yyyy').format(DateTime.now());
      final className = '$_selectedClass-$_selectedSection';
      
      final List<Map<String, dynamic>> attendanceData = _students.map((s) {
        return {
          'STUDENT_NAME': s.name,
          'CLASS': className,
          'DATE': today,
          'STATUS': _absentStudentIds.contains(s.id) ? 'A' : 'P',
        };
      }).toList();

      final success = await SupabaseService.batchMarkAttendance(attendanceData);

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Attendance submitted successfully!'), backgroundColor: Colors.green),
          );
        }
        
        // Optionally send SMS to absentees
        if (_absentStudentIds.isNotEmpty) {
           _promptSms();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to submit attendance.'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      print('Error submitting attendance: $e');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _submitHoliday() async {
    if (_holidayReasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a reason for the holiday.')),
      );
      return;
    }

    setState(() => _isSavingHoliday = true);

    try {
      final today = DateFormat('dd-MM-yyyy').format(DateTime.now());
      final success = await SupabaseService.saveHoliday(today, _holidayReasonController.text.trim());

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Holiday marked successfully!'), backgroundColor: Colors.green),
          );
          _holidayReasonController.clear();
          setState(() {
            _isHoliday = false;
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to mark holiday.'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      print('Error saving holiday: $e');
    } finally {
      if (mounted) {
        setState(() => _isSavingHoliday = false);
      }
    }
  }

  Future<void> _promptSms() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send SMS?'),
        content: Text('Attendance marked. Would you like to send absence notifications to masks parents of ${_absentStudentIds.length} students?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes, Send SMS')),
        ],
      ),
    );

    if (confirm == true) {
      _sendAbsentMessages();
    }
  }

  Future<void> _sendAbsentMessages() async {
    final absentees = _students.where((s) => _absentStudentIds.contains(s.id)).toList();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    int successCount = 0;
    int failureCount = 0;
    final todayStr = DateFormat('dd-MM-yyyy').format(DateTime.now());

    for (var student in absentees) {
      final message = 'Dear parent, your child ${student.name} is marked ABSENT today ($todayStr). - NALANDA';
      final success = await SupabaseService.sendSms(student.parentMobile, message);
      if (success) successCount++; else failureCount++;
    }

    if (mounted) {
      Navigator.pop(context); // Hide loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('SMS Sent: $successCount, Failed: $failureCount'),
          backgroundColor: failureCount > 0 ? Colors.orange : Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Attendance', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white)),
        backgroundColor: Colors.indigo,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoadingDropdowns
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Class',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          value: _selectedClass,
                          items: _classesAndSections.keys.map((c) {
                            return DropdownMenuItem(value: c, child: Text(c));
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedClass = val;
                              _selectedSection = null; 
                            });
                            _onClassOrSectionChanged();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Section',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          value: _selectedSection,
                          items: (_selectedClass != null && _classesAndSections.containsKey(_selectedClass))
                              ? _classesAndSections[_selectedClass]!.map((s) {
                                  return DropdownMenuItem(value: s, child: Text(s));
                                }).toList()
                              : [],
                          onChanged: _selectedClass == null
                              ? null
                              : (val) {
                                  setState(() {
                                    _selectedSection = val;
                                  });
                                  _onClassOrSectionChanged();
                                },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_classTeacher != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.indigo.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person, color: Colors.indigo),
                          const SizedBox(width: 12),
                          Text(
                            'Class Teacher: $_classTeacher',
                            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _showStudents,
                    icon: const Icon(Icons.people_outline),
                    label: const Text('Fetch Student List'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(
                        value: _isHoliday,
                        onChanged: (val) {
                          setState(() {
                            _isHoliday = val ?? false;
                          });
                        },
                      ),
                      Text(
                        'Mark Today as Holiday',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  if (_isHoliday) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: _holidayReasonController,
                      decoration: const InputDecoration(
                        labelText: 'Holiday Reason',
                        border: OutlineInputBorder(),
                        hintText: 'e.g., Summer Vacation, Public Holiday',
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _isSavingHoliday ? null : _submitHoliday,
                      icon: _isSavingHoliday 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                          : const Icon(Icons.beach_access),
                      label: Text(_isSavingHoliday ? 'Saving...' : 'Save Holiday'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Expanded(
                    child: _isLoadingStudents
                        ? const Center(child: CircularProgressIndicator())
                        : _students.isEmpty
                            ? Center(
                                child: Text(
                                  _selectedClass == null || _selectedSection == null
                                      ? 'Select class and section to view students.'
                                      : 'No students found.',
                                  style: GoogleFonts.poppins(color: Colors.grey),
                                ),
                              )
                            : Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Mark absentees (checking means absent):',
                                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey[700]),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            setState(() {
                                              if (_absentStudentIds.length == _students.length) {
                                                _absentStudentIds.clear();
                                              } else {
                                                _absentStudentIds = _students.map((s) => s.id!).toSet();
                                              }
                                            });
                                          },
                                          child: Text(_absentStudentIds.length == _students.length ? 'Unselect All' : 'Select All'),
                                        )
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: ListView.builder(
                                      itemCount: _students.length,
                                      itemBuilder: (context, index) {
                                        final student = _students[index];
                                        final isAbsent = _absentStudentIds.contains(student.id);
                                        return Card(
                                          elevation: 0,
                                          margin: const EdgeInsets.only(bottom: 8),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            side: BorderSide(color: isAbsent ? Colors.red.withOpacity(0.3) : Colors.grey.withOpacity(0.2)),
                                          ),
                                          color: isAbsent ? Colors.red.withOpacity(0.02) : Colors.white,
                                          child: CheckboxListTile(
                                            title: Text(student.name, style: GoogleFonts.poppins(fontWeight: FontWeight.w500, color: isAbsent ? Colors.red : Colors.black87)),
                                            value: isAbsent,
                                            activeColor: Colors.red,
                                            onChanged: (bool? value) {
                                              setState(() {
                                                if (value == true && student.id != null) {
                                                  _absentStudentIds.add(student.id!);
                                                } else {
                                                  _absentStudentIds.remove(student.id);
                                                }
                                              });
                                            },
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                  ),
                  const SizedBox(height: 16),
                  if (_students.isNotEmpty)
                    ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _submitAttendance,
                      icon: _isSubmitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.check_circle_outline),
                      label: Text(_isSubmitting ? 'Submitting...' : 'Submit Attendance'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

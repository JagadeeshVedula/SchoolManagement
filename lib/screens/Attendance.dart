import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

  // Set of student IDs (or names) who are selected to receive the absent message
  Set<int> _selectedStudentIds = {};

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
    _selectedStudentIds.clear();
    
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
      _selectedStudentIds.clear();
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

  Future<void> _sendAbsentMessages() async {
    if (_selectedStudentIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No students selected.')),
      );
      return;
    }

    final selectedStudents = _students.where((s) => _selectedStudentIds.contains(s.id)).toList();
    
    // Show a confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm'),
          content: Text('Are you sure you want to send absent messages to the parents of ${selectedStudents.length} student(s)?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Send'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    int successCount = 0;
    int failureCount = 0;

    for (var student in selectedStudents) {
      final message = 'Dear parent, your child ${student.name} is marked absent today. - NALANDA';
      final success = await SupabaseService.sendSms(student.parentMobile, message);
      if (success) {
        successCount++;
      } else {
        failureCount++;
      }
    }

    if (mounted) {
      // Hide loading
      Navigator.pop(context);

      // Show result
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Messages sent: $successCount, Failed: $failureCount'),
          backgroundColor: failureCount > 0 ? Colors.orange : Colors.green,
        ),
      );
      
      // Optionally deselect
      setState(() {
        _selectedStudentIds.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Attendance', style: GoogleFonts.poppins()),
        backgroundColor: Colors.indigo,
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
                          ),
                          value: _selectedClass,
                          items: _classesAndSections.keys.map((c) {
                            return DropdownMenuItem(value: c, child: Text(c));
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedClass = val;
                              _selectedSection = null; // Reset section
                            });
                            _onClassOrSectionChanged();
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Section',
                            border: OutlineInputBorder(),
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
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            const Icon(Icons.person, color: Colors.indigo),
                            const SizedBox(width: 8),
                            Text(
                              'Class Teacher: $_classTeacher',
                              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _showStudents,
                    icon: const Icon(Icons.list),
                    label: const Text('Show Students'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
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
                            : ListView.builder(
                                itemCount: _students.length,
                                itemBuilder: (context, index) {
                                  final student = _students[index];
                                  final isSelected = _selectedStudentIds.contains(student.id);
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: CheckboxListTile(
                                      title: Text(student.name, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                                      subtitle: Text('Parent Mobile: ${student.parentMobile}'),
                                      value: isSelected,
                                      onChanged: (bool? value) {
                                        setState(() {
                                          if (value == true && student.id != null) {
                                            _selectedStudentIds.add(student.id!);
                                          } else {
                                            _selectedStudentIds.remove(student.id);
                                          }
                                        });
                                      },
                                    ),
                                  );
                                },
                              ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _students.isEmpty ? null : _sendAbsentMessages,
                    icon: const Icon(Icons.message),
                    label: const Text('Send Absent Message Option'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

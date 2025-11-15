import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:school_management/services/supabase_service.dart';
import 'package:school_management/models/student.dart';

class RegisterTab extends StatefulWidget {
  final String? role;

  const RegisterTab({super.key, this.role = 'admin'});

  @override
  State<RegisterTab> createState() => _RegisterTabState();
}

class _RegisterTabState extends State<RegisterTab> {
  // Student registration controllers (kept for now, can be refactored)
  final _sName = TextEditingController();
  final _sClass = TextEditingController();
  final _sFather = TextEditingController();
  final _sMother = TextEditingController();
  final _sParentMobile = TextEditingController();

  // Performance controllers
  final _perfAssessment = TextEditingController();
  final _perfSubject = TextEditingController();
  final _perfMarks = TextEditingController();
  final _perfGrade = TextEditingController();
  final _perfRemarks = TextEditingController();

  // Staff controllers
  final _staffName = TextEditingController();
  final _staffQualification = TextEditingController();
  final _staffMobile = TextEditingController();
  final _staffUsername = TextEditingController();
  final _staffPassword = TextEditingController();

  // Parent login controllers
  final _parentUsername = TextEditingController();
  final _parentPassword = TextEditingController();
  final _parentMobile = TextEditingController();

  late Future<List<Student>> _studentsFuture;

  @override
  void initState() {
    super.initState();
    _studentsFuture = SupabaseService.getAllStudents();
  }

  @override
  void dispose() {
    _sName.dispose();
    _sClass.dispose();
    _sFather.dispose();
    _sMother.dispose();
    _sParentMobile.dispose();
    _perfAssessment.dispose();
    _perfSubject.dispose();
    _perfMarks.dispose();
    _perfGrade.dispose();
    _perfRemarks.dispose();
    _staffName.dispose();
    _staffQualification.dispose();
    _staffMobile.dispose();
    _staffUsername.dispose();
    _staffPassword.dispose();
    _parentUsername.dispose();
    _parentPassword.dispose();
    _parentMobile.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.role == 'admin';

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Registration & Management',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A1D21),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // Register Student Button
              _buildMainButton(
                label: 'Register Student',
                icon: Icons.person_add,
                color: const Color(0xFF6366F1),
                onPressed: () => _showRegisterStudentDialog(context),
              ),
              const SizedBox(height: 16),
              // Register Staff Button (only for admin)
              if (isAdmin)
                _buildMainButton(
                  label: 'Register Staff',
                  icon: Icons.group_add,
                  color: const Color(0xFF8B5CF6),
                  onPressed: () => _showRegisterStaffDialog(context),
                ),
              if (isAdmin) const SizedBox(height: 16),
              // Update Performance Button
              _buildMainButton(
                label: 'Update Performance',
                icon: Icons.assessment,
                color: const Color(0xFF10B981),
                onPressed: () => _showUpdatePerformanceDialog(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 24),
      label: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 2,
      ),
    );
  }

  void _showRegisterStudentDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final classCtrl = TextEditingController();
    final fatherCtrl = TextEditingController();
    final motherCtrl = TextEditingController();
    final mobileCtrl = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setState) {
            return SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
                top: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Register Student',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Student Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: classCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Class',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: fatherCtrl,
                    decoration: const InputDecoration(
                      labelText: "Father's Name",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: motherCtrl,
                    decoration: const InputDecoration(
                      labelText: "Mother's Name",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: mobileCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Parent Mobile Number',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              if (nameCtrl.text.trim().isEmpty ||
                                  classCtrl.text.trim().isEmpty) {
                                ScaffoldMessenger.of(sheetContext).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Please enter student name and class'),
                                  ),
                                );
                                return;
                              }
                              setState(() => isSubmitting = true);
                              final data = {
                                'Name': nameCtrl.text.trim(),
                                'Class': classCtrl.text.trim(),
                                'Father Name': fatherCtrl.text.trim(),
                                'Mother Name': motherCtrl.text.trim(),
                                'Parent Mobile': mobileCtrl.text.trim(),
                              };
                              final ok = await SupabaseService.insertStudent(data);
                              setState(() => isSubmitting = false);
                              if (ok) {
                                ScaffoldMessenger.of(sheetContext).showSnackBar(
                                  const SnackBar(
                                    content: Text('Student registered successfully'),
                                  ),
                                );
                                Navigator.pop(sheetContext);
                                setState(() {
                                  _studentsFuture =
                                      SupabaseService.getAllStudents();
                                });
                              } else {
                                ScaffoldMessenger.of(sheetContext).showSnackBar(
                                  const SnackBar(
                                    content: Text('Failed to register student'),
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : const Text('Register Student'),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showRegisterStaffDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final qualCtrl = TextEditingController();
    final mobileCtrl = TextEditingController();
    final usernameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setState) {
            return SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
                top: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Register Staff',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Staff Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: qualCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Qualification',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: mobileCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Mobile Number',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: usernameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              if (nameCtrl.text.trim().isEmpty ||
                                  mobileCtrl.text.trim().isEmpty ||
                                  usernameCtrl.text.trim().isEmpty ||
                                  passwordCtrl.text.trim().isEmpty) {
                                ScaffoldMessenger.of(sheetContext).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Please fill all required fields'),
                                  ),
                                );
                                return;
                              }
                              setState(() => isSubmitting = true);

                              final staffData = {
                                'Name': nameCtrl.text.trim(),
                                'Qualification': qualCtrl.text.trim(),
                                'Mobile': mobileCtrl.text.trim(),
                              };
                              final staffOk =
                                  await SupabaseService.insertStaff(staffData);

                              if (!staffOk) {
                                setState(() => isSubmitting = false);
                                ScaffoldMessenger.of(sheetContext).showSnackBar(
                                  const SnackBar(
                                    content: Text('Failed to register staff'),
                                  ),
                                );
                                return;
                              }

                              final credOk = await SupabaseService
                                  .insertOrUpdateCredentials(
                                usernameCtrl.text.trim(),
                                passwordCtrl.text.trim(),
                                mobileNumber: mobileCtrl.text.trim(),
                                role: 'STAFF',
                              );

                              setState(() => isSubmitting = false);

                              if (credOk) {
                                ScaffoldMessenger.of(sheetContext).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Staff registered with credentials'),
                                  ),
                                );
                                Navigator.pop(sheetContext);
                              } else {
                                ScaffoldMessenger.of(sheetContext).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Failed to save credentials'),
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : const Text('Register Staff'),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showUpdatePerformanceDialog(BuildContext context) {
    String? selectedStudent;
    final assessmentCtrl = TextEditingController();
    final subjectCtrl = TextEditingController();
    final marksCtrl = TextEditingController();
    final gradeCtrl = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setState) {
            return SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
                top: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Update Performance',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<List<Student>>(
                    future: _studentsFuture,
                    builder: (sheetContext, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const CircularProgressIndicator();
                      }
                      final students = snap.data ?? [];
                      return DropdownButtonFormField<String>(
                        value: selectedStudent,
                        items: students
                            .map(
                              (s) => DropdownMenuItem(
                                value: s.name,
                                child: Text(s.name),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => selectedStudent = v),
                        decoration: const InputDecoration(
                          labelText: 'Select Student',
                          border: OutlineInputBorder(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: assessmentCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Assessment',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: subjectCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Subject Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: marksCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Marks',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: gradeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Grade',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              if (selectedStudent == null ||
                                  subjectCtrl.text.trim().isEmpty) {
                                ScaffoldMessenger.of(sheetContext).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Please select student and enter subject'),
                                  ),
                                );
                                return;
                              }
                              setState(() => isSubmitting = true);
                              final data = {
                                'Student Name': selectedStudent!,
                                'Assessment': assessmentCtrl.text.trim(),
                                'Subject name': subjectCtrl.text.trim(),
                                'Marks': marksCtrl.text.trim(),
                                'Grade': gradeCtrl.text.trim(),
                              };
                              final ok = await SupabaseService
                                  .insertPerformance(data);
                              setState(() => isSubmitting = false);
                              if (ok) {
                                ScaffoldMessenger.of(sheetContext).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Performance record added successfully'),
                                  ),
                                );
                                Navigator.pop(sheetContext);
                              } else {
                                ScaffoldMessenger.of(sheetContext).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Failed to add performance record'),
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : const Text('Update Performance'),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:school_management/services/supabase_service.dart';
import 'package:school_management/models/student.dart';

class RegisterTab extends StatefulWidget {
  const RegisterTab({super.key});

  @override
  State<RegisterTab> createState() => _RegisterTabState();
}

class _RegisterTabState extends State<RegisterTab> {
  // Student registration controllers
  final _sName = TextEditingController();
  final _sClass = TextEditingController();
  final _sFather = TextEditingController();
  final _sMother = TextEditingController();
  final _sParentMobile = TextEditingController();

  // Performance controllers
  String? _perfStudent;
  final _perfAssessment = TextEditingController();
  final _perfSubject = TextEditingController();
  final _perfMarks = TextEditingController();
  final _perfGrade = TextEditingController();
  final _perfRemarks = TextEditingController();

  // Staff controllers
  final _staffName = TextEditingController();
  final _staffQualification = TextEditingController();
  final _staffMobile = TextEditingController();

  bool _isSubmittingStudent = false;
  bool _isSubmittingPerf = false;
  bool _isSubmittingStaff = false;

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
    super.dispose();
  }

  Future<void> _submitStudent() async {
    if (_sName.text.trim().isEmpty || _sClass.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter student name and class')));
      return;
    }
    setState(() => _isSubmittingStudent = true);
    final data = {
      'Name': _sName.text.trim(),
      'Class': _sClass.text.trim(),
      'Father Name': _sFather.text.trim(),
      'Mother Name': _sMother.text.trim(),
      'Parent Mobile': _sParentMobile.text.trim(),
    };
    final ok = await SupabaseService.insertStudent(data);
    setState(() => _isSubmittingStudent = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Student registered')));
      _sName.clear(); _sClass.clear(); _sFather.clear(); _sMother.clear(); _sParentMobile.clear();
      setState(() { _studentsFuture = SupabaseService.getAllStudents(); });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to register student')));
    }
  }

  Future<void> _submitPerformance() async {
    if (_perfStudent == null || _perfSubject.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a student and enter subject')));
      return;
    }
    setState(() => _isSubmittingPerf = true);
    final data = {
      'Student Name': _perfStudent!,
      'Assessment': _perfAssessment.text.trim(),
      'Subject name': _perfSubject.text.trim(),
      'Marks': _perfMarks.text.trim(),
      'Grade': _perfGrade.text.trim(),
      // 'Remarks': _perfRemarks.text.trim(),
    };
    final ok = await SupabaseService.insertPerformance(data);
    setState(() => _isSubmittingPerf = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Performance record added')));
      _perfAssessment.clear(); _perfSubject.clear(); _perfMarks.clear(); _perfGrade.clear(); _perfRemarks.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to add performance')));
    }
  }

  Future<void> _submitStaff() async {
    if (_staffName.text.trim().isEmpty || _staffMobile.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter staff name and mobile')));
      return;
    }
    setState(() => _isSubmittingStaff = true);
    final data = {
      'Name': _staffName.text.trim(),
      'Qualification': _staffQualification.text.trim(),
      'Mobile': _staffMobile.text.trim(),
    };
    final ok = await SupabaseService.insertStaff(data);
    setState(() => _isSubmittingStaff = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Staff registered')));
      _staffName.clear(); _staffQualification.clear(); _staffMobile.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to register staff')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Register Student', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(controller: _sName, decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 8),
          TextField(controller: _sClass, decoration: const InputDecoration(labelText: 'Class')),
          const SizedBox(height: 8),
          TextField(controller: _sFather, decoration: const InputDecoration(labelText: "Father's Name")),
          const SizedBox(height: 8),
          TextField(controller: _sMother, decoration: const InputDecoration(labelText: "Mother's Name")),
          const SizedBox(height: 8),
          TextField(controller: _sParentMobile, decoration: const InputDecoration(labelText: 'Parent Mobile'), keyboardType: TextInputType.phone),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmittingStudent ? null : _submitStudent,
              child: _isSubmittingStudent ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Register Student'),
            ),
          ),

          const Divider(height: 32),

          Text('Add Performance', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          FutureBuilder<List<Student>>(
            future: _studentsFuture,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) return const CircularProgressIndicator();
              final students = snap.data ?? [];
              return DropdownButtonFormField<String>(
                value: _perfStudent,
                items: students.map((s) => DropdownMenuItem(value: s.name, child: Text(s.name))).toList(),
                onChanged: (v) => setState(() => _perfStudent = v),
                decoration: const InputDecoration(labelText: 'Select Student'),
              );
            },
          ),
          const SizedBox(height: 8),
          TextField(controller: _perfAssessment, decoration: const InputDecoration(labelText: 'Assessment')),
          const SizedBox(height: 8),
          TextField(controller: _perfSubject, decoration: const InputDecoration(labelText: 'Subject Name')),
          const SizedBox(height: 8),
          TextField(controller: _perfMarks, decoration: const InputDecoration(labelText: 'Marks')), 
          const SizedBox(height: 8),
          TextField(controller: _perfGrade, decoration: const InputDecoration(labelText: 'Grade')),
          const SizedBox(height: 8),
          // TextField(controller: _perfRemarks, decoration: const InputDecoration(labelText: 'Remarks')),
          // const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmittingPerf ? null : _submitPerformance,
              child: _isSubmittingPerf ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Add Performance'),
            ),
          ),

          const Divider(height: 32),

          Text('Register Staff', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(controller: _staffName, decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 8),
          TextField(controller: _staffQualification, decoration: const InputDecoration(labelText: 'Qualification')),
          const SizedBox(height: 8),
          TextField(controller: _staffMobile, decoration: const InputDecoration(labelText: 'Mobile'), keyboardType: TextInputType.phone),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmittingStaff ? null : _submitStaff,
              child: _isSubmittingStaff ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Register Staff'),
            ),
          ),
        ],
      ),
    );
  }
}

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
  int _currentPage = 0; // 0: Menu, 1: Student, 2: Staff, 3: Performance, 4: Bus

  // Student registration controllers
  final _sName = TextEditingController();
  final _sClass = TextEditingController();
  final _sFather = TextEditingController();
  final _sMother = TextEditingController();
  final _sParentMobile = TextEditingController();
  String? _sGender;

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

  // Bus/Transport controllers
  final _busNumber = TextEditingController();
  final _busRoute = TextEditingController();
  final _busFees = TextEditingController();

  bool _isSubmittingStudent = false;
  bool _isSubmittingPerf = false;
  bool _isSubmittingStaff = false;
  bool _isSubmittingBus = false;

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
    _busNumber.dispose();
    _busRoute.dispose();
    _busFees.dispose();
    super.dispose();
  }

  Future<void> _submitStudent() async {
    if (_sName.text.trim().isEmpty || _sClass.text.trim().isEmpty || _sGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter student name, class, and gender')));
      return;
    }
    setState(() => _isSubmittingStudent = true);
    final data = {
      'Name': _sName.text.trim(),
      'Class': _sClass.text.trim(),
      'Father Name': _sFather.text.trim(),
      'Mother Name': _sMother.text.trim(),
      'Parent Mobile': _sParentMobile.text.trim(),
      'Gender': _sGender,
    };
    final ok = await SupabaseService.insertStudent(data);
    setState(() => _isSubmittingStudent = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Student registered successfully')));
      _sName.clear(); _sClass.clear(); _sFather.clear(); _sMother.clear(); _sParentMobile.clear();
      setState(() { _sGender = null; _studentsFuture = SupabaseService.getAllStudents(); _currentPage = 0; });
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
      'Subject Name': _perfSubject.text.trim(),
      'Marks': _perfMarks.text.trim(),
      'Grade': _perfGrade.text.trim(),
      'Remarks': _perfRemarks.text.trim(),
    };
    final ok = await SupabaseService.insertPerformance(data);
    setState(() => _isSubmittingPerf = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Performance record added successfully')));
      _perfAssessment.clear(); _perfSubject.clear(); _perfMarks.clear(); _perfGrade.clear(); _perfRemarks.clear();
      setState(() { _currentPage = 0; });
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Staff registered successfully')));
      _staffName.clear(); _staffQualification.clear(); _staffMobile.clear();
      setState(() { _currentPage = 0; });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to register staff')));
    }
  }

  Future<void> _submitBus() async {
    if (_busNumber.text.trim().isEmpty || _busRoute.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter bus number and route')));
      return;
    }
    setState(() => _isSubmittingBus = true);
    final data = {
      'BusNumber': _busNumber.text.trim(),
      'Route': _busRoute.text.trim(),
      'Fees': _busFees.text.trim(),
    };
    final ok = await SupabaseService.insertTransport(data);
    setState(() => _isSubmittingBus = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bus registered successfully')));
      _busNumber.clear(); _busRoute.clear(); _busFees.clear();
      setState(() { _currentPage = 0; });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to register bus')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentPage == 0) {
      // Menu page with 4 buttons
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Registration Menu',
                style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              _buildMenuButton(
                icon: Icons.school,
                title: 'Register Student',
                onPressed: () => setState(() => _currentPage = 1),
              ),
              const SizedBox(height: 16),
              _buildMenuButton(
                icon: Icons.people,
                title: 'Register Staff',
                onPressed: () => setState(() => _currentPage = 2),
              ),
              const SizedBox(height: 16),
              _buildMenuButton(
                icon: Icons.bar_chart,
                title: 'Add Performance',
                onPressed: () => setState(() => _currentPage = 3),
              ),
              const SizedBox(height: 16),
              _buildMenuButton(
                icon: Icons.directions_bus,
                title: 'Register Bus',
                onPressed: () => setState(() => _currentPage = 4),
              ),
            ],
          ),
        ),
      );
    } else if (_currentPage == 1) {
      // Register Student page
      return _buildStudentRegistrationPage();
    } else if (_currentPage == 2) {
      // Register Staff page
      return _buildStaffRegistrationPage();
    } else if (_currentPage == 3) {
      // Add Performance page
      return _buildPerformancePage();
    } else {
      // Register Bus page
      return _buildBusRegistrationPage();
    }
  }

  Widget _buildMenuButton({required IconData icon, required String title, required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      height: 120,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 4,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Colors.white),
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentRegistrationPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildBackButton(),
          const SizedBox(height: 16),
          Text('Register Student', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          TextField(controller: _sName, decoration: const InputDecoration(labelText: 'Student Name', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _sClass, decoration: const InputDecoration(labelText: 'Class', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _sFather, decoration: const InputDecoration(labelText: "Father's Name", border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _sMother, decoration: const InputDecoration(labelText: "Mother's Name", border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _sParentMobile, decoration: const InputDecoration(labelText: 'Parent Mobile', border: OutlineInputBorder()), keyboardType: TextInputType.phone),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _sGender,
            items: const [DropdownMenuItem(value: 'Male', child: Text('Male')), DropdownMenuItem(value: 'Female', child: Text('Female'))],
            onChanged: (v) => setState(() => _sGender = v),
            decoration: const InputDecoration(labelText: 'Gender', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isSubmittingStudent ? null : _submitStudent,
              child: _isSubmittingStudent ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Register Student'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffRegistrationPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildBackButton(),
          const SizedBox(height: 16),
          Text('Register Staff', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          TextField(controller: _staffName, decoration: const InputDecoration(labelText: 'Staff Name', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _staffQualification, decoration: const InputDecoration(labelText: 'Qualification', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _staffMobile, decoration: const InputDecoration(labelText: 'Mobile', border: OutlineInputBorder()), keyboardType: TextInputType.phone),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isSubmittingStaff ? null : _submitStaff,
              child: _isSubmittingStaff ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Register Staff'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformancePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildBackButton(),
          const SizedBox(height: 16),
          Text('Add Performance', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          FutureBuilder<List<Student>>(
            future: _studentsFuture,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) return const CircularProgressIndicator();
              final students = snap.data ?? [];
              return DropdownButtonFormField<String>(
                value: _perfStudent,
                items: students.map((s) => DropdownMenuItem(value: s.name, child: Text(s.name))).toList(),
                onChanged: (v) => setState(() => _perfStudent = v),
                decoration: const InputDecoration(labelText: 'Select Student', border: OutlineInputBorder()),
              );
            },
          ),
          const SizedBox(height: 12),
          TextField(controller: _perfAssessment, decoration: const InputDecoration(labelText: 'Assessment', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _perfSubject, decoration: const InputDecoration(labelText: 'Subject Name', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _perfMarks, decoration: const InputDecoration(labelText: 'Marks', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _perfGrade, decoration: const InputDecoration(labelText: 'Grade', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _perfRemarks, decoration: const InputDecoration(labelText: 'Remarks', border: OutlineInputBorder())),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isSubmittingPerf ? null : _submitPerformance,
              child: _isSubmittingPerf ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Add Performance'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusRegistrationPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildBackButton(),
          const SizedBox(height: 16),
          Text('Register Bus', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          TextField(controller: _busNumber, decoration: const InputDecoration(labelText: 'Bus Number', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _busRoute, decoration: const InputDecoration(labelText: 'Route', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _busFees, decoration: const InputDecoration(labelText: 'Fees', border: OutlineInputBorder()), keyboardType: TextInputType.number),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isSubmittingBus ? null : _submitBus,
              child: _isSubmittingBus ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Register Bus'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackButton() {
    return Align(
      alignment: Alignment.topLeft,
      child: ElevatedButton.icon(
        onPressed: () => setState(() => _currentPage = 0),
        icon: const Icon(Icons.arrow_back),
        label: const Text('Back'),
      ),
    );
  }
}

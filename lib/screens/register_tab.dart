import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:school_management/services/supabase_service.dart';
import 'package:school_management/models/student.dart';
import 'package:intl/intl.dart';

class RegisterTab extends StatefulWidget {
  const RegisterTab({super.key});

  @override
  State<RegisterTab> createState() => _RegisterTabState();
}

class _RegisterTabState extends State<RegisterTab> {
  int _currentPage = 0; // 0: Menu, 1: Student, 2: Staff, 3: Performance, 4: Bus

  // Student registration controllers
  final _sName = TextEditingController();
  String? _sClass;
  String? _sSection;
  List<String> _sections = [];
  final _sFather = TextEditingController();
  final _sMother = TextEditingController();
  final _sParentMobile = TextEditingController();
  final _sAddress = TextEditingController();
  String? _sGender;
  bool _sBusFacility = false;
  String? _sBusRoute;
  String? _sBusNo;
  bool _sHostelFacility = false;
  DateTime? _selectedJoiningDate;
  double _sHostelFee = 0;

  // Performance controllers
  String? _perfClass;
  String? _perfSection;
  Student? _perfStudent;
  List<Student> _perfStudents = [];
  final _perfAssessment = TextEditingController();
  final _perfSubject = TextEditingController();
  final _perfMarks = TextEditingController();
  final _perfGrade = TextEditingController();
  final _perfRemarks = TextEditingController();
  
  // Subject marks controllers
  late Map<String, TextEditingController> _subjectMarksControllers;
  final List<String> _subjects = ['Telugu', 'English', 'Hindi', 'Maths', 'Science', 'Social', 'Computers'];

  // Staff controllers
  final _staffName = TextEditingController();
  final _staffQualification = TextEditingController();
  final _staffMobile = TextEditingController();
  final _staffSalary = TextEditingController();
  String? _staffType;

  // Bus/Transport controllers
  final _busNumber = TextEditingController();
  final _busRegNumber = TextEditingController();
  final _busRoute = TextEditingController();
  final _busFees = TextEditingController();

  bool _isSubmittingStudent = false;
  bool _isSubmittingPerf = false;
  bool _isSubmittingStaff = false;
  bool _isSubmittingBus = false;

  List<String> _classes = [];
  List<String> _busRoutes = [];
  List<String> _busNumbers = [];
  Map<String, double> _hostelFeesByClass = {};

  @override
  void initState() {
    super.initState();
    _subjectMarksControllers = {
      for (var subject in _subjects) subject: TextEditingController(),
    };
    _loadClasses();
    _loadBusRoutes();
    _loadHostelFees();
  }

  Future<void> _loadClasses() async {
    try {
      final classes = await SupabaseService.getClassesFromFeeStructure();
      final sections = List.generate(26, (i) => String.fromCharCode('A'.codeUnitAt(0) + i));
      if(mounted) {
        setState(() {
          _classes = classes..sort();
          _sections = sections;
        });
      }
    } catch (e) {
      print('Error loading classes: $e');
    }
  }

  Future<void> _loadBusRoutes() async {
    try {
      final routes = await SupabaseService.getBusRoutes();
      setState(() => _busRoutes = routes);
    } catch (e) {
      print('Error loading bus routes: $e');
    }
  }

  Future<void> _loadBusNumbersByRoute(String route) async {
    try {
      final busNumbers = await SupabaseService.getBusNumbersByRoute(route);
      setState(() {
        _busNumbers = busNumbers;
        _sBusNo = null; // Reset bus number selection when route changes
      });
    } catch (e) {
      print('Error loading bus numbers for route: $e');
    }
  }

  Future<void> _loadHostelFees() async {
    try {
      final fees = await SupabaseService.getHostelFees();
      print('DEBUG RegisterTab: Loaded hostel fees: $fees');
      setState(() => _hostelFeesByClass = fees);
    } catch (e) {
      print('Error loading hostel fees: $e');
    }
  }

  Future<void> _loadStudentsForClass(String className) async {
    final students = await SupabaseService.getStudentsByClass(className);
    setState(() => _perfStudents = students);
  }

  void _openStudentSearchDialog() {
    if (_perfClass == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a class first')),
      );
      return;
    }
    if (_perfStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No students found in this class')),
      );
      return;
    }

    final searchController = TextEditingController();
    final dialogContext = context;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSearchState) => Dialog(
          child: SizedBox(
            width: 400,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search student by name',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setSearchState(() {}),
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: ListView(
                      children: _perfStudents
                          .where((s) => s.name.toLowerCase().contains(searchController.text.toLowerCase()))
                          .map(
                            (s) => ListTile(
                              title: Text(s.name),
                              subtitle: Text('${s.className} - ${s.gender}'),
                              onTap: () {
                                setState(() => _perfStudent = s);
                                Navigator.pop(dialogContext);
                              },
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _sName.dispose();
    _sFather.dispose();
    _sMother.dispose();
    _sParentMobile.dispose();
    _sAddress.dispose();
    _perfAssessment.dispose();
    _perfSubject.dispose();
    _perfMarks.dispose();
    _perfGrade.dispose();
    _perfRemarks.dispose();
    for (var controller in _subjectMarksControllers.values) {
      controller.dispose();
    }
    _staffName.dispose();
    _staffQualification.dispose();
    _staffMobile.dispose();
    _staffSalary.dispose();
    _busNumber.dispose();
    _busRoute.dispose();
    _busFees.dispose();
    super.dispose();
  }

  Future<void> _submitStudent() async {
    if (_sName.text.trim().isEmpty || _sClass == null || _sSection == null || _sGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter student name, select class, section, and gender')));
      return;
    }
    if (_sBusFacility && _sBusRoute == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a bus route')));
      return;
    }
    if (_sBusFacility && _sBusNo == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a bus number')));
      return;
    }
    setState(() => _isSubmittingStudent = true);
    final data = {
      'Name': _sName.text.trim(),
      'Class': '$_sClass-$_sSection',
      'Father Name': _sFather.text.trim(),
      'Mother Name': _sMother.text.trim(),
      'Parent Mobile': _sParentMobile.text.trim(),
      'ADDRESS': _sAddress.text.trim(),
      'GENDER': _sGender,
      'Route': _sBusRoute,
      'BusNo': _sBusNo,
      'Bus Facility': _sBusFacility ? 'Yes' : null,
      'Hostel Facility': _sHostelFacility ? 'Yes' : null,
    };
    data['DOJ'] = _selectedJoiningDate != null ? DateFormat('dd-MM-yyyy').format(_selectedJoiningDate!) : null;
    final ok = await SupabaseService.insertStudent(data);
    setState(() => _isSubmittingStudent = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Student registered successfully')));
      _sName.clear(); _sFather.clear(); _sMother.clear(); _sParentMobile.clear(); _sAddress.clear();
      setState(() { 
        _sGender = null; 
        _sClass = null;
        _sSection = null;
        _sBusFacility = false;
        _sBusRoute = null;
        _sBusNo = null;
        _busNumbers = [];
        _sHostelFacility = false;
        _selectedJoiningDate = null;
        _sHostelFee = 0;
        _loadClasses(); 
        _currentPage = 0; 
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to register student')));
    }
  }

  Future<void> _submitPerformance() async {
    if (_perfStudent == null || _perfAssessment.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a student and enter assessment')));
      return;
    }

    // Collect all subjects with marks
    bool hasMarks = false;
    for (var subject in _subjects) {
      if (_subjectMarksControllers[subject]!.text.trim().isNotEmpty) {
        hasMarks = true;
        break;
      }
    }

    if (!hasMarks) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter marks for at least one subject')));
      return;
    }

    setState(() => _isSubmittingPerf = true);

    // Build data with all subjects and their marks
    final data = {
      'Student Name': _perfStudent!.name,
      'Assessment': _perfAssessment.text.trim(),
    };

    // Add subject columns and marks
    for (var subject in _subjects) {
      final marks = _subjectMarksControllers[subject]!.text.trim();
      if (marks.isNotEmpty) {
        data[subject] = 'Yes'; // Subject taken
        data['$subject Marks'] = marks; // Subject marks
      }
    }

    final ok = await SupabaseService.insertPerformance(data);
    setState(() => _isSubmittingPerf = false);
    
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Performance record added successfully')));
      _perfAssessment.clear();
      for (var controller in _subjectMarksControllers.values) {
        controller.clear();
      }
      setState(() { _perfStudent = null; _perfClass = null; _currentPage = 0; });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to add performance record')));
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
      'Salary': _staffSalary.text.trim(),
      'StaffType': _staffType,
    };
    final ok = await SupabaseService.insertStaff(data);
    setState(() => _isSubmittingStaff = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Staff registered successfully')));
      _staffName.clear(); _staffQualification.clear(); _staffMobile.clear(); _staffSalary.clear();
      setState(() { _staffType = null; _currentPage = 0; });
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
      'BusReg': _busRegNumber.text.trim(),
    };
    final ok = await SupabaseService.insertTransport(data);
    setState(() => _isSubmittingBus = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bus registered successfully')));
      _busNumber.clear();
      _busRoute.clear();
      _busFees.clear();
      _busRegNumber.clear();
      setState(() {
        _currentPage = 0;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to register bus')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentPage == 0) {
      // Menu page with 4 buttons
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.purple[50]!, Colors.pink[100]!],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Registration Menu',
                  style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.purple[900]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                _buildMenuButton(
                  icon: Icons.school,
                  title: 'Register Student',
                  color: Colors.blue,
                  onPressed: () => setState(() => _currentPage = 1),
                ),
                const SizedBox(height: 16),
                _buildMenuButton(
                  icon: Icons.people,
                  title: 'Register Staff',
                  color: Colors.green,
                  onPressed: () => setState(() => _currentPage = 2),
                ),
                const SizedBox(height: 16),
                _buildMenuButton(
                  icon: Icons.bar_chart,
                  title: 'Add Performance',
                  color: Colors.orange,
                  onPressed: () => setState(() => _currentPage = 3),
                ),
                const SizedBox(height: 16),
                _buildMenuButton(
                  icon: Icons.directions_bus,
                  title: 'Register Bus',
                  color: Colors.teal,
                  onPressed: () => setState(() => _currentPage = 4),
                ),
              ],
            ),
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

  Widget _buildMenuButton({required IconData icon, required String title, required Color color, required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      height: 130,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 8,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 44, color: Colors.white),
            const SizedBox(height: 10),
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
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue[50]!, Colors.cyan[100]!],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildBackButton(),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[600],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Register Student',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.3), blurRadius: 8)],
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _sName,
                    decoration: InputDecoration(
                      labelText: 'Student Name',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: Colors.blue[50],
                      prefixIcon: const Icon(Icons.person, color: Colors.blue),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _sClass,
                          items: _classes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                          onChanged: (v) {
                            setState(() {
                              _sClass = v;
                              print('DEBUG: Selected class: $v');
                              // Auto-load hostel fee if hostel facility is already checked
                              if (_sHostelFacility && v != null) {
                                print('DEBUG: Hostel facility checked, loading fee for class: $v');
                                print('DEBUG: Available fees: $_hostelFeesByClass');
                                _sHostelFee = _hostelFeesByClass[v] ?? 0;
                                print('DEBUG: Set hostel fee to: $_sHostelFee');
                              }
                            });
                          },
                          decoration: InputDecoration(
                            labelText: 'Class',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            filled: true,
                            fillColor: Colors.blue[50],
                            prefixIcon: const Icon(Icons.school, color: Colors.blue),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _sSection,
                          items: _sections.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                          onChanged: (v) {
                            setState(() {
                              _sSection = v;
                            });
                          },
                          decoration: InputDecoration(
                            labelText: 'Section',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            filled: true,
                            fillColor: Colors.blue[50],
                            prefixIcon: const Icon(Icons.school, color: Colors.blue),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _sFather,
                    decoration: InputDecoration(
                      labelText: "Father's Name",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: Colors.blue[50],
                      prefixIcon: const Icon(Icons.person, color: Colors.blue),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _sMother,
                    decoration: InputDecoration(
                      labelText: "Mother's Name",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: Colors.blue[50],
                      prefixIcon: const Icon(Icons.person, color: Colors.blue),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _sParentMobile,
                    decoration: InputDecoration(
                      labelText: 'Parent Mobile',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: Colors.blue[50],
                      prefixIcon: const Icon(Icons.phone, color: Colors.blue),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _sAddress,
                    decoration: InputDecoration(
                      labelText: 'Address',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: Colors.blue[50],
                      prefixIcon: const Icon(Icons.home, color: Colors.blue),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _sGender,
                    items: const [DropdownMenuItem(value: 'Male', child: Text('Male')), DropdownMenuItem(value: 'Female', child: Text('Female'))],
                    onChanged: (v) => setState(() => _sGender = v),
                    decoration: InputDecoration(
                      labelText: 'Gender',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: Colors.blue[50],
                      prefixIcon: const Icon(Icons.wc, color: Colors.blue),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Joining Date
                  ListTile(
                    leading: const Icon(Icons.calendar_today, color: Colors.blue),
                    title: Text(
                      _selectedJoiningDate == null
                          ? 'Select Joining Date'
                          : 'Joining Date: ${DateFormat('dd-MM-yyyy').format(_selectedJoiningDate!)}',
                    ),
                    trailing: const Icon(Icons.edit, color: Colors.blue),
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: _selectedJoiningDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (pickedDate != null) {
                        setState(() {
                          _selectedJoiningDate = pickedDate;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  // Bus Facility
                  CheckboxListTile(
                    title: const Text('Bus Facility', style: TextStyle(fontWeight: FontWeight.w600)),
                    value: _sBusFacility,
                    activeColor: Colors.blue,
                    onChanged: (v) => setState(() => _sBusFacility = v ?? false),
                  ),
                  if (_sBusFacility) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _sBusRoute,
                      items: _busRoutes.map((route) => DropdownMenuItem(value: route, child: Text(route))).toList(),
                      onChanged: (v) {
                        setState(() => _sBusRoute = v);
                        if (v != null) {
                          _loadBusNumbersByRoute(v);
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Select Bus Route',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        filled: true,
                        fillColor: Colors.blue[50],
                        prefixIcon: const Icon(Icons.directions_bus, color: Colors.blue),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_busNumbers.isNotEmpty)
                      DropdownButtonFormField<String>(
                        value: _sBusNo,
                        items: _busNumbers.map((busNo) => DropdownMenuItem(value: busNo, child: Text(busNo))).toList(),
                        onChanged: (v) => setState(() => _sBusNo = v),
                        decoration: InputDecoration(
                          labelText: 'Select Bus Number',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: Colors.blue[50],
                          prefixIcon: const Icon(Icons.confirmation_number, color: Colors.blue),
                        ),
                      )
                    else if (_sBusRoute != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Loading bus numbers...',
                          style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
                        ),
                      ),
                  ],
                  const SizedBox(height: 16),
                  // Hostel Facility
                  CheckboxListTile(
                    title: const Text('Hostel Facility', style: TextStyle(fontWeight: FontWeight.w600)),
                    value: _sHostelFacility,
                    activeColor: Colors.blue,
                    onChanged: (v) {
                      setState(() {
                        _sHostelFacility = v ?? false;
                        // Auto-load hostel fee if class is selected
                        if (_sHostelFacility && _sClass != null) {
                          print('DEBUG: Checking hostel fee for class: $_sClass');
                          print('DEBUG: Available fees: $_hostelFeesByClass');
                          _sHostelFee = _hostelFeesByClass[_sClass] ?? 0;
                          print('DEBUG: Set hostel fee to: $_sHostelFee');
                        }
                      });
                    },
                  ),
                  if (_sHostelFacility) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        border: Border.all(color: Colors.blue),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Hostel Fee: ₹${_sHostelFee.toStringAsFixed(2)}',
                        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.blue[900]),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSubmittingStudent ? null : _submitStudent,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isSubmittingStudent
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                          : const Text('Register Student', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
          const SizedBox(height: 12),
          TextField(controller: _staffSalary, decoration: const InputDecoration(labelText: 'Salary', border: OutlineInputBorder()), keyboardType: TextInputType.number),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _staffType,
            items: const [
              DropdownMenuItem(value: 'Teaching', child: Text('Teaching')),
              DropdownMenuItem(value: 'Non-Teaching', child: Text('Non-Teaching')),
            ],
            onChanged: (value) {
              setState(() {
                _staffType = value;
              });
            },
            decoration: const InputDecoration(
              labelText: 'Staff Type',
              border: OutlineInputBorder(),
            ),
          ),
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
          const Text('Select Class', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _perfClass,
                  items: _classes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) {
                    setState(() {
                      _perfClass = v;
                      _perfSection = null;
                      _perfStudent = null;
                      _perfStudents = [];
                    });
                  },
                  decoration: const InputDecoration(labelText: 'Class', border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _perfSection,
                  items: _sections.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) {
                    setState(() {
                      _perfSection = v;
                      _perfStudent = null;
                      _perfStudents = [];
                    });
                    if (_perfClass != null && v != null) {
                      _loadStudentsForClass('$_perfClass-$v');
                    }
                  },
                  decoration: const InputDecoration(labelText: 'Section', border: OutlineInputBorder()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _openStudentSearchDialog,
              icon: const Icon(Icons.search),
              label: const Text('Search & Select Student'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (_perfStudent != null) ...[  
            const SizedBox(height: 12), 
            Text(
              'Selected: ${_perfStudent!.name} (${_perfStudent!.className})',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.blue,
              ),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _perfAssessment,
            decoration: const InputDecoration(
              labelText: 'Assessment Name',
              border: OutlineInputBorder(),
              hintText: 'e.g., Mid-term, Final Exam',
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enter Marks for Each Subject',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange[900],
                  ),
                ),
                const SizedBox(height: 12),
                ..._subjects.map((subject) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            subject,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: TextField(
                            controller: _subjectMarksControllers[subject],
                            decoration: InputDecoration(
                              hintText: 'Marks',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isSubmittingPerf ? null : _submitPerformance,
              child: _isSubmittingPerf
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Add Performance'),
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
          TextField(controller: _busRegNumber, decoration: const InputDecoration(labelText: 'Bus Registration Number', border: OutlineInputBorder())),
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

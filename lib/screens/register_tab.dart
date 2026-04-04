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
  String? _sHostelType = 'NON-AC';
  DateTime? _selectedJoiningDate;
  double _sHostelFee = 0;
  bool _sAdminFee = false;

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
  Map<String, Map<String, double>> _hostelFeesByClass = {};

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

  void _updateHostelFee() {
    if (_sHostelFacility && _sClass != null && _sHostelType != null) {
      _sHostelFee = _hostelFeesByClass[_sClass]?[_sHostelType!] ?? 0;
    } else {
      _sHostelFee = 0;
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
      'HOSTELTYPE': _sHostelFacility ? _sHostelType : null,
    };
    data['DOJ'] = _selectedJoiningDate != null ? DateFormat('dd-MM-yyyy').format(_selectedJoiningDate!) : null;
    final ok = await SupabaseService.insertStudent(data);
    
    // If student inserted and Admin Fee checkbox was selected, add the fee record
    if (ok && _sAdminFee) {
      final currentMonth = DateTime.now().month;
      int currentTerm = 1;
      String termMonth = 'June - September';
      
      // Determine current term based on current month
      if (currentMonth >= 6 && currentMonth <= 9) {
        currentTerm = 1;
        termMonth = 'June - September';
      } else if (currentMonth >= 11 || currentMonth <= 2) {
        currentTerm = 2;
        termMonth = 'November - February';
      } else if (currentMonth >= 3 && currentMonth <= 5) {
        currentTerm = 3;
        termMonth = 'March - June';
      }
      
      final currentYear = DateTime.now().year.toString();
      final feeData = {
        'STUDENT NAME': _sName.text.trim(),
        'AMOUNT': 500,
        'FEE TYPE': 'Administration fee',
        'DATE': DateFormat('dd-MM-yyyy').format(DateTime.now()),
        'TERM MONTH': termMonth,
        'TERM YEAR': currentYear,
        'TERM NO': currentTerm.toString(),
      };
      await SupabaseService.insertFee(feeData);
    }

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
        _sHostelType = 'NON-AC';
        _selectedJoiningDate = null;
        _sHostelFee = 0;
        _sAdminFee = false;
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
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Registration Portal',
                  style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                _buildMenuButton(
                  icon: Icons.school_outlined,
                  title: 'Register Student',
                  subtitle: 'Add new students to the system',
                  gradient: const [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  onPressed: () => setState(() => _currentPage = 1),
                ),
                const SizedBox(height: 16),
                _buildMenuButton(
                  icon: Icons.people_outline,
                  title: 'Register Staff',
                  subtitle: 'Manage school faculty and staff',
                  gradient: const [Color(0xFF0EA5E9), Color(0xFF2DD4BF)],
                  onPressed: () => setState(() => _currentPage = 2),
                ),
                const SizedBox(height: 16),
                _buildMenuButton(
                  icon: Icons.bar_chart_outlined,
                  title: 'Add Performance',
                  subtitle: 'Record academic achievements',
                  gradient: const [Color(0xFFF59E0B), Color(0xFFD97706)],
                  onPressed: () => setState(() => _currentPage = 3),
                ),
                const SizedBox(height: 16),
                _buildMenuButton(
                  icon: Icons.directions_bus_outlined,
                  title: 'Register Bus',
                  subtitle: 'Manage transport routes and vehicles',
                  gradient: const [Color(0xFF10B981), Color(0xFF059669)],
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

  Widget _buildMenuButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradient,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      height: 120,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, size: 32, color: Colors.white),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStudentRegistrationPage() {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildBackButton(),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Student Registration',
                    style: GoogleFonts.poppins(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Fill in the details to enroll a new student',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
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
                      hintText: 'Enter full name',
                      prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF6366F1)),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
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
                              _updateHostelFee();
                            });
                          },
                          decoration: InputDecoration(
                            labelText: 'Class',
                            filled: true,
                            fillColor: const Color(0xFFF1F5F9),
                            prefixIcon: const Icon(Icons.school_outlined, color: Color(0xFF6366F1)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
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
                            filled: true,
                            fillColor: const Color(0xFFF1F5F9),
                            prefixIcon: const Icon(Icons.grid_view_outlined, color: Color(0xFF6366F1)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
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
                      prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF6366F1)),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _sMother,
                    decoration: InputDecoration(
                      labelText: "Mother's Name",
                      prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF6366F1)),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _sParentMobile,
                    decoration: InputDecoration(
                      labelText: 'Parent Mobile',
                      prefixIcon: const Icon(Icons.phone_outlined, color: Color(0xFF6366F1)),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _sAddress,
                    decoration: InputDecoration(
                      labelText: 'Address',
                      prefixIcon: const Icon(Icons.home_outlined, color: Color(0xFF6366F1)),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _sGender,
                    items: const [DropdownMenuItem(value: 'Male', child: Text('Male')), DropdownMenuItem(value: 'Female', child: Text('Female'))],
                    onChanged: (v) => setState(() => _sGender = v),
                    decoration: InputDecoration(
                      labelText: 'Gender',
                      prefixIcon: const Icon(Icons.wc_outlined, color: Color(0xFF6366F1)),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
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
                  // Admin Fee Checkbox
                  CheckboxListTile(
                    title: const Text('Admin Fee (Rs. 500)', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Automatically add Rs. 500 as Administration fee'),
                    value: _sAdminFee,
                    activeColor: Colors.blue,
                    onChanged: (v) => setState(() => _sAdminFee = v ?? false),
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
                    Autocomplete<String>(
                      initialValue: TextEditingValue(text: _sBusRoute ?? ''),
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text == '') {
                          return _busRoutes;
                        }
                        return _busRoutes.where((String option) {
                          return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                        });
                      },
                      onSelected: (String selection) {
                        setState(() => _sBusRoute = selection);
                        _loadBusNumbersByRoute(selection);
                        setState(() => _sBusNo = null);
                      },
                      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                        return TextField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: InputDecoration(
                            labelText: 'Search & Select Bus Route',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            filled: true,
                            fillColor: Colors.blue[50],
                            prefixIcon: const Icon(Icons.search, color: Colors.blue),
                          ),
                          onChanged: (v) {
                            if (_busRoutes.contains(v)) {
                              setState(() => _sBusRoute = v);
                              _loadBusNumbersByRoute(v);
                            } else {
                              setState(() => _sBusRoute = null);
                            }
                          },
                        );
                      },
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4,
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: MediaQuery.of(context).size.width - 64,
                              height: 200,
                              child: ListView.builder(
                                padding: EdgeInsets.zero,
                                itemCount: options.length,
                                itemBuilder: (BuildContext context, int index) {
                                  final String option = options.elementAt(index);
                                  return ListTile(
                                    title: Text(option),
                                    onTap: () {
                                      onSelected(option);
                                    },
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
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
                        _updateHostelFee();
                      });
                    },
                  ),
                  if (_sHostelFacility) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('AC'),
                            value: 'AC',
                            groupValue: _sHostelType,
                            onChanged: (v) {
                              setState(() {
                                _sHostelType = v;
                                _updateHostelFee();
                              });
                            },
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('NON-AC'),
                            value: 'NON-AC',
                            groupValue: _sHostelType,
                            onChanged: (v) {
                              setState(() {
                                _sHostelType = v;
                                _updateHostelFee();
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        border: Border.all(color: Colors.blue),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Hostel Fee: Rs.${_sHostelFee.toStringAsFixed(2)}',
                        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.blue[900]),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isSubmittingStudent ? null : _submitStudent,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: _isSubmittingStudent 
                        ? const CircularProgressIndicator(color: Colors.white) 
                        : Text('Submit Registration', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
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
    return Container(
      color: const Color(0xFFF8FAFC),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildBackButton(),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0EA5E9), Color(0xFF2DD4BF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0EA5E9).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Staff Registration',
                    style: GoogleFonts.poppins(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Register new faculty and school staff',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _staffName,
                    decoration: InputDecoration(
                      labelText: 'Staff Name',
                      prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF0EA5E9)),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _staffQualification,
                    decoration: InputDecoration(
                      labelText: 'Qualification',
                      prefixIcon: const Icon(Icons.school_outlined, color: Color(0xFF0EA5E9)),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _staffMobile,
                    decoration: InputDecoration(
                      labelText: 'Mobile Number',
                      prefixIcon: const Icon(Icons.phone_outlined, color: Color(0xFF0EA5E9)),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _staffSalary,
                    decoration: InputDecoration(
                      labelText: 'Salary',
                      prefixIcon: const Icon(Icons.payments_outlined, color: Color(0xFF0EA5E9)),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _staffType,
                    items: const [
                      DropdownMenuItem(value: 'Teaching', child: Text('Teaching')),
                      DropdownMenuItem(value: 'Non-Teaching', child: Text('Non-Teaching')),
                    ],
                    onChanged: (value) => setState(() => _staffType = value),
                    decoration: InputDecoration(
                      labelText: 'Staff Type',
                      prefixIcon: const Icon(Icons.category_outlined, color: Color(0xFF0EA5E9)),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isSubmittingStaff ? null : _submitStaff,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0EA5E9),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: _isSubmittingStaff 
                        ? const CircularProgressIndicator(color: Colors.white) 
                        : Text('Register Staff', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
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

  Widget _buildPerformancePage() {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildBackButton(),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF59E0B).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Academic Performance',
                    style: GoogleFonts.poppins(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Record student grades and achievements',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                          decoration: InputDecoration(
                            labelText: 'Class',
                            filled: true,
                            fillColor: const Color(0xFFF1F5F9),
                            prefixIcon: const Icon(Icons.school_outlined, color: Color(0xFFF59E0B)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
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
                          decoration: InputDecoration(
                            labelText: 'Section',
                            filled: true,
                            fillColor: const Color(0xFFF1F5F9),
                            prefixIcon: const Icon(Icons.grid_view_outlined, color: Color(0xFFF59E0B)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _openStudentSearchDialog,
                      icon: const Icon(Icons.search_outlined),
                      label: Text('Search & Select Student', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B).withOpacity(0.1),
                        foregroundColor: const Color(0xFFD97706),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  if (_perfStudent != null) ...[  
                    const SizedBox(height: 16), 
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline, color: Color(0xFFD97706), size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Selected: ${_perfStudent!.name}',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFD97706),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  TextField(
                    controller: _perfAssessment,
                    decoration: InputDecoration(
                      labelText: 'Assessment Name',
                      hintText: 'e.g., Mid-term, Final Exam',
                      prefixIcon: const Icon(Icons.assignment_outlined, color: Color(0xFFF59E0B)),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Subject Marks',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._subjects.map((subject) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              subject,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: TextField(
                              controller: _subjectMarksControllers[subject],
                              decoration: InputDecoration(
                                hintText: 'Marks',
                                filled: true,
                                fillColor: const Color(0xFFF1F5F9),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isSubmittingPerf ? null : _submitPerformance,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: _isSubmittingPerf
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text('Add Performance Record', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
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

  Widget _buildBusRegistrationPage() {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildBackButton(),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bus Registration',
                    style: GoogleFonts.poppins(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Manage school transport and vehicle routes',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _busNumber,
                    decoration: InputDecoration(
                      labelText: 'Bus Number / ID',
                      prefixIcon: const Icon(Icons.directions_bus_outlined, color: Color(0xFF10B981)),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _busRegNumber,
                    decoration: InputDecoration(
                      labelText: 'Registration Number',
                      prefixIcon: const Icon(Icons.badge_outlined, color: Color(0xFF10B981)),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _busRoute,
                    decoration: InputDecoration(
                      labelText: 'Route Name',
                      prefixIcon: const Icon(Icons.route_outlined, color: Color(0xFF10B981)),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _busFees,
                    decoration: InputDecoration(
                      labelText: 'Transport Fees',
                      prefixIcon: const Icon(Icons.payments_outlined, color: Color(0xFF10B981)),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isSubmittingBus ? null : _submitBus,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: _isSubmittingBus 
                        ? const CircularProgressIndicator(color: Colors.white) 
                        : Text('Register Bus', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
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

  Widget _buildBackButton() {
    return Align(
      alignment: Alignment.topLeft,
      child: InkWell(
        onTap: () => setState(() => _currentPage = 0),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.arrow_back, size: 20, color: Color(0xFF6366F1)),
              const SizedBox(width: 8),
              Text(
                'Back to Menu',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6366F1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

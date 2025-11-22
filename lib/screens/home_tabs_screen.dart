import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:school_management/services/supabase_service.dart';
import 'package:school_management/models/student.dart';
import 'package:school_management/models/staff.dart';
import 'package:school_management/screens/student_detail_screen.dart';
import 'package:school_management/screens/register_tab.dart';
import 'package:school_management/screens/fees_tab.dart';
import 'package:school_management/screens/report_tab.dart';
import 'package:school_management/screens/diesel_data_screen.dart';

class HomeTabsScreen extends StatefulWidget {
  final String role;
  final String username;
  final String? parentMobile;

  const HomeTabsScreen({
    super.key,
    required this.role,
    required this.username,
    this.parentMobile,
  });

  @override
  State<HomeTabsScreen> createState() => _HomeTabsScreenState();
}

class _HomeTabsScreenState extends State<HomeTabsScreen> with SingleTickerProviderStateMixin {
  bool _sidebarOpen = true;
  late TabController _tabController;
  late DateTime _currentDateTime;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _currentDateTime = DateTime.now();
    _startTimeUpdater();
  }

  void _startTimeUpdater() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() {
          _currentDateTime = DateTime.now();
        });
      }
      return mounted;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.year}';
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <Tab>[
      const Tab(text: 'Student Data'),
      const Tab(text: 'Register'),
      const Tab(text: 'Staff Data'),
      const Tab(text: 'Transport Details'),
      const Tab(text: 'Fees'),
      const Tab(text: 'Reports'),
    ];

    final views = <Widget>[
      StudentDataWidget(parentMobile: widget.parentMobile),
      const RegisterTab(),
      const Center(child: StaffDataWidget()),
      const Center(child: TransportDataWidget()),
      const Center(child: FeesTab()),
      const Center(child: ReportTab()),
    ];

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 120,
        leading: IconButton(
          icon: Icon(_sidebarOpen ? Icons.menu_open : Icons.menu),
          onPressed: () => setState(() => _sidebarOpen = !_sidebarOpen),
        ),
        title: Row(
          children: [
            // Logo from assets
            Container(
              width: 85,
              height: 85,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.contain,
                  scale: 0.8,
                ),
              ),
            ),
            const SizedBox(width: 16),
            // School info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'NALANDA IIT OLYMPIAD SCHOOL',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'NARSIPATNAM (1004)',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Date: ${_formatDateTime(_currentDateTime)}',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70,
                    ),
                  ),
                  Text(
                    'Time: ${_formatTime(_currentDateTime)}',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
          const SizedBox(width: 8),
        ],
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue[800]!, Colors.blue[600]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Row(
        children: [
          // Sidebar Navigation
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: _sidebarOpen ? 250 : 0,
            color: Colors.indigo[50],
            child: _sidebarOpen
                ? SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.blue[800]!, Colors.blue[600]!],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.school,
                                size: 40,
                                color: Colors.white,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Navigation',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ..._buildSidebarItems(tabs),
                      ],
                    ),
                  )
                : null,
          ),
          // Main Content Area
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: views,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSidebarItems(List<Tab> tabs) {
    return tabs.asMap().entries.map((entry) {
      int idx = entry.key;
      Tab tab = entry.value;
      final isActive = _tabController.index == idx;

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? Colors.blue[100] : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isActive ? Border.all(color: Colors.blue[600]!, width: 2) : null,
        ),
        child: ListTile(
          title: Text(
            tab.text ?? '',
            style: GoogleFonts.poppins(
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive ? Colors.blue[900] : Colors.grey[700],
              fontSize: 14,
            ),
          ),
          leading: Icon(
            _getTabIcon(idx),
            color: isActive ? Colors.blue[600] : Colors.grey[600],
          ),
          onTap: () {
            _tabController.animateTo(idx);
            setState(() {});
          },
        ),
      );
    }).toList();
  }

  IconData _getTabIcon(int index) {
    const icons = [
      Icons.person,
      Icons.app_registration,
      Icons.people,
      Icons.directions_bus,
      Icons.payment,
      Icons.assessment,
    ];
    return icons[index];
  }
}

// Student Data Widget - Fetches from Supabase with class filter
class StudentDataWidget extends StatefulWidget {
  final String? parentMobile;

  const StudentDataWidget({super.key, this.parentMobile});

  @override
  State<StudentDataWidget> createState() => _StudentDataWidgetState();
}

class _StudentDataWidgetState extends State<StudentDataWidget> {
  late Future<List<String>> _classesFuture;
  String? _selectedClass;
  late Future<List<Student>> _studentsFuture;

  @override
  void initState() {
    super.initState();
    _classesFuture = SupabaseService.getUniqueClasses();
    _studentsFuture = Future.value([]);
  }

  void _onClassSelected(String? className) {
    setState(() {
      _selectedClass = className;
      if (className != null && className.isNotEmpty) {
        // Fetch students for this class
        if (widget.parentMobile != null && widget.parentMobile!.isNotEmpty) {
          // Parent: fetch their children in the selected class
          _studentsFuture = SupabaseService.getStudentsByClassAndParentMobile(
              className, widget.parentMobile!);
        } else {
          // Admin/Staff: fetch all students in the selected class
          _studentsFuture = SupabaseService.getStudentsByClass(className);
        }
      } else {
        _studentsFuture = Future.value([]);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Class Filter Dropdown with gradient header
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.cyan[600]!, Colors.cyan[400]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.all(16.0),
          child: FutureBuilder<List<String>>(
            future: _classesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 60,
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return Text('Error loading classes: ${snapshot.error}');
              }

              final classes = snapshot.data ?? [];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Filter by Class',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.cyan[300]!, width: 2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedClass,
                      hint: Text(
                        'Select a class',
                        style: GoogleFonts.inter(color: Colors.grey),
                      ),
                      underline: const SizedBox(),
                      items: classes
                          .map(
                            (className) => DropdownMenuItem<String>(
                              value: className,
                              child: Text(className),
                            ),
                          )
                          .toList(),
                      onChanged: _onClassSelected,
                    ),
                  ),
                ],
              );
            },
          ),
        ),

        // Student List
        if (_selectedClass != null && _selectedClass!.isNotEmpty)
          Expanded(
            child: FutureBuilder<List<Student>>(
              future: _studentsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline,
                              size: 48, color: Colors.red),
                          const SizedBox(height: 16),
                          Text('Error loading students: ${snapshot.error}',
                              textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  );
                }

                final students = snapshot.data ?? [];

                if (students.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.school,
                              size: 48, color: Colors.cyan[600]),
                          const SizedBox(height: 12),
                          const Text('No students found in this class'),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: students.length,
                  itemBuilder: (context, index) {
                    final student = students[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12.0),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            colors: [Colors.cyan[50]!, Colors.blue[50]!],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16.0),
                          title: Text(
                            student.name,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.cyan[900],
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              Text(
                                'Class: ${student.className}',
                                style: GoogleFonts.inter(color: Colors.grey),
                              ),
                              Text(
                                'Father: ${student.fatherName}',
                                style: GoogleFonts.inter(color: Colors.grey),
                              ),
                            ],
                          ),
                          trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.cyan[600]),
                          onTap: () {
                            // Navigate to student detail screen
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    StudentDetailScreen(student: student),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          )
        else
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline,
                        size: 48, color: Colors.cyan[600]),
                    const SizedBox(height: 12),
                    Text(
                      'Select a class to view students',
                      style: GoogleFonts.inter(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// Staff Data Widget - Fetches staff from Supabase STAFF table
class StaffDataWidget extends StatefulWidget {
  const StaffDataWidget({super.key});

  @override
  State<StaffDataWidget> createState() => _StaffDataWidgetState();
}

class _StaffDataWidgetState extends State<StaffDataWidget> {
  late Future<List<Staff>> _staffFuture;

  @override
  void initState() {
    super.initState();
    _staffFuture = SupabaseService.getAllStaff();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Staff>>(
      future: _staffFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Error loading staff: ${snapshot.error}'),
            ),
          );
        }

        final staffList = snapshot.data ?? [];

        if (staffList.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people, size: 48, color: Colors.amber[600]),
                  const SizedBox(height: 12),
                  Text('No Staff Records', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.amber[700])),
                  const SizedBox(height: 8),
                  Text('No staff members are currently registered.', style: GoogleFonts.inter(color: Colors.grey)),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: staffList.length,
          itemBuilder: (context, index) {
            final staff = staffList[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: [Colors.amber[50]!, Colors.orange[50]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        staff.name,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.amber[900],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.school, size: 16, color: Colors.amber[600]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Qualification: ${staff.qualification}',
                              style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[700]),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.phone, size: 16, color: Colors.amber[600]),
                          const SizedBox(width: 8),
                          Text(
                            'Mobile: ${staff.mobile}',
                            style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[700]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class TransportDataWidget extends StatefulWidget {
  const TransportDataWidget({super.key});

  @override
  State<TransportDataWidget> createState() => _TransportDataWidgetState();
}

class _TransportDataWidgetState extends State<TransportDataWidget> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange[50]!, Colors.deepOrange[50]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Container(
            color: Colors.deepOrange[700],
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelStyle: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              tabs: const [
                Tab(text: 'Transport Details'),
                Tab(text: 'Diesel Data'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTransportDetails(),
                _buildDieselDataTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransportDetails() {
    return FutureBuilder<Map<String, Map<String, dynamic>>>(
      future: SupabaseService.getAllTransportDataWithBusReg(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(Colors.deepOrange[600]),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading transport data',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.red[600],
              ),
            ),
          );
        }

        final transportData = snapshot.data ?? {};

        if (transportData.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.directions_bus, size: 64, color: Colors.deepOrange[600]),
                const SizedBox(height: 20),
                Text(
                  'No Transport Data Available',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.deepOrange[900],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'No buses or routes configured yet.',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.directions_bus, size: 28, color: Colors.deepOrange[600]),
                  const SizedBox(width: 12),
                  Text(
                    'Transport Details',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.deepOrange[900],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  itemCount: transportData.length,
                  itemBuilder: (context, index) {
                    final busReg = transportData.keys.elementAt(index);
                    final busData = transportData[busReg]!;
                    final busNumber = busData['busNumber'] as String;
                    final routes = (busData['routes'] as List<String>?) ?? [];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            colors: [Colors.white, Colors.orange[50]!],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: FutureBuilder<Map<String, dynamic>?>(
                          future: SupabaseService.getLatestDieselDataForRoute(busNumber),
                          builder: (context, dieselSnapshot) {
                            final latestDiesel = dieselSnapshot.data;

                            return Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.deepOrange[100],
                                        ),
                                        child: Icon(
                                          Icons.directions_bus,
                                          color: Colors.deepOrange[700],
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Route No',
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                            Text(
                                              busNumber,
                                              style: GoogleFonts.poppins(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.deepOrange[800],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.deepOrange[100],
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          'Reg: $busReg',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.deepOrange[700],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  // Last Diesel Fill Information
                                  if (latestDiesel != null)
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.amber[50],
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.amber[300]!,
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Last Filled',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                latestDiesel['FilledDate']?.toString() ?? 'N/A',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.amber[900],
                                                ),
                                              ),
                                            ],
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                'Last Filled Litres',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${latestDiesel['FilledLitres'] ?? 0.0} L',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.green[700],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    )
                                  else
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.grey[300]!,
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                                          const SizedBox(width: 8),
                                          Text(
                                            'No diesel data recorded yet',
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Routes:',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: routes.map((route) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.orange[200],
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: Colors.deepOrange[400]!,
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.location_on,
                                              size: 14,
                                              color: Colors.deepOrange[700],
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              route,
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.deepOrange[900],
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDieselDataTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.local_gas_station, size: 64, color: Colors.deepOrange[600]),
          const SizedBox(height: 20),
          Text(
            'Diesel Data Management',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.deepOrange[900],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const DieselDataScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange[700],
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
            ),
            icon: const Icon(Icons.open_in_new, color: Colors.white),
            label: Text(
              'Manage Diesel Data',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

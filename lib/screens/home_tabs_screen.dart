import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:school_management/services/supabase_service.dart';
import 'package:school_management/models/student.dart';
import 'package:school_management/models/staff.dart';
import 'package:school_management/screens/student_detail_screen.dart';
import 'package:school_management/screens/register_tab.dart';
import 'package:school_management/screens/fees_tab.dart';
import 'package:school_management/screens/report_tab.dart';

class HomeTabsScreen extends StatelessWidget {
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
      StudentDataWidget(parentMobile: null),
      const RegisterTab(),
      const Center(child: StaffDataWidget()),
      const Center(child: TransportDataWidget()),
      const Center(child: FeesTab()),
      const Center(child: ReportTab()),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Admin Dashboard',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          centerTitle: true,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[800]!, Colors.blue[600]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          bottom: TabBar(
            tabs: tabs,
            isScrollable: true,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
          ),
        ),
        body: TabBarView(
          children: views,
        ),
      ),
    );
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

class TransportDataWidget extends StatelessWidget {
  const TransportDataWidget({super.key});

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
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_bus, size: 64, color: Colors.deepOrange[600]),
            const SizedBox(height: 20),
            Text(
              'Transport Details',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.deepOrange[900],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Routes, vehicles and driver info appear here.',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

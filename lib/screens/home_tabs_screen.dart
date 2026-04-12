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
import 'package:school_management/screens/leave_requests_approval_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html;
import 'package:school_management/screens/salary_slips_screen.dart';
import 'package:school_management/screens/accounts_tab.dart';
import 'package:school_management/models/user_role.dart';
import 'package:school_management/screens/student_data_tab.dart';
import 'package:school_management/screens/miscellaneous_screen.dart';
import 'package:school_management/screens/Attendance.dart';
import 'package:school_management/screens/Events.dart';
import 'package:school_management/screens/staff_student_details_screen.dart';
import 'package:school_management/screens/dashboard_tab.dart';
import 'package:school_management/widgets/chat_bot_widget.dart';

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

class _HomeTabsScreenState extends State<HomeTabsScreen>
    with SingleTickerProviderStateMixin {
  bool _sidebarOpen = true;
  late TabController _tabController;
  late DateTime _currentDateTime;
  int _lastTabCount = 10;

  @override
  void initState() {
    super.initState();
    // HomeTabsScreen is only used by admin, always 13 tabs
    _lastTabCount = 13;
    // Initialize with index 0 to avoid RangeError
    _tabController =
        TabController(length: _lastTabCount, initialIndex: 0, vsync: this);

    // Monitor for unexpected index changes
    _tabController.addListener(() {
      if (_tabController.index >= _tabController.length) {
        print(
            'WARNING: TabController index ${_tabController.index} >= length ${_tabController.length}');
        _tabController.index = 0;
      }
    });

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
            child: const Text('Confirm', style: TextStyle(color: Colors.red)),
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
    final baseTabs = <Tab>[
      const Tab(text: 'Dashboard'),
      const Tab(text: 'Student Data'),
      const Tab(text: 'Register'),
      const Tab(text: 'Staff Data'),
      const Tab(text: 'Transport Details'),
      const Tab(text: 'Fees'),
      const Tab(text: 'Reports'),
    ];

    final baseViews = <Widget>[
      const DashboardTab(),
      const StudentDataTab(),
      const RegisterTab(),
      const Center(child: StaffDataWidget()),
      const Center(child: TransportDataWidget()),
      const Center(child: FeesTab()),
      const Center(child: ReportTab()),
    ];

    final userRole = UserRole.roles.firstWhere(
      (role) => role.id == widget.role,
      orElse: () => UserRole.roles.first, // Fallback to avoid crash
    );

    // Always add Salary Slips and Pending Requests tabs for admin
    final tabs = [
      ...baseTabs,
      const Tab(text: 'Salary Slips'),
      const Tab(text: 'Pending Requests'),
      const Tab(text: 'Accounts'),
      const Tab(text: 'Attendance'),
      const Tab(text: 'Events'),
      const Tab(text: 'Miscellaneous'),
    ];

    final views = [
      ...baseViews,
      const Center(child: SalarySlipsScreen()),
      const Center(child: LeaveRequestsApprovalScreen()),
      const Center(child: AccountsTab()),
      const AttendanceScreen(),
      const EventsScreen(),
      Center(child: MiscellaneousScreen(userRole: userRole)),
    ];

    return WillPopScope(
      onWillPop: () async {
        final shouldLogout = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirm Logout'),
            content: const Text('Are you sure you want to logout?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Confirm', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        if (shouldLogout == true) {
          if (context.mounted) {
            Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
          }
        }
        return false;
      },
      child: Scaffold(
      appBar: AppBar(
        toolbarHeight: 120,
        leading: IconButton(
          icon: Icon(_sidebarOpen ? Icons.menu_open : Icons.menu),
          onPressed: () => setState(() => _sidebarOpen = !_sidebarOpen),
        ),
        title: Row(
          children: [
            // Logo from assets
            Image.asset(
              'assets/images/logo.png',
              height: 85,
              fit: BoxFit.contain,
            ),
            const Spacer(),
            // School info
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'NALANDA IIT OLYMPIAD SCHOOL',
                  style: GoogleFonts.poppins(
                    fontSize: 35,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'NARSIPATNAM - 531116',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
            const Spacer(),
            // Date and time
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Date: ${_formatDateTime(_currentDateTime)}',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white70,
                  ),
                ),
                Text(
                  'Time: ${_formatTime(_currentDateTime)}',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            // Mother Image
            Image.asset(
              'assets/images/Mother.png',
              height: 85,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 16),
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
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF800000), Color(0xFFB91C1C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Row(
            children: [
              // Sidebar Navigation
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: _sidebarOpen ? 280 : 0,
                color: const Color(0xFFF1F5F9), // Slate 100
                child: _sidebarOpen
                    ? SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Color(0xFF800000), Color(0xFFB91C1C)],
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
                                    'Menu',
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
                  physics: const NeverScrollableScrollPhysics(),
                  children: views,
                ),
              ),
            ],
          ),
          const ChatBotWidget(),
        ],
      ),
    ));
  }

  List<Widget> _buildSidebarItems(List<Tab> tabs) {
    // Safety check: ensure TabController index is valid
    if (_tabController.index >= tabs.length) {
      _tabController.index = 0;
    }
    
    return tabs.asMap().entries.map((entry) {
      int idx = entry.key;
      Tab tab = entry.value;
      final isActive = _tabController.index == idx;
      final isMiscellaneous = tab.text == 'Miscellaneous';

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF800000).withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isActive ? Border.all(color: const Color(0xFF800000).withOpacity(0.2), width: 1) : null,
        ),
        child: ListTile(
          title: Text(
            tab.text ?? '',
            style: GoogleFonts.poppins(
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              color: isActive ? const Color(0xFF800000) : const Color(0xFF64748B),
              fontSize: 14,
            ),
          ),
          leading: Icon(
            _getTabIcon(idx),
            color: isActive ? const Color(0xFF800000) : const Color(0xFF94A3B8),
            size: 20,
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
      Icons.dashboard,
      Icons.person,
      Icons.app_registration,
      Icons.people,
      Icons.directions_bus,
      Icons.payment,
      Icons.assessment,
      Icons.receipt_long,
      Icons.pending_actions,
      Icons.account_balance_wallet,
      Icons.fact_check,
      Icons.event,
      Icons.category,
    ];
    return icons[index];
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
  List<String> _classes = [];
  List<String> _sections = [];

  @override
  void initState() {
    super.initState();
    _staffFuture = SupabaseService.getAllStaff();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    final classes = await SupabaseService.getClassesFromFeeStructure();
    final sections = List.generate(26, (i) => String.fromCharCode('A'.codeUnitAt(0) + i));
    if (mounted) {
      setState(() {
        _classes = classes..sort();
        _sections = sections;
      });
    }
  }

  void _showAssignClassDialog(Staff staff) {
    String? selectedClass;
    String? selectedSection;
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Assign Class to ${staff.name}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedClass,
                    hint: const Text('Select Class'),
                    items: _classes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedClass = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedSection,
                    hint: const Text('Select Section'),
                    items: _sections.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedSection = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (selectedClass == null || selectedSection == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please select both class and section')),
                            );
                            return;
                          }

                          setDialogState(() {
                            isSubmitting = true;
                          });

                          final className = '$selectedClass-$selectedSection';
                          final success = await SupabaseService.assignClassToTeacher(staff.name, className);

                          setDialogState(() {
                            isSubmitting = false;
                          });

                          if (success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Assigned ${staff.name} to $className')),
                            );
                            Navigator.of(context).pop();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Failed to assign class')),
                            );
                          }
                        },
                  child: isSubmitting ? const CircularProgressIndicator(strokeWidth: 2) : const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showRemoveClassDialog(Staff staff) async {
    List<String> assignedClasses = await SupabaseService.getClassesForStaff(staff.name);
    String? selectedClass;
    bool isSubmitting = false;

    if (!mounted) return;

    if (assignedClasses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No classes assigned to ${staff.name}')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Remove Class from ${staff.name}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedClass,
                    hint: const Text('Select Class to Remove'),
                    items: assignedClasses.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedClass = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                  onPressed: isSubmitting || selectedClass == null
                      ? null
                      : () async {
                          setDialogState(() {
                            isSubmitting = true;
                          });

                          final success = await SupabaseService.removeClassFromTeacher(staff.name, selectedClass!);

                          setDialogState(() {
                            isSubmitting = false;
                          });

                          if (success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Removed ${staff.name} from $selectedClass')),
                            );
                            Navigator.of(context).pop();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Failed to remove class')),
                            );
                          }
                        },
                  child: isSubmitting ? const CircularProgressIndicator(strokeWidth: 2, color: Colors.white) : const Text('Remove'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showStaffAssignmentDialog() async {
    final assignments = await SupabaseService.getAllStaffAssignments();
    
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Staff Assignments'),
              ElevatedButton.icon(
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Export CSV'),
                onPressed: () {
                  String csv = 'Staff Name,Assigned Class\n';
                  for (var row in assignments) {
                    csv += '${row['STAFF']},${row['CLASS']}\n';
                  }
                  final bytes = Uri.encodeComponent(csv);
                  html.AnchorElement(href: 'data:text/csv;charset=utf-8,$bytes')
                    ..setAttribute('download', 'staff_assignments.csv')
                    ..click();
                },
              ),
            ],
          ),
          content: SizedBox(
            width: 600,
            height: 400,
            child: assignments.isEmpty 
              ? const Center(child: Text('No assignments found'))
              : ListView.builder(
                  itemCount: assignments.length,
                  itemBuilder: (context, index) {
                    final row = assignments[index];
                    return ListTile(
                      title: Text(row['STAFF'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Class: ${row['CLASS'] ?? 'N/A'}'),
                      leading: const Icon(Icons.assignment_ind),
                    );
                  },
                ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
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

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.assignment_outlined),
                    label: const Text('Staff Assignment'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF800000),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onPressed: _showStaffAssignmentDialog,
                  ),
                ],
              ),
            ),
            if (staffList.isEmpty)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 48, color: const Color(0xFF800000)),
                        const SizedBox(height: 12),
                        Text('No Staff Records', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
                        const SizedBox(height: 8),
                        Text('No staff members are currently registered.', style: GoogleFonts.inter(color: const Color(0xFF64748B))),
                      ],
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: staffList.length,
                  itemBuilder: (context, index) {
                    final staff = staffList[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: const Color(0xFFE2E8F0), width: 1),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: Colors.white,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                staff.name,
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Icon(Icons.school_outlined, size: 16, color: Color(0xFF64748B)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Qualification: ${staff.qualification}',
                                      style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.phone_outlined, size: 16, color: Color(0xFF64748B)),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Mobile: ${staff.mobile}',
                                    style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.groups_outlined, size: 18),
                                    label: const Text('Students'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF800000).withOpacity(0.1),
                                      foregroundColor: const Color(0xFF800000),
                                      elevation: 0,
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => StaffStudentDetailsScreen(
                                            staffName: staff.name,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red[50],
                                      foregroundColor: Colors.red[700],
                                      elevation: 0,
                                    ),
                                    onPressed: () => _showRemoveClassDialog(staff),
                                    child: const Text('Remove Class'),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF800000),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                    ),
                                    onPressed: () => _showAssignClassDialog(staff),
                                    child: const Text('Assign Class'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
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
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
      ),
      child: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF800000), Color(0xFFB91C1C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 4,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withOpacity(0.7),
              labelStyle: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              tabs: const [
                Tab(text: 'Transport Details', icon: Icon(Icons.directions_bus, size: 20)),
                Tab(text: 'Diesel Data', icon: Icon(Icons.local_gas_station, size: 20)),
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
                          future: SupabaseService.getDieselDataForRouteByDate(
                              busNumber, DateTime.now()),
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
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
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
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.deepOrange[100],
                                          borderRadius:
                                              BorderRadius.circular(20),
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
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
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
                                                latestDiesel['FilledDate']
                                                        ?.toString() ??
                                                    'N/A',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.amber[900],
                                                ),
                                              ),
                                            ],
                                          ),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                'Today\'s Filled Litres',
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
                                          Icon(Icons.info_outline,
                                              size: 16,
                                              color: Colors.grey[600]),
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
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.orange[200],
                                          borderRadius:
                                              BorderRadius.circular(8),
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

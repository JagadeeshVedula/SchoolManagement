import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:school_management/services/supabase_service.dart';
import 'package:school_management/models/student.dart';
import 'package:school_management/screens/student_detail_screen.dart';
import 'package:school_management/screens/student_attendance_report_screen.dart';
import 'package:school_management/screens/timetable_screen.dart';

class ParentHomeScreen extends StatefulWidget {
  final String parentMobile;

  const ParentHomeScreen({super.key, required this.parentMobile});

  @override
  State<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends State<ParentHomeScreen> {
  late Future<List<Student>> _studentsFuture;

  @override
  void initState() {
    super.initState();
    _studentsFuture = SupabaseService.getStudentsByParentMobile(widget.parentMobile);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Nalanda Parent App',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF2563EB),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2563EB), Color(0xFFF8FAFC)],
            stops: [0.0, 0.3],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 0),
              child: FutureBuilder<List<Student>>(
                future: _studentsFuture,
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                    final classes = snapshot.data!
                        .map((s) => s.className)
                        .toSet()
                        .toList();
                    return _NotificationTicker(classes: classes);
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome, Parent',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Viewing performance for your children',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: FutureBuilder<List<Student>>(
                  future: _studentsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    final students = snapshot.data ?? [];
                    if (students.isEmpty) {
                      return Center(
                        child: Text(
                          'No students found for this mobile number.',
                          style: GoogleFonts.inter(fontSize: 16),
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: students.length,
                      itemBuilder: (context, index) {
                        final student = students[index];
                        return _buildStudentCard(student);
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentCard(Student student) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            _showStudentOptions(context, student);
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withOpacity(0.1),
                    shape: BoxShape.circle,
                    image: student.photoUrl != null && student.photoUrl!.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(student.photoUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: student.photoUrl == null || student.photoUrl!.isEmpty
                      ? const Icon(
                          Icons.person,
                          color: Color(0xFF2563EB),
                          size: 30,
                        )
                      : null,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.name,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Class: ${student.className}',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Color(0xFF94A3B8),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showStudentOptions(BuildContext context, Student student) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                student.name,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose what you want to see',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 24),
              _buildOptionButton(
                context,
                icon: Icons.person_outline,
                label: 'Student Data',
                color: const Color(0xFF2563EB),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StudentDetailScreen(
                        student: student,
                        initialView: 'data',
                        isParentView: true,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _buildOptionButton(
                context,
                icon: Icons.bar_chart_outlined,
                label: 'Performance',
                color: const Color(0xFF059669),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StudentDetailScreen(
                        student: student,
                        initialView: 'performance',
                        isParentView: true,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _buildOptionButton(
                context,
                icon: Icons.assignment_outlined,
                label: 'Homework',
                color: const Color(0xFF8B5CF6),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StudentDetailScreen(
                        student: student,
                        initialView: 'homework',
                        isParentView: true,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _buildOptionButton(
                context,
                icon: Icons.table_chart_outlined,
                label: 'Timetable',
                color: const Color(0xFFEA580C),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TimetableScreen(
                        student: student,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _buildOptionButton(
                context,
                icon: Icons.calendar_today_outlined,
                label: 'Attendance',
                color: const Color(0xFFF59E0B),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StudentAttendanceReportScreen(
                        student: student,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const Spacer(),
            Icon(Icons.chevron_right, color: color.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }
}

class _NotificationTicker extends StatefulWidget {
  final List<String> classes;

  const _NotificationTicker({required this.classes});

  @override
  State<_NotificationTicker> createState() => _NotificationTickerState();
}

class _NotificationTickerState extends State<_NotificationTicker> {
  late Future<List<Map<String, dynamic>>> _eventsFuture;
  late ScrollController _scrollController;
  bool _shouldScroll = true;

  @override
  void initState() {
    super.initState();
    _eventsFuture = SupabaseService.getEventsForClasses(widget.classes);
    _scrollController = ScrollController();

    // Start ticker animation after some delay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _startScrolling();
      }
    });
  }

  void _startScrolling() async {
    while (_shouldScroll && mounted) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (_scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        if (maxScroll > 0) {
          await _scrollController.animateTo(
            maxScroll,
            duration: Duration(seconds: (maxScroll / 40).round() + 5),
            curve: Curves.linear,
          );
          if (mounted) _scrollController.jumpTo(0);
        } else {
          // If no scrollable content, just wait a bit and recheck
          await Future.delayed(const Duration(seconds: 5));
        }
      }
    }
  }

  @override
  void dispose() {
    _shouldScroll = false;
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _eventsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: Colors.red[50],
              border: Border(
                bottom: BorderSide(color: Colors.red[100]!, width: 1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_busy, size: 16, color: Colors.red[400]),
                const SizedBox(width: 8),
                Text(
                  'No upcoming events found',
                  style: GoogleFonts.inter(
                    color: Colors.red[700],
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }

        final events = snapshot.data!;
        final tickerText = events
            .map((e) => "NEW: ${e['EVENT_NAME']} (${e['EVENT_DATE']})")
            .join("      ★      ");

        return Container(
          width: double.infinity,
          height: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.yellow[700]!, Colors.orange[600]!],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                color: Colors.black,
                height: double.infinity,
                alignment: Alignment.center,
                child: Text(
                  'EVENTS',
                  style: GoogleFonts.poppins(
                    color: Colors.yellow[700],
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      child: Text(
                        tickerText,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 2,
                              offset: const Offset(1, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Duplicate to ensure scrollable length if content is short
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 10),
                      child: Text(
                        tickerText,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    // Triple for safety on wide screens
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 10),
                      child: Text(
                        tickerText,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

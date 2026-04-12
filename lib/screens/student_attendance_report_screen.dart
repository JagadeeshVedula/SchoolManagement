import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:school_management/models/student.dart';
import 'package:school_management/services/supabase_service.dart';

class StudentAttendanceReportScreen extends StatefulWidget {
  final Student student;

  const StudentAttendanceReportScreen({super.key, required this.student});

  @override
  State<StudentAttendanceReportScreen> createState() => _StudentAttendanceReportScreenState();
}

class _StudentAttendanceReportScreenState extends State<StudentAttendanceReportScreen> {
  DateTime _focusedDate = DateTime.now();
  Map<String, String> _attendanceMap = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  Future<void> _loadAttendance() async {
    setState(() => _isLoading = true);
    print('DEBUG: Starting attendance load for [${widget.student.name}] in class [${widget.student.className}]');
    try {
      final studentNameNormalized = widget.student.name.trim().toLowerCase();
      
      // Fetch both patterns to be absolutely sure
      final classData = await SupabaseService.getAttendanceByClass(widget.student.className);
      final directData = await SupabaseService.getAttendanceForStudent(widget.student.name);
      
      print('DEBUG: Class records found: ${classData.length}');
      print('DEBUG: Direct student records found: ${directData.length}');
      
      // Combine results
      final List<Map<String, dynamic>> allData = [...classData, ...directData];
      
      final Map<String, String> attendanceMap = {};
      final outputFormat = DateFormat('dd-MM-yyyy');
      
      for (var record in allData) {
        final rawDbName = record['STUDENT_NAME']?.toString();
        final dbName = rawDbName?.trim().toLowerCase();
        
        // Lenient name matching
        bool isMatch = false;
        if (dbName != null) {
           isMatch = (dbName == studentNameNormalized || dbName.contains(studentNameNormalized) || studentNameNormalized.contains(dbName));
        }

        if (isMatch) {
          final rawDate = record['DATE']?.toString().trim();
          final rawStatus = record['STATUS']?.toString().trim();
          print('DEBUG: Match found! Date: $rawDate, Status: $rawStatus, DB Name: $rawDbName');
          
          if (rawDate != null && rawStatus != null) {
            DateTime? parsedDate;
            try {
              if (rawDate.contains('-')) {
                final parts = rawDate.split('-');
                if (parts[0].length == 4) {
                   parsedDate = DateFormat('yyyy-MM-dd').parse(rawDate);
                } else {
                   parsedDate = DateFormat('dd-MM-yyyy').parse(rawDate);
                }
              }
            } catch (e) { /* silent parse fail */ }
            
            if (parsedDate != null) {
              final key = outputFormat.format(parsedDate);
              attendanceMap[key] = rawStatus;
            }
          }
        } else {
           // Optional: print failures if you want to see what didn't match
           // print('DEBUG: No match for DB Name: $rawDbName vs Searched: $studentNameNormalized');
        }
      }
      
      print('DEBUG: Final attendance map size: ${attendanceMap.length}');
      
      if (mounted) {
        setState(() {
          _attendanceMap = attendanceMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('DEBUG: Load Attendance Error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Attendance Report',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF2563EB),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2563EB), Color(0xFFF8FAFC)],
            stops: [0.0, 0.2],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildStudentHeader(),
                    const SizedBox(height: 20),
                    _buildCalendarCard(),
                    const SizedBox(height: 20),
                    _buildLegend(),
                    const SizedBox(height: 20),
                    _buildSummary(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStudentHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: const Color(0xFF2563EB).withOpacity(0.1),
            child: Text(
              widget.student.name.substring(0, 1).toUpperCase(),
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF2563EB),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.student.name,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E293B),
                ),
              ),
              Text(
                'Class: ${widget.student.className}',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            _buildCalendarHeader(),
            const SizedBox(height: 20),
            _buildDaysOfWeek(),
            const SizedBox(height: 10),
            _buildCalendarGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: () {
            setState(() {
              _focusedDate = DateTime(_focusedDate.year, _focusedDate.month - 1);
            });
          },
          icon: const Icon(Icons.chevron_left),
        ),
        Text(
          DateFormat('MMMM yyyy').format(_focusedDate),
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1E293B),
          ),
        ),
        IconButton(
          onPressed: () {
            setState(() {
              _focusedDate = DateTime(_focusedDate.year, _focusedDate.month + 1);
            });
          },
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget _buildDaysOfWeek() {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: days.map((day) {
        return Expanded(
          child: Center(
            child: Text(
              day,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF94A3B8),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCalendarGrid() {
    final lastDayOfMonth = DateTime(_focusedDate.year, _focusedDate.month + 1, 0).day;
    final firstDayOfMonth = DateTime(_focusedDate.year, _focusedDate.month, 1).weekday; // 1 = Monday, 7 = Sunday
    
    // Total cells in grid
    final prevMonthDays = firstDayOfMonth - 1;
    final totalCells = (lastDayOfMonth + prevMonthDays);
    final rows = (totalCells / 7).ceil();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: rows * 7,
      itemBuilder: (context, index) {
        final day = index - prevMonthDays + 1;
        if (day < 1 || day > lastDayOfMonth) {
          return const SizedBox.shrink();
        }

        final date = DateTime(_focusedDate.year, _focusedDate.month, day);
        final dateStr = DateFormat('dd-MM-yyyy').format(date);
        final status = _attendanceMap[dateStr];
        final isSunday = date.weekday == 7;
        final isFuture = date.isAfter(DateTime.now());

        return _buildDayCell(day, status, isSunday, isFuture);
      },
    );
  }

  Widget _buildDayCell(int day, String? status, bool isSunday, bool isFuture) {
    Color bgColor = Colors.transparent;
    Color textColor = const Color(0xFF1E293B);
    String label = '';

    if (isSunday) {
      label = 'H';
      textColor = Colors.blueGrey;
      bgColor = Colors.blueGrey.withOpacity(0.1);
    } else if (!isFuture) {
      final normalizedStatus = status?.toLowerCase();
      if (normalizedStatus == 'present' || normalizedStatus == 'p') {
        label = 'P';
        textColor = Colors.green;
        bgColor = Colors.green.withOpacity(0.1);
      } else if (normalizedStatus == 'abscent' || normalizedStatus == 'absent' || normalizedStatus == 'a') {
        label = 'A';
        textColor = Colors.red;
        bgColor = Colors.red.withOpacity(0.1);
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: label != '' ? textColor.withOpacity(0.3) : Colors.grey.withOpacity(0.1),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            day.toString(),
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B),
            ),
          ),
          if (label != '')
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLegendItem('Present', Colors.green),
        const SizedBox(width: 20),
        _buildLegendItem('Absent', Colors.red),
        const SizedBox(width: 20),
        _buildLegendItem('Holiday', Colors.blueGrey),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: color.withOpacity(0.5)),
          ),
          child: Center(
            child: Text(
              label.substring(0, 1),
              style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildSummary() {
    int present = 0;
    int absent = 0;
    int holidays = 0;

    final daysInMonth = DateTime(_focusedDate.year, _focusedDate.month + 1, 0).day;
    for (int i = 1; i <= daysInMonth; i++) {
        final date = DateTime(_focusedDate.year, _focusedDate.month, i);
        if (date.weekday == 7) {
            holidays++;
            continue;
        }
        final dateStr = DateFormat('dd-MM-yyyy').format(date);
        final status = _attendanceMap[dateStr];
        final normalizedStatus = status?.toLowerCase();
        if (normalizedStatus == 'present' || normalizedStatus == 'p') present++;
        else if (normalizedStatus == 'abscent' || normalizedStatus == 'absent' || normalizedStatus == 'a') absent++;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem('Present', present, Colors.greenAccent),
          _buildSummaryItem('Absent', absent, Colors.redAccent),
          _buildSummaryItem('Holidays', holidays, Colors.blueGrey),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

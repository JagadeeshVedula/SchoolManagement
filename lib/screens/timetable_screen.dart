import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:school_management/services/supabase_service.dart';
import 'package:school_management/models/student.dart';

class TimetableScreen extends StatefulWidget {
  final Student student;

  const TimetableScreen({super.key, required this.student});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  String? _selectedAssessment;
  List<String> _assessments = [];
  bool _isLoadingAssessments = true;
  List<Map<String, dynamic>> _timetableData = [];
  bool _isLoadingTimetable = false;

  @override
  void initState() {
    super.initState();
    _fetchAssessments();
  }

  Future<void> _fetchAssessments() async {
    final assessments =
        await SupabaseService.getTimetableAssessments(widget.student.className);
    if (mounted) {
      setState(() {
        _assessments = assessments;
        _isLoadingAssessments = false;
        if (_assessments.isNotEmpty) {
          _selectedAssessment = _assessments.first;
          _fetchTimetable(_selectedAssessment!);
        }
      });
    }
  }

  Future<void> _fetchTimetable(String assessmentName) async {
    setState(() {
      _isLoadingTimetable = true;
    });
    final data = await SupabaseService.getTimetable(
        widget.student.className, assessmentName);
    if (mounted) {
      setState(() {
        _timetableData = data;
        _isLoadingTimetable = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Student Timetable',
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF2563EB),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
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
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoadingAssessments
                  ? const Center(child: CircularProgressIndicator())
                  : _assessments.isEmpty
                      ? _buildEmptyState()
                      : _buildTimetableContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.class_, color: Color(0xFF2563EB), size: 20),
              const SizedBox(width: 8),
              Text(
                'Class: ${widget.student.className}',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Select Assessment',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedAssessment,
                isExpanded: true,
                icon:
                    const Icon(Icons.arrow_drop_down, color: Color(0xFF2563EB)),
                items: _assessments.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value, style: GoogleFonts.inter()),
                  );
                }).toList(),
                onChanged: (newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedAssessment = newValue;
                    });
                    _fetchTimetable(newValue);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimetableContent() {
    if (_isLoadingTimetable) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_timetableData.isEmpty) {
      return Center(
        child: Text(
          'No timetable found for this assessment.',
          style: GoogleFonts.inter(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    // Sort timetable by date
    _timetableData.sort((a, b) {
      final dateAStr = a['exam_date']?.toString() ?? a['date']?.toString() ?? a['event_date']?.toString() ?? '';
      final dateBStr = b['exam_date']?.toString() ?? b['date']?.toString() ?? b['event_date']?.toString() ?? '';
      try {
        final dateA = DateFormat('dd-MM-yyyy').parse(dateAStr);
        final dateB = DateFormat('dd-MM-yyyy').parse(dateBStr);
        return dateA.compareTo(dateB);
      } catch (e) {
        return 0;
      }
    });

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              children: [
                Text(
                  'NALANDA ENGLISH MEDIUM SCHOOL',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const Divider(height: 20),
                Text(
                  'EXAM TIMETABLE',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'ASSESSMENT NAME - ${_selectedAssessment ?? ""}',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.grey[100]),
                headingTextStyle: GoogleFonts.inter(
                    color: Colors.black, fontWeight: FontWeight.bold),
                columnSpacing: 30,
                border: TableBorder.all(color: Colors.grey[300]!, width: 1),
                columns: const [
                  DataColumn(label: Center(child: Text('CLASS'))),
                  DataColumn(label: Center(child: Text('DATE'))),
                  DataColumn(label: Center(child: Text('TIME'))),
                  DataColumn(label: Center(child: Text('SUBJECT'))),
                ],
                rows: _timetableData.map((row) {
                  final className = row['class_name']?.toString() ??
                      row['class']?.toString() ??
                      widget.student.className.split('-')[0];
                  final date = row['exam_date']?.toString() ??
                      row['date']?.toString() ??
                      row['event_date']?.toString() ??
                      '-';
                  final time =
                      row['exam_time']?.toString() ?? row['time']?.toString() ?? '-';
                  final subject = row['subject']?.toString() ?? '-';

                  return DataRow(
                    cells: [
                      DataCell(Center(child: Text(className, style: const TextStyle(fontWeight: FontWeight.w500)))),
                      DataCell(Center(child: Text(date))),
                      DataCell(Center(child: Text(time))),
                      DataCell(Center(child: Text(subject, style: const TextStyle(fontWeight: FontWeight.w600)))),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  DataCell _buildSubjectCell(dynamic subject) {
    final sub = subject?.toString() ?? '-';
    Color bgColor = Colors.white;
    Color textColor = const Color(0xFF1E293B);

    if (sub != '-' && sub.isNotEmpty) {
      // Assign colors based on subject name for variety
      final hash = sub.toLowerCase().hashCode;
      final hue = (hash % 12) * 30.0; // Distribute colors around the wheel
      bgColor = HSVColor.fromAHSV(0.15, hue, 0.5, 0.95).toColor();
      textColor = HSVColor.fromAHSV(1.0, hue, 0.8, 0.4).toColor();
    }

    return DataCell(
      Container(
        constraints: const BoxConstraints(minWidth: 80),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: sub != '-' && sub.isNotEmpty
              ? Border.all(color: textColor.withOpacity(0.2))
              : null,
        ),
        child: Text(
          sub,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight:
                sub != '-' && sub.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
            color: textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05), blurRadius: 20)
                ],
              ),
              child: Icon(Icons.calendar_month_outlined,
                  size: 80, color: Colors.blue[200]),
            ),
            const SizedBox(height: 24),
            Text(
              'No Timetable Found',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'We couldn\'t find a timetable for ${widget.student.className}.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: const Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }
}

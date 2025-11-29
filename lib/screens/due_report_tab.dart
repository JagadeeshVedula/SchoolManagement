import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:school_management/models/staff.dart';
import 'package:school_management/models/student.dart';
import 'package:school_management/services/supabase_service.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io' show File;
import 'dart:typed_data' show Uint8List;
import 'dart:html' as html;
import 'package:flutter/foundation.dart' show kIsWeb;


class DueReportTab extends StatefulWidget {
  final List<Staff> staffList;

  const DueReportTab({super.key, required this.staffList});

  @override
  State<DueReportTab> createState() => _DueReportTabState();
}

class _DueReportTabState extends State<DueReportTab> {
  Staff? _selectedStaff;
  List<String> _assignedClasses = [];
  bool _isLoadingClasses = false;
  bool _term1Selected = true;
  bool _term2Selected = true;
  bool _term3Selected = true;
  List<Map<String, dynamic>> _dueReportData = [];
  bool _isLoadingReport = false;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStaffSelector(),
          const SizedBox(height: 24),
          if (_selectedStaff != null) ...[
            _buildClassAndTermFilters(),
            const SizedBox(height: 24),
            _buildReportData(),
          ],
        ],
      ),
    );
  }

  Widget _buildStaffSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Staff',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<Staff>(
          value: _selectedStaff,
          hint: const Text('Select Staff'),
          items: widget.staffList
              .map((staff) => DropdownMenuItem(value: staff, child: Text(staff.name)))
              .toList(),
          onChanged: (staff) {
            setState(() {
              _selectedStaff = staff;
              _assignedClasses = [];
              _dueReportData = [];
            });
            if (staff != null) {
              _loadAssignedClasses(staff.name);
            }
          },
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Staff',
          ),
        ),
      ],
    );
  }

  Widget _buildClassAndTermFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Assigned Classes',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 12),
        _isLoadingClasses
            ? const Center(child: CircularProgressIndicator())
            : Wrap(
          spacing: 8,
          children: _assignedClasses.map((className) => Chip(label: Text(className))).toList(),
        ),
        const SizedBox(height: 24),
        Text(
          'Select Terms',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Checkbox(
              value: _term1Selected,
              onChanged: (value) => setState(() => _term1Selected = value!),
            ),
            const Text('Term 1'),
            Checkbox(
              value: _term2Selected,
              onChanged: (value) => setState(() => _term2Selected = value!),
            ),
            const Text('Term 2'),
            Checkbox(
              value: _term3Selected,
              onChanged: (value) => setState(() => _term3Selected = value!),
            ),
            const Text('Term 3'),
          ],
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _loadDueReportData,
          child: const Text('Generate Report'),
        ),
      ],
    );
  }

  Widget _buildReportData() {
    if (_isLoadingReport) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_dueReportData.isEmpty) {
      return const Center(child: Text('No due data available for the selected criteria.'));
    }

    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: _dueReportData.isEmpty ? null : _downloadDueReportExcel,
          icon: const Icon(Icons.download),
          label: const Text('Download Excel'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[600],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        const SizedBox(height: 16),
        _buildReportTable(),
      ],
    );
  }

  Widget _buildReportTable() {
    final columns = [
      const DataColumn(label: Text('Student Name')),
      const DataColumn(label: Text('Class')),
      const DataColumn(label: Text('Parent Mobile')),
      const DataColumn(label: Text('Staff Name')),
    ];
    if (_term1Selected) columns.add(const DataColumn(label: Text('Term 1 Due')));
    if (_term2Selected) columns.add(const DataColumn(label: Text('Term 2 Due')));
    if (_term3Selected) columns.add(const DataColumn(label: Text('Term 3 Due')));

    return DataTable(
      columns: columns,
      rows: _dueReportData.map((data) {
        final cells = [
          DataCell(Text(data['Student Name'])),
          DataCell(Text(data['Class'])),
          DataCell(Text(data['Parent Mobile'])),
          DataCell(Text(data['Staff Name'])),
        ];
        if (_term1Selected) {
          cells.add(DataCell(Text(data['Term1 Due']?.toString() ?? 'N/A')));
        }
        if (_term2Selected) {
          cells.add(DataCell(Text(data['Term2 Due']?.toString() ?? 'N/A')));
        }
        if (_term3Selected) {
          cells.add(DataCell(Text(data['Term3 Due']?.toString() ?? 'N/A')));
        }
        return DataRow(cells: cells);
      }).toList(),
    );
  }

  Future<void> _loadAssignedClasses(String staffName) async {
    setState(() => _isLoadingClasses = true);
    try {
      final classes = await SupabaseService.getClassesForStaff(staffName);
      setState(() {
        _assignedClasses = classes;
        _isLoadingClasses = false;
      });
    } catch (e) {
      setState(() => _isLoadingClasses = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading assigned classes: $e')),
      );
    }
  }

  Future<void> _loadDueReportData() async {
    if (_selectedStaff == null || _assignedClasses.isEmpty) return;

    setState(() => _isLoadingReport = true);

    try {
      final reportData = <Map<String, dynamic>>[];
      for (final className in _assignedClasses) {
        final students = await SupabaseService.getStudentsByClass(className);
        final studentNames = students.map((s) => s.name).toList();
        final allFeesByStudent = await SupabaseService.getFeesForStudents(studentNames);

        for (final student in students) {
          final fees = allFeesByStudent[student.name] ?? [];
          final feeStructure = await SupabaseService.getFeeStructureByClass(student.className.split('-').first);
          if (feeStructure == null || feeStructure.isEmpty) continue;

          final totalFee = double.tryParse(feeStructure['FEE']?.toString() ?? '0') ?? 0;
          final concession = student.schoolFeeConcession;
          final termFees = SupabaseService.calculateTermFees(totalFee, concession);

          final Map<String, dynamic> rowData = {
            'Student Name': student.name,
            'Class': student.className,
            'Parent Mobile': student.parentMobile,
            'Staff Name': _selectedStaff!.name,
          };

          if (_term1Selected) {
            final termPaidAmount = fees
                .where((f) =>
            (f['FEE TYPE'] as String? ?? '').trim().toLowerCase() == 'school fee' &&
                (f['TERM NO'] as String? ?? '').trim().contains('Term 1'))
                .fold<double>(0, (sum, f) => sum + (double.tryParse((f['AMOUNT'] as dynamic).toString()) ?? 0));
            final termDue = ((termFees[1] ?? 0.0) - termPaidAmount).clamp(0, double.infinity);
            rowData['Term1 Due'] = termDue.toStringAsFixed(2);
          }
          if (_term2Selected) {
            final termPaidAmount = fees
                .where((f) =>
            (f['FEE TYPE'] as String? ?? '').trim().toLowerCase() == 'school fee' &&
                (f['TERM NO'] as String? ?? '').trim().contains('Term 2'))
                .fold<double>(0, (sum, f) => sum + (double.tryParse((f['AMOUNT'] as dynamic).toString()) ?? 0));
            final termDue = ((termFees[2] ?? 0.0) - termPaidAmount).clamp(0, double.infinity);
            rowData['Term2 Due'] = termDue.toStringAsFixed(2);
          }
          if (_term3Selected) {
            final termPaidAmount = fees
                .where((f) =>
            (f['FEE TYPE'] as String? ?? '').trim().toLowerCase() == 'school fee' &&
                (f['TERM NO'] as String? ?? '').trim().contains('Term 3'))
                .fold<double>(0, (sum, f) => sum + (double.tryParse((f['AMOUNT'] as dynamic).toString()) ?? 0));
            final termDue = ((termFees[3] ?? 0.0) - termPaidAmount).clamp(0, double.infinity);
            rowData['Term3 Due'] = termDue.toStringAsFixed(2);
          }

          reportData.add(rowData);
        }
      }
      setState(() {
        _dueReportData = reportData;
        _isLoadingReport = false;
      });
    } catch (e) {
      setState(() => _isLoadingReport = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading due report: $e')),
      );
    }
  }

  Future<void> _downloadDueReportExcel() async {
    final excel = excel_pkg.Excel.createExcel();
    final sheet = excel['Sheet1'];

    final headers = ['Student Name', 'Class', 'Parent Mobile', 'Staff Name'];
    if (_term1Selected) headers.add('Term 1 Due');
    if (_term2Selected) headers.add('Term 2 Due');
    if (_term3Selected) headers.add('Term 3 Due');

    sheet.appendRow(headers);

    for (final data in _dueReportData) {
      final row = [
        data['Student Name'],
        data['Class'],
        data['Parent Mobile'],
        data['Staff Name'],
      ];
      if (_term1Selected) row.add(data['Term1 Due']);
      if (_term2Selected) row.add(data['Term2 Due']);
      if (_term3Selected) row.add(data['Term3 Due']);
      sheet.appendRow(row);
    }

    final bytes = excel.encode();
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error encoding Excel file')),
      );
      return;
    }

    final fileName = 'Due_Report_${DateFormat('yyyy-MM-dd_HHmmss').format(DateTime.now())}.xlsx';

    if (kIsWeb) {
      final uint8List = Uint8List.fromList(bytes);
      final blob = html.Blob([uint8List], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..target = 'blank'
        ..download = fileName;
      html.document.body?.append(anchor);
      anchor.click();
      html.Url.revokeObjectUrl(url);
      anchor.remove();
    } else {
      try {
        final directory = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$fileName');
        await file.writeAsBytes(bytes);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Downloaded: $fileName')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving file: $e')),
        );
      }
    }
  }
}

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
          if (_selectedStaff != null || _assignedClasses.isNotEmpty) ...[
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
        DropdownButtonFormField<dynamic>(
          value: _selectedStaff,
          hint: const Text('Select Staff'),
          items: [
            const DropdownMenuItem(value: 'all', child: Text('All Staff / All Classes')),
            ...widget.staffList
                .map((staff) => DropdownMenuItem(value: staff, child: Text(staff.name))),
          ],
          onChanged: (val) {
            setState(() {
              if (val is String) {
                _selectedStaff = null; // Represents 'All'
                _assignedClasses = [];
                _dueReportData = [];
              } else {
                _selectedStaff = val as Staff;
                _assignedClasses = [];
                _dueReportData = [];
              }
            });
            if (val is Staff) {
              _loadAssignedClasses(val.name);
            } else if (val == 'all') {
              _loadAllAssignedClasses();
            }
          },
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Staff Selection',
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
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: (_selectedStaff == null && _assignedClasses.isEmpty && !(_dueReportData.isEmpty && widget.staffList.isNotEmpty)) 
              ? null // This condition might need refinement if 'All' is selected
              : _loadDueReportData,
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
    final isAllStaff = _selectedStaff == null;

    final columns = isAllStaff ? [
      const DataColumn(label: Text('Staff Name')),
      const DataColumn(label: Text('Class Assigned')),
      const DataColumn(label: Text('Total School Fee')),
      const DataColumn(label: Text('Total Bus Fee')),
      const DataColumn(label: Text('Total Hostel Fee')),
      const DataColumn(label: Text('Total Fee')),
      const DataColumn(label: Text('Total Paid')),
      const DataColumn(label: Text('Total Pending')),
    ] : [
      const DataColumn(label: Text('Student Name')),
      const DataColumn(label: Text('Class')),
      const DataColumn(label: Text('Parent Mobile')),
      const DataColumn(label: Text('Staff Name')),
      const DataColumn(label: Text('Bus Fee')),
      const DataColumn(label: Text('Hostel Fee')),
      const DataColumn(label: Text('Total Fees')),
      const DataColumn(label: Text('Total Paid')),
      const DataColumn(label: Text('Total Pending')),
    ];

    if (!isAllStaff) {
      if (_term1Selected) columns.add(const DataColumn(label: Text('Term 1 Due')));
      if (_term2Selected) columns.add(const DataColumn(label: Text('Term 2 Due')));
      if (_term3Selected) columns.add(const DataColumn(label: Text('Term 3 Due')));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: columns,
        rows: _dueReportData.map((data) {
          if (isAllStaff) {
            return DataRow(cells: [
              DataCell(Text(data['Staff Name'] ?? '')),
              DataCell(Text(data['Class Assigned'] ?? '')),
              DataCell(Text(data['Total School Fee'] ?? '0.00')),
              DataCell(Text(data['Total Bus Fee'] ?? '0.00')),
              DataCell(Text(data['Total Hostel Fee'] ?? '0.00')),
              DataCell(Text(data['Total Fee'] ?? '0.00')),
              DataCell(Text(data['Total Paid'] ?? '0.00')),
              DataCell(Text(data['Total Pending'] ?? '0.00')),
            ]);
          }

          final cells = [
            DataCell(Text(data['Student Name'] ?? '')),
            DataCell(Text(data['Class'] ?? '')),
            DataCell(Text(data['Parent Mobile'] ?? '')),
            DataCell(Text(data['Staff Name'] ?? '')),
            DataCell(Text(data['Bus Fee'] ?? '0.00')),
            DataCell(Text(data['Hostel Fee'] ?? '0.00')),
            DataCell(Text(data['Total Fees'] ?? '0.00')),
            DataCell(Text(data['Total Paid'] ?? '0.00')),
            DataCell(Text(data['Total Pending'] ?? '0.00')),
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
      ),
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

  Future<void> _loadAllAssignedClasses() async {
    setState(() => _isLoadingClasses = true);
    try {
      final Set<String> allAssigned = {};
      for (final staff in widget.staffList) {
        final classes = await SupabaseService.getClassesForStaff(staff.name);
        allAssigned.addAll(classes);
      }
      setState(() {
        _assignedClasses = allAssigned.toList()..sort();
        _isLoadingClasses = false;
      });
    } catch (e) {
      setState(() => _isLoadingClasses = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading all assigned classes: $e')),
      );
    }
  }

  Future<void> _loadDueReportData() async {
    // Return early only if no selection has been made yet
    if (_selectedStaff == null && _assignedClasses.isEmpty && _dueReportData.isEmpty) return;

    setState(() => _isLoadingReport = true);

    try {
      final reportData = <Map<String, dynamic>>[];
      
      // 1. Determine which staff/classes to process
      final staffsToProcess = <(Staff, List<String>)>[];
      if (_selectedStaff != null) {
        staffsToProcess.add((_selectedStaff!, _assignedClasses));
      } else {
        // 'All' mode
        for (final staff in widget.staffList) {
          final classes = await SupabaseService.getClassesForStaff(staff.name);
          if (classes.isNotEmpty) {
            staffsToProcess.add((staff, classes));
          }
        }
      }

      if (staffsToProcess.isEmpty) {
        setState(() => _isLoadingReport = false);
        return;
      }

      // 2. Fetch all Master Data in parallel for O(1) local lookup
      final masterData = await Future.wait([
        SupabaseService.getAllFeeStructures(),
        SupabaseService.getAllTransport(),
        SupabaseService.getAllHostelFees(),
      ]);

      final feeStructures = {for (var f in masterData[0]) f['CLASS']?.toString() ?? '': f};
      final transportMap = {for (var t in masterData[1]) t['Route']?.toString() ?? '': t};
      final hostelMap = {for (var h in masterData[2]) h['CLASS']?.toString() ?? '': h};

      // 3. Collect all unique classes and students
      final allClassNames = staffsToProcess.expand((e) => e.$2.map((c) => c.trim())).toSet().toList();
      final allStudents = await SupabaseService.getStudentsByClasses(allClassNames);
      
      if (allStudents.isEmpty) {
        setState(() {
          _dueReportData = [];
          _isLoadingReport = false;
        });
        return;
      }

      // 4. Bulk fetch all fee records for all students
      final allStudentNames = allStudents.map((s) => s.name).toList();
      final allFeesByStudent = await SupabaseService.getFeesForStudents(allStudentNames);

      // 5. Create a map of Class -> Staff for quick lookup
      final classToStaffMap = <String, List<Staff>>{};
      for (final item in staffsToProcess) {
        final staff = item.$1;
        for (final className in item.$2) {
          classToStaffMap.putIfAbsent(className.trim(), () => []).add(staff);
        }
      }

      // 6. Process all data locally (High Speed)
      final isAllStaff = _selectedStaff == null;
      final Map<String, Map<String, dynamic>> summaryMap = {};

      if (isAllStaff) {
        // Initialize summaryMap with all assigned classes for each staff to ensure they show up even with 0 students
        for (final item in staffsToProcess) {
          final staff = item.$1;
          for (final className in item.$2) {
            final key = '${staff.name}|${className.trim()}';
            summaryMap[key] = {
              'Staff Name': staff.name,
              'Class Assigned': className.trim(),
              'Total School Fee': 0.0,
              'Total Bus Fee': 0.0,
              'Total Hostel Fee': 0.0,
              'Total Fee': 0.0,
              'Total Paid': 0.0,
              'Total Pending': 0.0,
            };
          }
        }
      }

      for (final student in allStudents) {
        final fees = allFeesByStudent[student.name] ?? [];
        final classTrimmed = student.className.trim();
        final classPrefix = classTrimmed.split('-').first;
        final feeStructure = feeStructures[classPrefix];
        
        if (feeStructure == null) continue;

        // Calculate School Fees
        final totalFee = double.tryParse(feeStructure['FEE']?.toString() ?? '0') ?? 0.0;
        final concession = student.schoolFeeConcession;
        final netSchoolFee = totalFee - concession;
        final termFees = SupabaseService.calculateTermFees(totalFee, concession);

        // Calculate Bus Fees
        final busRouteData = transportMap[student.busRoute];
        final totalBusFee = double.tryParse(busRouteData?['Fees']?.toString() ?? '0') ?? 0.0;
        final netBusFee = (totalBusFee - student.busFeeConcession).clamp(0.0, double.infinity).toDouble();

        // Calculate Hostel Fees
        final hostelData = hostelMap[classPrefix];
        final totalHostelFee = double.tryParse(hostelData?['HOSTEL_FEE']?.toString() ?? '0') ?? 0.0;
        final netHostelFee = (totalHostelFee - student.hostelFeeConcession).clamp(0.0, double.infinity).toDouble();

        final totalFees = netSchoolFee + netBusFee + netHostelFee;
        final totalPaid = fees.fold<double>(0, (sum, f) => sum + (double.tryParse((f['AMOUNT'] as dynamic).toString()) ?? 0));
        final totalPending = (totalFees - totalPaid).clamp(0.0, double.infinity).toDouble();

        if (isAllStaff) {
          final studentClass = student.className.trim();
          final associatedStaffs = classToStaffMap[studentClass] ?? [];
          final staffNames = associatedStaffs.isEmpty ? ['Unassigned'] : associatedStaffs.map((s) => s.name).toList();
          
          for (final sName in staffNames) {
            final key = '$sName|$studentClass';
            if (!summaryMap.containsKey(key)) {
              summaryMap[key] = {
                'Staff Name': sName,
                'Class Assigned': studentClass,
                'Total School Fee': 0.0,
                'Total Bus Fee': 0.0,
                'Total Hostel Fee': 0.0,
                'Total Fee': 0.0,
                'Total Paid': 0.0,
                'Total Pending': 0.0,
              };
            }
            summaryMap[key]!['Total School Fee'] += netSchoolFee;
            summaryMap[key]!['Total Bus Fee'] += netBusFee;
            summaryMap[key]!['Total Hostel Fee'] += netHostelFee;
            summaryMap[key]!['Total Fee'] += totalFees;
            summaryMap[key]!['Total Paid'] += totalPaid;
            summaryMap[key]!['Total Pending'] += totalPending;
          }
        } else {
          // Individual Student Row
          final rowBase = {
            'Student Name': student.name,
            'Class': student.className,
            'Parent Mobile': student.parentMobile,
            'Bus Fee': netBusFee.toStringAsFixed(2),
            'Hostel Fee': netHostelFee.toStringAsFixed(2),
            'Total Fees': totalFees.toStringAsFixed(2),
            'Total Paid': totalPaid.toStringAsFixed(2),
            'Total Pending': totalPending.toStringAsFixed(2),
          };

          // Term specific dues
          if (_term1Selected) {
            final termPaid = fees.where((f) => (f['FEE TYPE'] as String? ?? '').trim().toLowerCase() == 'school fee' && (f['TERM NO'] as String? ?? '').trim().contains('Term 1'))
                .fold<double>(0, (sum, f) => sum + (double.tryParse((f['AMOUNT'] as dynamic).toString()) ?? 0));
            rowBase['Term1 Due'] = ((termFees[1] ?? 0.0) - termPaid).clamp(0.0, double.infinity).toStringAsFixed(2);
          }
          if (_term2Selected) {
            final termPaid = fees.where((f) => (f['FEE TYPE'] as String? ?? '').trim().toLowerCase() == 'school fee' && (f['TERM NO'] as String? ?? '').trim().contains('Term 2'))
                .fold<double>(0, (sum, f) => sum + (double.tryParse((f['AMOUNT'] as dynamic).toString()) ?? 0));
            rowBase['Term2 Due'] = ((termFees[2] ?? 0.0) - termPaid).clamp(0.0, double.infinity).toStringAsFixed(2);
          }
          if (_term3Selected) {
            final termPaid = fees.where((f) => (f['FEE TYPE'] as String? ?? '').trim().toLowerCase() == 'school fee' && (f['TERM NO'] as String? ?? '').trim().contains('Term 3'))
                .fold<double>(0, (sum, f) => sum + (double.tryParse((f['AMOUNT'] as dynamic).toString()) ?? 0));
            rowBase['Term3 Due'] = ((termFees[3] ?? 0.0) - termPaid).clamp(0.0, double.infinity).toStringAsFixed(2);
          }

          final associatedStaffs = classToStaffMap[student.className.trim()] ?? [];
          if (associatedStaffs.isEmpty) {
            reportData.add({...rowBase, 'Staff Name': 'Unassigned'});
          } else {
            for (final staff in associatedStaffs) {
              reportData.add({...rowBase, 'Staff Name': staff.name});
            }
          }
        }
      }

      if (isAllStaff) {
        final List<Map<String, dynamic>> summaryList = summaryMap.values.toList();
        // Sort by Staff Name, then by Class Assigned
        summaryList.sort((a, b) {
          int cmp = (a['Staff Name'] as String).compareTo(b['Staff Name'] as String);
          if (cmp != 0) return cmp;
          return (a['Class Assigned'] as String).compareTo(b['Class Assigned'] as String);
        });

        for (final entry in summaryList) {
          reportData.add({
            'Staff Name': entry['Staff Name'],
            'Class Assigned': entry['Class Assigned'],
            'Total School Fee': (entry['Total School Fee'] as double).toStringAsFixed(2),
            'Total Bus Fee': (entry['Total Bus Fee'] as double).toStringAsFixed(2),
            'Total Hostel Fee': (entry['Total Hostel Fee'] as double).toStringAsFixed(2),
            'Total Fee': (entry['Total Fee'] as double).toStringAsFixed(2),
            'Total Paid': (entry['Total Paid'] as double).toStringAsFixed(2),
            'Total Pending': (entry['Total Pending'] as double).toStringAsFixed(2),
          });
        }
      }

      setState(() {
        _dueReportData = reportData;
        _isLoadingReport = false;
      });
    } catch (e) {
      print('Error generating due report: $e');
      setState(() => _isLoadingReport = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _downloadDueReportExcel() async {
    final excel = excel_pkg.Excel.createExcel();
    final sheet = excel['Sheet1'];

    final isAllStaff = _selectedStaff == null;
    final headers = isAllStaff ? ['Staff Name', 'Class Assigned', 'Total School Fee', 'Total Bus Fee', 'Total Hostel Fee', 'Total Fee', 'Total Paid', 'Total Pending'] : ['Student Name', 'Class', 'Parent Mobile', 'Staff Name', 'Bus Fee', 'Hostel Fee', 'Total Fees', 'Total Paid', 'Total Pending'];
    
    if (!isAllStaff) {
      if (_term1Selected) headers.add('Term 1 Due');
      if (_term2Selected) headers.add('Term 2 Due');
      if (_term3Selected) headers.add('Term 3 Due');
    }

    sheet.appendRow(headers);

    for (final data in _dueReportData) {
      final List<dynamic> row;
      if (isAllStaff) {
        row = [
          data['Staff Name'],
          data['Class Assigned'],
          data['Total School Fee'],
          data['Total Bus Fee'],
          data['Total Hostel Fee'],
          data['Total Fee'],
          data['Total Paid'],
          data['Total Pending'],
        ];
      } else {
        row = [
          data['Student Name'],
          data['Class'],
          data['Parent Mobile'],
          data['Staff Name'],
          data['Bus Fee'],
          data['Hostel Fee'],
          data['Total Fees'],
          data['Total Paid'],
          data['Total Pending'],
        ];
        if (_term1Selected) row.add(data['Term1 Due']);
        if (_term2Selected) row.add(data['Term2 Due']);
        if (_term3Selected) row.add(data['Term3 Due']);
      }
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

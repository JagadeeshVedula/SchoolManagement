import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:school_management/models/student.dart';
import 'package:school_management/services/supabase_service.dart';
import 'package:excel/excel.dart' as excel_package;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class StaffStudentDetailsScreen extends StatefulWidget {
  final String staffName;

  const StaffStudentDetailsScreen({super.key, required this.staffName});

  @override
  State<StaffStudentDetailsScreen> createState() => _StaffStudentDetailsScreenState();
}

class _StaffStudentDetailsScreenState extends State<StaffStudentDetailsScreen> {
  bool _isLoading = true;
  List<String> _classes = [];
  String? _selectedClass;
  List<Student> _students = [];
  Map<String, List<Map<String, dynamic>>> _feesMap = {};
  Map<String, double> _duesMap = {};
  Map<String, Map<String, dynamic>> _busHostelFeesMap = {};

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isLoading = true);
    try {
      final classes = await SupabaseService.getClassesForStaff(widget.staffName);
      setState(() {
        _classes = classes;
        if (_classes.isNotEmpty) {
          _selectedClass = _classes.first;
        }
      });
      if (_selectedClass != null) {
        await _fetchStudentsForClass(_selectedClass!);
      }
    } catch (e) {
      print('Error fetching initial data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchStudentsForClass(String className) async {
    setState(() => _isLoading = true);
    try {
      final students = await SupabaseService.getStudentsByClass(className);
      final studentNames = students.map((s) => s.name).toList();
      Map<String, List<Map<String, dynamic>>> feesMap = {};
      if (studentNames.isNotEmpty) {
        feesMap = await SupabaseService.getFeesForStudents(studentNames);
      }
      Map<String, double> duesMap = {};
      Map<String, double> routeFees = {};
      Map<String, Map<String, dynamic>> busHostelFeesMap = {};
      final classBase = className.split('-').first;
      final structure = await SupabaseService.getFeeStructureByClass(classBase);
      final totalFee = structure != null ? (double.tryParse((structure['FEE'] as dynamic).toString()) ?? 0.0) : 0.0;
      
      for (final s in students) {
        final concession = s.schoolFeeConcession.toDouble();
        final termFees = SupabaseService.calculateTermFees(totalFee, concession);
        final studentFees = feesMap[s.name] ?? [];
        
        double studentTotalDue = 0.0;
        for (int term = 1; term <= 3; term++) {
          final termKeyFull = 'term $term';
          double paidAmount = 0;
          for (final fee in studentFees) {
            final feeType = (fee['FEE TYPE'] as String? ?? '').toLowerCase().trim();
            final termNo = (fee['TERM NO'] as String? ?? '').toLowerCase().trim();
            if (feeType.contains('school fee') && termNo.contains(termKeyFull)) {
              paidAmount += double.tryParse((fee['AMOUNT'] as dynamic).toString()) ?? 0;
            }
          }
          final termFee = termFees[term]!;
          if (paidAmount < termFee) {
            studentTotalDue += (termFee - paidAmount);
          }
        }
        
        // Calculate bus fees
        double busFeeTotal = 0;
        double busPaidAmount = 0;
        if (s.busRoute != null && s.busRoute!.isNotEmpty) {
          busPaidAmount = studentFees
              .where((f) => (f['FEE TYPE'] as String? ?? '').toLowerCase().contains('bus fee'))
              .fold<double>(0, (sum, f) => sum + (double.tryParse((f['AMOUNT'] as dynamic).toString()) ?? 0));
          if (!routeFees.containsKey(s.busRoute!)) {
            routeFees[s.busRoute!] = await SupabaseService.getBusFeeByRoute(s.busRoute!);
          }
          busFeeTotal = routeFees[s.busRoute!]!;
        }
        double busFeeDue = (busFeeTotal - busPaidAmount).clamp(0, double.infinity);
        studentTotalDue += busFeeDue;
        
        // Calculate hostel fees
        double hostelFeeTotal = 0;
        double hostelPaidAmount = 0;
        if (s.hostelFacility?.toUpperCase() == 'YES' && s.hostelType != null && s.hostelType!.isNotEmpty) {
          hostelPaidAmount = studentFees
              .where((f) => (f['FEE TYPE'] as String? ?? '').toLowerCase().contains('hostel fee'))
              .fold<double>(0, (sum, f) => sum + (double.tryParse((f['AMOUNT'] as dynamic).toString()) ?? 0));
          hostelFeeTotal = await SupabaseService.getHostelFeeByClassAndType(classBase, s.hostelType!);
        }
        double hostelFeeDue = (hostelFeeTotal - hostelPaidAmount).clamp(0, double.infinity);
        studentTotalDue += hostelFeeDue;
        
        duesMap[s.name] = studentTotalDue;
        busHostelFeesMap[s.name] = {
          'busAvailed': s.busFacility?.toUpperCase() == 'YES',
          'busFeeTotal': busFeeTotal,
          'busPaid': busPaidAmount,
          'busDue': busFeeDue,
          'busRoute': s.busRoute ?? 'N/A',
          'hostelAvailed': s.hostelFacility?.toUpperCase() == 'YES',
          'hostelFeeTotal': hostelFeeTotal,
          'hostelPaid': hostelPaidAmount,
          'hostelDue': hostelFeeDue,
          'hostelType': s.hostelType ?? 'N/A',
        };
      }

      setState(() {
        _students = students;
        _feesMap = feesMap;
        _duesMap = duesMap;
        _busHostelFeesMap = busHostelFeesMap;
      });
    } catch (e) {
      print('Error fetching students: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  double _calculateTotalPaid(String studentName) {
    final fees = _feesMap[studentName] ?? [];
    double total = 0.0;
    for (final fee in fees) {
      total += double.tryParse(fee['AMOUNT']?.toString() ?? '0') ?? 0.0;
    }
    return total;
  }

  Map<int, Map<String, double>> _calculateTermBreakdown(Student student) {
    final fees = _feesMap[student.name] ?? [];
    final concession = student.schoolFeeConcession.toDouble();
    
    // Initialize term data
    Map<int, Map<String, double>> termData = {
      1: {'Total': 0, 'Paid': 0, 'Due': 0},
      2: {'Total': 0, 'Paid': 0, 'Due': 0},
      3: {'Total': 0, 'Paid': 0, 'Due': 0},
    };

    // This would normally get the total fee from structure, for now using a default
    double totalFee = 50000; // Default value, should be fetched from fee structure
    final termFees = SupabaseService.calculateTermFees(totalFee, concession);

    for (int term = 1; term <= 3; term++) {
      termData[term]!['Total'] = termFees[term] ?? 0.0;
      
      double paidAmount = 0;
      for (final fee in fees) {
        final feeType = (fee['FEE TYPE'] as String? ?? '').toLowerCase().trim();
        final termNo = (fee['TERM NO'] as String? ?? '').toLowerCase().trim();
        if (feeType.contains('school fee') && termNo.contains('term $term')) {
          paidAmount += double.tryParse((fee['AMOUNT'] as dynamic).toString()) ?? 0;
        }
      }
      
      termData[term]!['Paid'] = paidAmount;
      termData[term]!['Due'] = (termData[term]!['Total']! - paidAmount).clamp(0, double.infinity);
    }

    return termData;
  }

  Map<String, dynamic> _calculateBusAndHostelFees(Student student) {
    return _busHostelFeesMap[student.name] ?? {
      'busAvailed': false,
      'busFeeTotal': 0,
      'busPaid': 0,
      'busDue': 0,
      'busRoute': 'N/A',
      'hostelAvailed': false,
      'hostelFeeTotal': 0,
      'hostelPaid': 0,
      'hostelDue': 0,
      'hostelType': 'N/A',
    };
  }

  Widget _buildTermsRow(Map<int, Map<String, double>> termBreakdown) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (int term = 1; term <= 3; term++)
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue[50]!, Colors.blue[100]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[300]!, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Term $term',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[900],
                      ),
                    ),
                    Text(
                      'P: ₹${(termBreakdown[term]?['Paid'] ?? 0).toStringAsFixed(0)}',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.green[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'D: ₹${(termBreakdown[term]?['Due'] ?? 0).toStringAsFixed(0)}',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.red[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBusHostelRow(Map<String, dynamic> busHostelInfo) {
    return Row(
      children: [
        if (busHostelInfo['busAvailed'])
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange[50]!, Colors.orange[100]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[300]!, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Bus: ${busHostelInfo['busRoute']}',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange[900],
                    ),
                  ),
                  Text(
                    'P: ₹${(busHostelInfo['busPaid']).toStringAsFixed(0)}',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      color: Colors.green[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    'D: ₹${(busHostelInfo['busDue']).toStringAsFixed(0)}',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      color: Colors.red[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (busHostelInfo['busAvailed'])
          const SizedBox(width: 8),
        if (busHostelInfo['hostelAvailed'])
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple[50]!, Colors.purple[100]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple[300]!, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Hostel: ${busHostelInfo['hostelType']}',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.purple[900],
                    ),
                  ),
                  Text(
                    'P: ₹${(busHostelInfo['hostelPaid']).toStringAsFixed(0)}',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      color: Colors.green[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    'D: ₹${(busHostelInfo['hostelDue']).toStringAsFixed(0)}',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      color: Colors.red[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _exportToExcel() async {
    try {
      var excel = excel_package.Excel.createExcel();
      excel_package.Sheet sheetObject = excel['Sheet1'];

      // Add headers
      List<String> headers = [
        'Student Name',
        'Class',
        'Father Name',
        'Mother Name',
        'Parent Mobile',
        'Term 1 Total',
        'Term 1 Paid',
        'Term 1 Due',
        'Term 2 Total',
        'Term 2 Paid',
        'Term 2 Due',
        'Term 3 Total',
        'Term 3 Paid',
        'Term 3 Due',
        'Bus Route',
        'Bus Total',
        'Bus Paid',
        'Bus Due',
        'Hostel Type',
        'Hostel Total',
        'Hostel Paid',
        'Hostel Due',
        'Total Due',
      ];

      for (int i = 0; i < headers.length; i++) {
        var cell = sheetObject.cell(excel_package.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = headers[i];
      }

      // Add student data
      for (int i = 0; i < _students.length; i++) {
        final student = _students[i];
        final termBreakdown = _calculateTermBreakdown(student);
        final busHostelInfo = _calculateBusAndHostelFees(student);

        List<dynamic> row = [
          student.name,
          student.className,
          student.fatherName,
          student.motherName,
          student.parentMobile,
          termBreakdown[1]?['Total'] ?? 0,
          termBreakdown[1]?['Paid'] ?? 0,
          termBreakdown[1]?['Due'] ?? 0,
          termBreakdown[2]?['Total'] ?? 0,
          termBreakdown[2]?['Paid'] ?? 0,
          termBreakdown[2]?['Due'] ?? 0,
          termBreakdown[3]?['Total'] ?? 0,
          termBreakdown[3]?['Paid'] ?? 0,
          termBreakdown[3]?['Due'] ?? 0,
          busHostelInfo['busRoute'],
          busHostelInfo['busFeeTotal'],
          busHostelInfo['busPaid'],
          busHostelInfo['busDue'],
          busHostelInfo['hostelType'],
          busHostelInfo['hostelFeeTotal'],
          busHostelInfo['hostelPaid'],
          busHostelInfo['hostelDue'],
          _duesMap[student.name] ?? 0,
        ];

        for (int j = 0; j < row.length; j++) {
          var cell = sheetObject.cell(excel_package.CellIndex.indexByColumnRow(columnIndex: j, rowIndex: i + 1));
          cell.value = row[j];
        }
      }

      // Save file
      final output = await getApplicationDocumentsDirectory();
      final fileName = 'StudentDetails_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final filePath = '${output.path}/$fileName';
      
      List<int>? fileBytes = excel.encode();
      if (fileBytes != null) {
        File(filePath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(fileBytes);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Excel file saved to: $filePath'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      print('Error exporting to Excel: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Student Details',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue[800],
        elevation: 2,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_students.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Center(
                child: ElevatedButton.icon(
                  onPressed: _exportToExcel,
                  icon: const Icon(Icons.download, size: 18),
                  label: Text(
                    'Export',
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue[50]!, Colors.cyan[50]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: _isLoading && _classes.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _classes.isEmpty
                ? Center(
                    child: Text(
                      'No classes assigned to you.',
                      style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[700]),
                    ),
                  )
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: DropdownButtonFormField<String>(
                          value: _selectedClass,
                          decoration: InputDecoration(
                            labelText: 'Select Class',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items: _classes.map((c) {
                            return DropdownMenuItem(value: c, child: Text(c));
                          }).toList(),
                          onChanged: (value) {
                            if (value != null && value != _selectedClass) {
                              setState(() {
                                _selectedClass = value;
                              });
                              _fetchStudentsForClass(value);
                            }
                          },
                        ),
                      ),
                      Expanded(
                        child: _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : _students.isEmpty
                                ? Center(
                                    child: Text(
                                      'No students found in $_selectedClass',
                                      style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[700]),
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    itemCount: _students.length,
                                    itemBuilder: (context, index) {
                                      final student = _students[index];
                                      final totalPaid = _calculateTotalPaid(student.name);
                                      final termBreakdown = _calculateTermBreakdown(student);
                                      final busHostelInfo = _calculateBusAndHostelFees(student);
                                      return Card(
                                        elevation: 3,
                                        margin: const EdgeInsets.only(bottom: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // Header with name and avatar
                                              Row(
                                                children: [
                                                  CircleAvatar(
                                                    backgroundColor: Colors.blue[100],
                                                    radius: 24,
                                                    child: Text(
                                                      student.name.isNotEmpty
                                                          ? student.name.substring(0, 1).toUpperCase()
                                                          : '?',
                                                      style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.bold, fontSize: 20),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          student.name,
                                                          style: GoogleFonts.poppins(
                                                            fontWeight: FontWeight.w700,
                                                            fontSize: 16,
                                                          ),
                                                        ),
                                                        Text(
                                                          student.className,
                                                          style: GoogleFonts.inter(
                                                            fontSize: 12,
                                                            color: Colors.grey[600],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 12),
                                              // Total payment status
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                      decoration: BoxDecoration(
                                                        gradient: LinearGradient(
                                                          colors: [Colors.green[50]!, Colors.green[100]!],
                                                          begin: Alignment.topLeft,
                                                          end: Alignment.bottomRight,
                                                        ),
                                                        borderRadius: BorderRadius.circular(8),
                                                        border: Border.all(color: Colors.green[300]!, width: 1),
                                                      ),
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            'Total Paid',
                                                            style: GoogleFonts.poppins(
                                                              fontSize: 10,
                                                              fontWeight: FontWeight.w600,
                                                              color: Colors.green[900],
                                                            ),
                                                          ),
                                                          Text(
                                                            '₹${totalPaid.toStringAsFixed(0)}',
                                                            style: GoogleFonts.inter(
                                                              fontSize: 14,
                                                              fontWeight: FontWeight.w700,
                                                              color: Colors.green[700],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                      decoration: BoxDecoration(
                                                        gradient: LinearGradient(
                                                          colors: [Colors.red[50]!, Colors.red[100]!],
                                                          begin: Alignment.topLeft,
                                                          end: Alignment.bottomRight,
                                                        ),
                                                        borderRadius: BorderRadius.circular(8),
                                                        border: Border.all(color: Colors.red[300]!, width: 1),
                                                      ),
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            'Total Due',
                                                            style: GoogleFonts.poppins(
                                                              fontSize: 10,
                                                              fontWeight: FontWeight.w600,
                                                              color: Colors.red[900],
                                                            ),
                                                          ),
                                                          Text(
                                                            '₹${(_duesMap[student.name] ?? 0.0).toStringAsFixed(0)}',
                                                            style: GoogleFonts.inter(
                                                              fontSize: 14,
                                                              fontWeight: FontWeight.w700,
                                                              color: Colors.red[700],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 12),
                                              // Terms breakdown
                                              Text(
                                                'Term-wise Fees',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.blue[900],
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              _buildTermsRow(termBreakdown),
                                              const SizedBox(height: 12),
                                              // Bus and Hostel fees
                                              Text(
                                                'Bus & Hostel Fees',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.blue[900],
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              _buildBusHostelRow(busHostelInfo),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

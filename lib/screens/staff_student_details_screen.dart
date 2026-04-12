import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:school_management/models/student.dart';
import 'package:school_management/services/supabase_service.dart';
import 'package:excel/excel.dart' as excel_package;
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:school_management/utils/platform_file_saver.dart';

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
  Map<String, Map<int, Map<String, dynamic>>> _termLastPaidDataMap = {};

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
      Map<String, Map<String, dynamic>> busHostelFeesMap = {};
      Map<String, Map<int, Map<String, dynamic>>> termLastPaidDataMap = {};
      
      final classBase = className.split('-').first;
      final structure = await SupabaseService.getFeeStructureByClass(classBase);
      final totalFee = structure != null ? (double.tryParse((structure['FEE'] as dynamic).toString()) ?? 0.0) : 0.0;
      
      Map<String, double> routeFees = {};
      
      for (final s in students) {
        final concession = s.schoolFeeConcession.toDouble();
        final termFees = SupabaseService.calculateTermFees(totalFee, concession);
        final studentFees = feesMap[s.name] ?? [];
        
        Map<int, Map<String, dynamic>> termLastPaidDatesMap = {};
        double studentTotalDue = 0.0;
        
        // 1. School Fees (Terms 1, 2, 3)
        for (int term = 1; term <= 3; term++) {
          double paidAmount = 0;
          List<Map<String, dynamic>> termPayments = [];
          
          for (final fee in studentFees) {
            final feeType = (fee['FEE TYPE'] as String? ?? '').toLowerCase();
            final termNoDb = (fee['TERM NO'] as String? ?? '').toLowerCase();
            
            // Loosen matching: Check if fee type contains 'school' and termNo contains 'term' + term number
            bool isSchoolFee = feeType.contains('school');
            bool isCorrectTerm = termNoDb.contains('term') && termNoDb.contains(term.toString());
            
            if (isSchoolFee && isCorrectTerm) {
              paidAmount += double.tryParse((fee['AMOUNT'] as dynamic).toString()) ?? 0.0;
              termPayments.add(fee);
            }
          }

          String? lastPaidDate;
          Map<String, dynamic>? lastPayment;
          if (termPayments.isNotEmpty) {
            termPayments.sort((a, b) {
              DateTime parseDate(Map<String, dynamic> f) {
                // Try created_at timestamp first
                if (f['created_at'] != null) {
                   try { return DateTime.parse(f['created_at'].toString()); } catch (_) {}
                }
                // Try DATE column (text)
                if (f['DATE'] != null) {
                  try {
                    return DateFormat('dd-MM-yyyy').parse(f['DATE'].toString());
                  } catch (_) {
                    try {
                      return DateFormat('yyyy-MM-dd').parse(f['DATE'].toString());
                    } catch (_) {}
                  }
                }
                return DateTime(2000);
              }
              return parseDate(b).compareTo(parseDate(a));
            });
            lastPayment = termPayments.first;
            
            // Extract the date properly from whichever column is available
            final dynamic rawDate = lastPayment['DATE'] ?? lastPayment['created_at'];
            if (rawDate != null) {
              final String dateStr = rawDate.toString();
              if (dateStr.length > 10) {
                try {
                  lastPaidDate = DateFormat('dd-MM-yyyy').format(DateTime.parse(dateStr));
                } catch (_) {
                  lastPaidDate = dateStr.split('T').first;
                }
              } else {
                lastPaidDate = dateStr;
              }
            }
          }

          final termFee = termFees[term]!;
          final termDue = (termFee - paidAmount).clamp(0, double.infinity);
          
          termLastPaidDatesMap[term] = {
            'Total': termFee,
            'Paid': paidAmount,
            'Due': termDue,
            'Date': lastPaidDate,
            'Payment': lastPayment,
          };
          
          studentTotalDue += termDue;
        }
        termLastPaidDataMap[s.name] = termLastPaidDatesMap;
        
        // 2. Bus Fees
        double busFeeTotal = 0;
        double busPaidAmount = 0;
        String? busLastPaidDate;
        Map<String, dynamic>? latestBusPayment;
        
        if (s.busFacility?.toUpperCase() == 'YES' && s.busRoute != null && s.busRoute!.isNotEmpty) {
          final busFees = studentFees
              .where((f) => (f['FEE TYPE'] as String? ?? '').toLowerCase().contains('bus fee'))
              .toList();
          
          busPaidAmount = busFees.fold<double>(0, (sum, f) => sum + (double.tryParse((f['AMOUNT'] as dynamic).toString()) ?? 0));
          
          if (busFees.isNotEmpty) {
            busFees.sort((a, b) {
              final dateA = a['created_at'] != null ? DateTime.parse(a['created_at'].toString()) : DateTime(2000);
              final dateB = b['created_at'] != null ? DateTime.parse(b['created_at'].toString()) : DateTime(2000);
              return dateB.compareTo(dateA);
            });
            latestBusPayment = busFees.first;
            final latestDate = latestBusPayment['created_at'];
            if (latestDate != null) {
              busLastPaidDate = DateFormat('dd-MM-yyyy').format(DateTime.parse(latestDate.toString()));
            }
          }

          if (!routeFees.containsKey(s.busRoute!)) {
            routeFees[s.busRoute!] = await SupabaseService.getBusFeeByRoute(s.busRoute!);
          }
          busFeeTotal = routeFees[s.busRoute!]!;
        }
        double busFeeDue = (busFeeTotal - busPaidAmount).clamp(0, double.infinity);
        studentTotalDue += busFeeDue;

        // 3. Hostel Fees
        double hostelFeeTotal = 0;
        double hostelPaidAmount = 0;
        String? hostelLastPaidDate;
        Map<String, dynamic>? latestHostelPayment;
        
        if (s.hostelFacility?.toUpperCase() == 'YES' && s.hostelType != null && s.hostelType!.isNotEmpty) {
          final hostelFees = studentFees
              .where((f) => (f['FEE TYPE'] as String? ?? '').toLowerCase().contains('hostel fee'))
              .toList();

          hostelPaidAmount = hostelFees.fold<double>(0, (sum, f) => sum + (double.tryParse((f['AMOUNT'] as dynamic).toString()) ?? 0));

          if (hostelFees.isNotEmpty) {
            hostelFees.sort((a, b) {
              final dateA = a['created_at'] != null ? DateTime.parse(a['created_at'].toString()) : DateTime(2000);
              final dateB = b['created_at'] != null ? DateTime.parse(b['created_at'].toString()) : DateTime(2000);
              return dateB.compareTo(dateA);
            });
            latestHostelPayment = hostelFees.first;
            final latestDate = latestHostelPayment['created_at'];
            if (latestDate != null) {
              hostelLastPaidDate = DateFormat('dd-MM-yyyy').format(DateTime.parse(latestDate.toString()));
            }
          }
          hostelFeeTotal = await SupabaseService.getHostelFeeByClassAndType(classBase, s.hostelType!);
        }
        
        double hostelFeeDue = (hostelFeeTotal - hostelPaidAmount).clamp(0, double.infinity);
        studentTotalDue += hostelFeeDue;
        
        duesMap[s.name] = studentTotalDue;
        
        busHostelFeesMap[s.name] = {
          'busAvailed': s.busFacility?.toUpperCase() == 'YES',
          'busRoute': s.busRoute ?? 'N/A',
          'busFeeTotal': busFeeTotal,
          'busPaid': busPaidAmount,
          'busDue': busFeeDue,
          'busLastPaid': busLastPaidDate,
          'busPayment': latestBusPayment,
          'hostelAvailed': s.hostelFacility?.toUpperCase() == 'YES',
          'hostelType': s.hostelType ?? 'N/A',
          'hostelFeeTotal': hostelFeeTotal,
          'hostelPaid': hostelPaidAmount,
          'hostelDue': hostelFeeDue,
          'hostelLastPaid': hostelLastPaidDate,
          'hostelPayment': latestHostelPayment,
        };
      }
      
      setState(() {
        _students = students;
        _feesMap = feesMap;
        _duesMap = duesMap;
        _busHostelFeesMap = busHostelFeesMap;
        _termLastPaidDataMap = termLastPaidDataMap;
        _isLoading = false;
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

  Map<int, Map<String, dynamic>> _calculateTermBreakdown(Student student) {
    return _termLastPaidDataMap[student.name] ?? {
      1: {'Total': 0.0, 'Paid': 0.0, 'Due': 0.0, 'Date': null},
      2: {'Total': 0.0, 'Paid': 0.0, 'Due': 0.0, 'Date': null},
      3: {'Total': 0.0, 'Paid': 0.0, 'Due': 0.0, 'Date': null},
    };
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

  Widget _buildTermsRow(Map<int, Map<String, dynamic>> termBreakdown) {
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
                    if (termBreakdown[term]?['Date'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Date: ${termBreakdown[term]?['Date']}',
                              style: GoogleFonts.inter(
                                fontSize: 8,
                                color: Colors.blueGrey[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                final payment = termBreakdown[term]?['Payment'];
                                if (payment != null) {
                                  _showReceipt(payment);
                                }
                              },
                              child: Icon(Icons.receipt, size: 12, color: Colors.blue[600]),
                            ),
                          ],
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

  void _showReceipt(Map<String, dynamic> payment) {
    // Navigate to a screen or dialog that shows the receipt
    // Since we are in staff_student_details_screen, we can't easily access FeesTab's dialog
    // But we can show a simple dialog here
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Payment Receipt', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Receipt Date: ${payment['DATE']}', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Fee Type: ${payment['FEE TYPE']}'),
            Text('Term No: ${payment['TERM NO']}'),
            const Divider(),
            Text('Amount Paid: ₹${payment['AMOUNT']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
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
                  if (busHostelInfo['busLastPaid'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Date: ${busHostelInfo['busLastPaid']}',
                            style: GoogleFonts.inter(
                              fontSize: 8,
                              color: Colors.blueGrey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              final payment = busHostelInfo['busPayment'];
                              if (payment != null) {
                                _showReceipt(payment);
                              }
                            },
                            child: Icon(Icons.receipt, size: 12, color: Colors.orange[600]),
                          ),
                        ],
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
                  if (busHostelInfo['hostelLastPaid'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Date: ${busHostelInfo['hostelLastPaid']}',
                            style: GoogleFonts.inter(
                              fontSize: 8,
                              color: Colors.blueGrey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              final payment = busHostelInfo['hostelPayment'];
                              if (payment != null) {
                                _showReceipt(payment);
                              }
                            },
                            child: Icon(Icons.receipt, size: 12, color: Colors.purple[600]),
                          ),
                        ],
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
        'Term 1 Paid Date',
        'Term 2 Total',
        'Term 2 Paid',
        'Term 2 Due',
        'Term 2 Paid Date',
        'Term 3 Total',
        'Term 3 Paid',
        'Term 3 Due',
        'Term 3 Paid Date',
        'Bus Route',
        'Bus Total',
        'Bus Paid',
        'Bus Due',
        'Bus Paid Date',
        'Hostel Type',
        'Hostel Total',
        'Hostel Paid',
        'Hostel Due',
        'Hostel Paid Date',
        'Total Due',
      ];

      for (int i = 0; i < headers.length; i++) {
        var cell = sheetObject.cell(excel_package.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = headers[i];
      }

      // Add student data
      double t1TotalSum = 0, t1PaidSum = 0, t1DueSum = 0;
      double t2TotalSum = 0, t2PaidSum = 0, t2DueSum = 0;
      double t3TotalSum = 0, t3PaidSum = 0, t3DueSum = 0;
      double busTotalSum = 0, busPaidSum = 0, busDueSum = 0;
      double hostelTotalSum = 0, hostelPaidSum = 0, hostelDueSum = 0;
      double totalDueSum = 0;

      for (int i = 0; i < _students.length; i++) {
        final student = _students[i];
        final termBreakdown = _calculateTermBreakdown(student);
        final busHostelInfo = _calculateBusAndHostelFees(student);
        final studentTotalDue = _duesMap[student.name] ?? 0;

        t1TotalSum += (termBreakdown[1]?['Total'] as num?)?.toDouble() ?? 0;
        t1PaidSum += (termBreakdown[1]?['Paid'] as num?)?.toDouble() ?? 0;
        t1DueSum += (termBreakdown[1]?['Due'] as num?)?.toDouble() ?? 0;
        t2TotalSum += (termBreakdown[2]?['Total'] as num?)?.toDouble() ?? 0;
        t2PaidSum += (termBreakdown[2]?['Paid'] as num?)?.toDouble() ?? 0;
        t2DueSum += (termBreakdown[2]?['Due'] as num?)?.toDouble() ?? 0;
        t3TotalSum += (termBreakdown[3]?['Total'] as num?)?.toDouble() ?? 0;
        t3PaidSum += (termBreakdown[3]?['Paid'] as num?)?.toDouble() ?? 0;
        t3DueSum += (termBreakdown[3]?['Due'] as num?)?.toDouble() ?? 0;

        busTotalSum += (busHostelInfo['busFeeTotal'] as num?)?.toDouble() ?? 0;
        busPaidSum += (busHostelInfo['busPaid'] as num?)?.toDouble() ?? 0;
        busDueSum += (busHostelInfo['busDue'] as num?)?.toDouble() ?? 0;

        hostelTotalSum += (busHostelInfo['hostelFeeTotal'] as num?)?.toDouble() ?? 0;
        hostelPaidSum += (busHostelInfo['hostelPaid'] as num?)?.toDouble() ?? 0;
        hostelDueSum += (busHostelInfo['hostelDue'] as num?)?.toDouble() ?? 0;

        totalDueSum += studentTotalDue;

        List<dynamic> row = [
          student.name,
          student.className,
          student.fatherName,
          student.motherName,
          student.parentMobile,
          termBreakdown[1]?['Total'] ?? 0,
          termBreakdown[1]?['Paid'] ?? 0,
          termBreakdown[1]?['Due'] ?? 0,
          termBreakdown[1]?['Date'] ?? 'N/A',
          termBreakdown[2]?['Total'] ?? 0,
          termBreakdown[2]?['Paid'] ?? 0,
          termBreakdown[2]?['Due'] ?? 0,
          termBreakdown[2]?['Date'] ?? 'N/A',
          termBreakdown[3]?['Total'] ?? 0,
          termBreakdown[3]?['Paid'] ?? 0,
          termBreakdown[3]?['Due'] ?? 0,
          termBreakdown[3]?['Date'] ?? 'N/A',
          busHostelInfo['busRoute'],
          busHostelInfo['busFeeTotal'],
          busHostelInfo['busPaid'],
          busHostelInfo['busDue'],
          busHostelInfo['busLastPaid'] ?? 'N/A',
          busHostelInfo['hostelType'],
          busHostelInfo['hostelFeeTotal'],
          busHostelInfo['hostelPaid'],
          busHostelInfo['hostelDue'],
          busHostelInfo['hostelLastPaid'] ?? 'N/A',
          studentTotalDue,
        ];

        for (int j = 0; j < row.length; j++) {
          var cell = sheetObject.cell(excel_package.CellIndex.indexByColumnRow(columnIndex: j, rowIndex: i + 1));
          cell.value = row[j];
        }
      }

      // Add total row
      int totalRowIndex = _students.length + 1;
      List<dynamic> totalRow = List.filled(headers.length, '');
      totalRow[0] = 'OVERALL TOTAL';
      totalRow[5] = t1TotalSum;
      totalRow[6] = t1PaidSum;
      totalRow[7] = t1DueSum;
      totalRow[9] = t2TotalSum;
      totalRow[10] = t2PaidSum;
      totalRow[11] = t2DueSum;
      totalRow[13] = t3TotalSum;
      totalRow[14] = t3PaidSum;
      totalRow[15] = t3DueSum;
      totalRow[18] = busTotalSum;
      totalRow[19] = busPaidSum;
      totalRow[20] = busDueSum;
      totalRow[23] = hostelTotalSum;
      totalRow[24] = hostelPaidSum;
      totalRow[25] = hostelDueSum;
      totalRow[27] = totalDueSum;

      for (int j = 0; j < totalRow.length; j++) {
        var cell = sheetObject.cell(excel_package.CellIndex.indexByColumnRow(columnIndex: j, rowIndex: totalRowIndex));
        cell.value = totalRow[j];
        cell.cellStyle = excel_package.CellStyle(bold: true);
      }

      // Save file using PlatformFileSaver
      final bytes = excel.encode();
      if (bytes != null) {
        final uint8List = Uint8List.fromList(bytes);
        final fileName = 'StudentDetails_${DateTime.now().millisecondsSinceEpoch}.xlsx';
        await PlatformFileSaver.saveFile(uint8List, fileName, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Excel file export process completed'),
            duration: const Duration(seconds: 3),
          ),
        );
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
                                                        Row(
                                                          children: [
                                                            Text(
                                                              student.className,
                                                              style: GoogleFonts.inter(
                                                                fontSize: 12,
                                                                color: Colors.grey[600],
                                                              ),
                                                            ),
                                                            const SizedBox(width: 8),
                                                            Icon(Icons.phone, size: 10, color: Colors.blue[600]),
                                                            const SizedBox(width: 4),
                                                            Text(
                                                              student.parentMobile,
                                                              style: GoogleFonts.inter(
                                                                fontSize: 12,
                                                                color: Colors.blue[600],
                                                                fontWeight: FontWeight.w600,
                                                              ),
                                                            ),
                                                          ],
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

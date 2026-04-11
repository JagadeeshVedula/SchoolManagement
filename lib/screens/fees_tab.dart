import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:school_management/services/supabase_service.dart';
import 'package:intl/intl.dart';
import 'package:school_management/models/student.dart';
import 'dart:io' show File;
import 'dart:typed_data' show Uint8List;
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html;
import 'package:flutter/services.dart';

class FeesTab extends StatefulWidget {
  const FeesTab({super.key});

  @override
  State<FeesTab> createState() => _FeesTabState();
}

class _FeesTabState extends State<FeesTab> {
  int _currentPage = 0; // 0 menu, 1 payments, 2 dues

  // Payments
  String? _selectedPaymentType; // 'School Fee', 'Books Fee', 'Uniform Fee'
  String? _selectedClass;
  String? _selectedSection;
  List<String> _sections = [];
  List<String> _classes = [];
  List<Student> _students = [];
  Student? _selectedStudent;

  // Fee form fields
  String? _selectedTermMonth;
  final _termYear = TextEditingController();
  final _feeType = TextEditingController();
  final _amount = TextEditingController();
  final _concession = TextEditingController(); // Concession amount input
  // Term No selections (checkboxes)
  final Map<int, bool> _termSelections = {1: false, 2: false, 3: false};

  // Bus Fee checkbox state
  bool _payBusFee = false;

  // Dues
  String? _selectedDueType; // 'School'
  String? _selectedDueClass;
  String? _selectedDueSection;
  List<String> _dueSections = [];
  List<Student> _dueStudents = [];
  final Map<String, bool> _dueTerms = {'Term1': false, 'Term2': false, 'Term3': false};
  
  // Payment History
  List<Map<String, dynamic>> _paymentHistory = [];
  bool _showPaymentHistory = false;

  // Track payment status for Books and Uniform fees
  bool _booksFeeAlreadyPaid = false;
  bool _uniformFeeAlreadyPaid = false;
  double _booksFeeTotal = 0;
  double _booksFeePaid = 0;
  double _uniformFeeTotal = 0;
  double _uniformFeePaid = 0;
  bool _hostelFeeAlreadyPaid = false;

  bool _isSubmitting = false;
  DateTime? _selectedDate;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadDropdownData();
  }

  Future<void> _loadDropdownData() async {
    final classes = await SupabaseService.getClassesFromFeeStructure();
    final sections = List.generate(26, (i) => String.fromCharCode('A'.codeUnitAt(0) + i));
    if (mounted) {
      setState(() {
        _classes = classes..sort();
        _sections = sections;
        _dueSections = sections;
      });
    }
  }

  Future<void> _onClassSelectedInFees(String? className) async {
    setState(() {
      _selectedClass = className;
      _selectedSection = null;
      _students = [];
      _selectedStudent = null;
    });
  }

  Future<void> _onSectionSelectedInFees(String? sectionName) async {
    setState(() {
      _selectedSection = sectionName;
    });
    if (_selectedClass == null || sectionName == null) return;
    final students = await SupabaseService.getStudentsByClass('$_selectedClass-$sectionName');
    setState(() {
      _students = students;
      _selectedStudent = null;
      _paymentHistory = [];
      _showPaymentHistory = false;
    });
  }

  Future<void> _onClassSelectedInDues(String? className) async {
    setState(() {
      _selectedDueClass = className;
      _selectedDueSection = null;
      _dueStudents = [];
    });
  }

  Future<void> _onSectionSelectedInDues(String? sectionName) async {
    setState(() {
      _selectedDueSection = sectionName;
    });
    if (_selectedDueClass == null || sectionName == null) {
      setState(() {
        _dueStudents = [];
      });
      return;
    }
    final students = await SupabaseService.getStudentsByClass('$_selectedDueClass-$sectionName');
    setState(() {
      _dueStudents = students;
    });
  }

  Future<void> _submitFee() async {
    if (_selectedStudent == null) return;
    if (_amount.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter amount')));
      return;
    }
    setState(() => _isSubmitting = true);
    final selectedTermNos = _termSelections.entries.where((e) => e.value).map((e) => 'Term ${e.key}').join(',');
    final data = {
      'STUDENT NAME': _selectedStudent!.name,
      'ROLL_NO': _selectedStudent!.rollNo ?? '',
      'TERM MONTH': _selectedTermMonth ?? '',
      'TERM YEAR': _termYear.text.trim(),
      'FEE TYPE': _feeType.text.trim().isEmpty ? (_selectedPaymentType ?? '') : _feeType.text.trim(),
      'AMOUNT': _amount.text.trim(),
      'TERM NO': selectedTermNos,
    };
    final ok = await SupabaseService.insertFee(data);
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (ok) {
      // Show receipt immediately before resetting
      final studentForReceipt = _selectedStudent!;
      final paymentForReceipt = Map<String, dynamic>.from(data)
        ..['AMOUNT'] = data['AMOUNT']
        ..['FEE TYPE'] = data['FEE TYPE'];
      _showPaymentInvoiceDialog(paymentForReceipt);
      // Keep student selected and don't reset navigation
      setState(() {
        _selectedTermMonth = null;
        _termYear.clear(); _feeType.clear(); _amount.clear();
        _termSelections.updateAll((key, value) => false);
        if (_showPaymentHistory) _loadPaymentHistory();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to record fee')));
    }
  }

  Future<void> _saveConcession() async {
    if (_selectedStudent == null || _selectedPaymentType == null) return;
    
    final concessionAmount = double.tryParse(_concession.text.trim()) ?? 0;
    
    // Determine which concession to update
    double newSchoolFeeConcession = _selectedStudent!.schoolFeeConcession;
    double newBusFeeConcession = _selectedStudent!.busFeeConcession;
    double newHostelFeeConcession = _selectedStudent!.hostelFeeConcession;
    
    if (_selectedPaymentType == 'School Fee') {
      newSchoolFeeConcession = concessionAmount;
    } else if (_selectedPaymentType == 'Bus Fee') {
      newBusFeeConcession = concessionAmount;
    } else if (_selectedPaymentType == 'Hostel Fee') {
      newHostelFeeConcession = concessionAmount;
    }
    // Call supabase service to update
    final ok = await SupabaseService.updateStudentConcession(
      _selectedStudent!.name,
      newSchoolFeeConcession,
      newBusFeeConcession,
      newHostelFeeConcession,
      _selectedStudent!.tuitionFeeConcession,
    );
    
    if (!mounted) return;
    
    if (ok) {
      // Update local student object to reflect new concession
      if (mounted) {
        setState(() {
          _selectedStudent = _selectedStudent?.copyWith(
            schoolFeeConcession: newSchoolFeeConcession,
            busFeeConcession: newBusFeeConcession,
            hostelFeeConcession: newHostelFeeConcession,
          );
        });
        _concession.clear();
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Concession saved successfully'), backgroundColor: Colors.green),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save concession'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<bool> _checkBusFeeAlreadyPaid(String studentName) async {
    final fees = await SupabaseService.getFeesByStudent(studentName);
    final busFeesPaid = fees
        .where((f) => (f['FEE TYPE'] as String? ?? '').contains('Bus Fee'))
        .fold<double>(0, (sum, f) => sum + (double.tryParse((f['AMOUNT'] as dynamic).toString()) ?? 0));
    return busFeesPaid > 0;
  }

  Future<bool> _checkBooksFeeAlreadyPaid(String studentName) async {
    final fees = await SupabaseService.getFeesByStudent(studentName);
    final currentYear = DateTime.now().year.toString();
    
    final booksFeesForCurrentYear = fees.where((f) {
      final feeType = (f['FEE TYPE'] as String? ?? '').toLowerCase();
      final termYear = (f['TERM YEAR'] as String? ?? '').toString();
      final isBooksFee = feeType.contains('books');
      final isCurrentYear = termYear == currentYear || termYear.isEmpty;
      return isBooksFee && isCurrentYear;
    }).toList();
    
    final booksFeePaid = booksFeesForCurrentYear.fold<double>(
      0, 
      (sum, f) => sum + (double.tryParse((f['AMOUNT'] as dynamic).toString()) ?? 0)
    );
    return booksFeePaid > 0;
  }

  Future<bool> _checkUniformFeeAlreadyPaid(String studentName) async {
    final fees = await SupabaseService.getFeesByStudent(studentName);
    final currentYear = DateTime.now().year.toString();
    
    final uniformFeesForCurrentYear = fees.where((f) {
      final feeType = (f['FEE TYPE'] as String? ?? '').toLowerCase();
      final termYear = (f['TERM YEAR'] as String? ?? '').toString();
      final isUniformFee = feeType.contains('uniform');
      final isCurrentYear = termYear == currentYear || termYear.isEmpty;
      return isUniformFee && isCurrentYear;
    }).toList();
    
    final uniformFeePaid = uniformFeesForCurrentYear.fold<double>(
      0, 
      (sum, f) => sum + (double.tryParse((f['AMOUNT'] as dynamic).toString()) ?? 0)
    );
    return uniformFeePaid > 0;
  }

  Future<bool> _checkHostelFeeAlreadyPaid(String studentName) async {
    final fees = await SupabaseService.getFeesByStudent(studentName);
    final currentYear = DateTime.now().year.toString();
    
    final hostelFeesForCurrentYear = fees.where((f) {
      final feeType = (f['FEE TYPE'] as String? ?? '').toLowerCase();
      final termYear = (f['TERM YEAR'] as String? ?? '').toString();
      final isHostelFee = feeType.contains('hostel');
      final isCurrentYear = termYear == currentYear || termYear.isEmpty;
      return isHostelFee && isCurrentYear;
    }).toList();
    
    final hostelFeePaid = hostelFeesForCurrentYear.fold<double>(
      0, 
      (sum, f) => sum + (double.tryParse((f['AMOUNT'] as dynamic).toString()) ?? 0)
    );
    return hostelFeePaid > 0;
  }

  Future<double> _getHostelFeePaid(String studentName) async {
    final fees = await SupabaseService.getFeesByStudent(studentName);
    final hostelPayments = fees.where((f) {
      final feeType = (f['FEE TYPE'] as String? ?? '').toLowerCase();
      return feeType.contains('hostel');
    }).toList();
    
    final totalPaid = hostelPayments.fold<double>(
      0,
      (sum, f) => sum + (double.tryParse((f['AMOUNT'] as dynamic).toString()) ?? 0)
    );
    return totalPaid;
  }

  Future<void> _downloadFile(List<int> bytes, String fileName) async {
    try {
      if (kIsWeb) {
        // Web: use html.Blob download
        _downloadFileWeb(bytes, fileName);
      } else {
        // Mobile/Desktop: save to Downloads or Documents directory
        try {
          final directory = await getDownloadsDirectory();
          if (directory == null) {
            // Fallback to documents directory
            final docDir = await getApplicationDocumentsDirectory();
            final file = File('${docDir.path}/$fileName');
            await file.writeAsBytes(bytes);
          } else {
            final file = File('${directory.path}/$fileName');
            await file.writeAsBytes(bytes);
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error saving file: $e')),
            );
          }
          return;
        }
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Downloaded: $fileName')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _downloadFileWeb(List<int> bytes, String fileName) {
    // Web download using Blob and download link
    try {
      // Determine MIME type based on file extension
      String mimeType = 'application/octet-stream';
      if (fileName.endsWith('.pdf')) {
        mimeType = 'application/pdf';
      } else if (fileName.endsWith('.xlsx')) {
        mimeType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      }
      
      // Create a Uint8List from the bytes to ensure proper byte handling
      final uint8List = Uint8List.fromList(bytes);
      final blob = html.Blob([uint8List], mimeType);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..target = 'blank'
        ..download = fileName;
      html.document.body?.append(anchor);
      anchor.click();
      html.Url.revokeObjectUrl(url);
      anchor.remove();
    } catch (e) {
      print('Error preparing web download: $e');
    }
  }

  Future<void> _exportDuesToExcel() async {
    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Sheet1'];
      
      // Add headers
      sheetObject.appendRow(['Student Name', 'Class', 'Term 1 Due', 'Term 2 Due', 'Term 3 Due', 'Bus Fee Due', 'Total Due']);
      
      // Add data for each student
      for (final s in _dueStudents) {
        final structure = await SupabaseService.getFeeStructureByClass(s.className.split('-').first);
        if (structure == null) continue;
        
        final totalFee = double.tryParse((structure['FEE'] as dynamic).toString()) ?? 0;
        final concession = s.schoolFeeConcession;
        final termFees = SupabaseService.calculateTermFees(totalFee, concession.toDouble());
        
        final fees = await SupabaseService.getFeesByStudent(s.name);
        
        final termsWithDue = <int, double>{};
        for (int term = 1; term <= 3; term++) {
          final termKeyFull = 'Term $term';
          double paidAmount = 0;
          
          for (final fee in fees) {
            final feeType = (fee['FEE TYPE'] as String? ?? '').toLowerCase().trim();
            final termNo = (fee['TERM NO'] as String? ?? '').toLowerCase().trim();
            
            // Match school fee payments for this term
            if (feeType.contains('school fee') && termNo.contains(termKeyFull.toLowerCase())) {
              final amt = double.tryParse((fee['AMOUNT'] as dynamic).toString()) ?? 0;
              paidAmount += amt;
            }
          }
          
          final termFee = termFees[term]!;
          if (paidAmount < termFee) {
            termsWithDue[term] = termFee - paidAmount;
          }
        }
        
        double busFee = 0;
        if (s.busRoute != null && s.busRoute!.isNotEmpty) {
          final busPaidAmount = fees
              .where((f) => (f['FEE TYPE'] as String? ?? '').contains('Bus Fee'))
              .fold<double>(0, (sum, f) => sum + (double.tryParse((f['AMOUNT'] as dynamic).toString()) ?? 0));
          if (busPaidAmount == 0) {
            busFee = await SupabaseService.getBusFeeByRoute(s.busRoute!);
          }
        }
        
        final totalDue = termsWithDue.values.fold<double>(0, (a, b) => a + b) + busFee;
        
        sheetObject.appendRow([
          s.name,
          s.className,
          termsWithDue[1] ?? 0,
          termsWithDue[2] ?? 0,
          termsWithDue[3] ?? 0,
          busFee,
          totalDue,
        ]);
      }
      
      // Encode and download
      final bytes = excel.encode();
      if (bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error encoding Excel file')),
          );
        }
        return;
      }
      final fileName = 'Dues_${DateTime.now().toString().split(' ')[0]}.xlsx';
      await _downloadFile(bytes, fileName);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _loadPaymentHistory() async {
    if (_selectedStudent == null) return;
    
    try {
      final payments = await SupabaseService.getFeesByStudent(_selectedStudent!.name);
      
      // Filter payments by selected payment type
      final filteredPayments = payments.where((p) {
        final feeType = (p['FEE TYPE'] as String? ?? '').trim();
        
        // For School Fee, show School Fee, Bus Fee, and Administration Fee
        if (_selectedPaymentType == 'School Fee') {
          return feeType.contains('School Fee') || feeType.contains('Bus Fee') || feeType.contains('Administration');
        }
        
        // For Books Fee and Uniform Fee, show only that specific fee type
        return feeType.contains(_selectedPaymentType!.trim());
      }).toList();
      
      // Sort payments by date/time (latest first)
      payments.sort((a, b) {
        final dateA = a['created_at'] != null ? DateTime.parse(a['created_at'].toString()) : DateTime.now();
        final dateB = b['created_at'] != null ? DateTime.parse(b['created_at'].toString()) : DateTime.now();
        return dateB.compareTo(dateA);
      });

      setState(() {
        _paymentHistory = filteredPayments;
        _showPaymentHistory = true;
      });
      
      // Show message if no payment history found
      if (filteredPayments.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No payment history found for ${_selectedStudent!.name}'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading payment history: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // â”€â”€â”€ Number to words helper â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  String _numberToWords(int n) {
    if (n == 0) return 'Zero';
    const ones = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven',
      'Eight', 'Nine', 'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen',
      'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'];
    const tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty',
      'Sixty', 'Seventy', 'Eighty', 'Ninety'];

    String _convertBelow1000(int num) {
      if (num == 0) return '';
      if (num < 20) return '${ones[num]} ';
      if (num < 100) return '${tens[num ~/ 10]} ${ones[num % 10]} ';
      return '${ones[num ~/ 100]} Hundred ${_convertBelow1000(num % 100)}';
    }

    String result = '';
    if (n >= 10000000) { result += '${_convertBelow1000(n ~/ 10000000)}Crore '; n %= 10000000; }
    if (n >= 100000)   { result += '${_convertBelow1000(n ~/ 100000)}Lakh '; n %= 100000; }
    if (n >= 1000)     { result += '${_convertBelow1000(n ~/ 1000)}Thousand '; n %= 1000; }
    result += _convertBelow1000(n);
    return result.trim();
  }

  String _amountInWords(double amount) {
    final rupees = amount.toInt();
    final paise = ((amount - rupees) * 100).round();
    String words = '${_numberToWords(rupees)} Rupees';
    if (paise > 0) words += ' and ${_numberToWords(paise)} Paise';
    words += ' Only.';
    return words;
  }

  // â”€â”€â”€ Fetch all receipt data in one go â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<Map<String, dynamic>> _fetchReceiptData(Map<String, dynamic> payment) async {
    final student = _selectedStudent!;
    final classOnly = student.className.split('-').first;

    // Fees paid (all records)
    final allFees = await SupabaseService.getFeesByStudent(student.name);

    // School fee total
    double schoolFeeTotal = 0;
    final structure = await SupabaseService.getFeeStructureByClass(classOnly);
    if (structure != null) {
      final rawFee = double.tryParse((structure['FEE'] as dynamic).toString()) ?? 0;
      schoolFeeTotal = (rawFee - student.schoolFeeConcession).clamp(0, double.infinity);
    }

    // School fee paid
    final schoolFeePaid = allFees
        .where((f) => (f['FEE TYPE'] as String? ?? '').toLowerCase().contains('school fee'))
        .fold<double>(0, (s, f) => s + (double.tryParse((f['AMOUNT'] as dynamic).toString()) ?? 0));

    // Bus fee total
    double busFeeTotal = 0;
    if (student.busFacility != null && student.busFacility!.toLowerCase() == 'yes' &&
        student.busRoute != null && student.busRoute!.isNotEmpty) {
      busFeeTotal = (await SupabaseService.getBusFeeByRoute(student.busRoute!) - student.busFeeConcession).clamp(0, double.infinity);
    }

    // Bus fee paid
    final busFeePaid = allFees
        .where((f) => (f['FEE TYPE'] as String? ?? '').toLowerCase().contains('bus fee'))
        .fold<double>(0, (s, f) => s + (double.tryParse((f['AMOUNT'] as dynamic).toString()) ?? 0));

    // Hostel fee total
    double hostelFeeTotal = 0;
    if (student.hostelFacility != null && student.hostelFacility!.toLowerCase() == 'yes') {
      final htype = student.hostelType ?? 'NON-AC';
      hostelFeeTotal = (await SupabaseService.getHostelFeeByClassAndType(classOnly, htype) - student.hostelFeeConcession)
          .clamp(0, double.infinity);
    }

    // Hostel fee paid
    final hostelFeePaid = allFees
        .where((f) => (f['FEE TYPE'] as String? ?? '').toLowerCase().contains('hostel'))
        .fold<double>(0, (s, f) => s + (double.tryParse((f['AMOUNT'] as dynamic).toString()) ?? 0));

    // This payment amount
    final thisPaidAmount = double.tryParse((payment['AMOUNT'] as dynamic).toString()) ?? 0;
    final feeType = (payment['FEE TYPE'] as String? ?? '');

    // Grand total and balance
    final grandTotal = schoolFeeTotal + busFeeTotal + hostelFeeTotal;
    final totalPaid = schoolFeePaid + busFeePaid + hostelFeePaid;
    final balance = (grandTotal - totalPaid).clamp(0, double.infinity);

    return {
      'schoolFeeTotal': schoolFeeTotal,
      'schoolFeePaid': schoolFeePaid,
      'busFeeTotal': busFeeTotal,
      'busFeePaid': busFeePaid,
      'hostelFeeTotal': hostelFeeTotal,
      'hostelFeePaid': hostelFeePaid,
      'grandTotal': grandTotal,
      'totalPaid': totalPaid,
      'balance': balance,
      'thisPaidAmount': thisPaidAmount,
      'feeType': feeType,
    };
  }

  // â”€â”€â”€ Show invoice dialog â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  void _showPaymentInvoiceDialog(Map<String, dynamic> payment) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: SizedBox(
          width: 700,
          child: FutureBuilder<Map<String, dynamic>>(
            future: _fetchReceiptData(payment),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
              }
              final d = snap.data ?? {};
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: _buildReceiptWidget(payment, d),
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.download),
                          label: const Text('Download PDF'),
                          onPressed: () => _downloadReceiptPDF(payment, d),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // â”€â”€â”€ In-app receipt widget â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildReceiptWidget(Map<String, dynamic> payment, Map<String, dynamic> d) {
    final student = _selectedStudent!;
    final receiptNo = payment['RECEIPT_ID'] ?? 'REC${DateTime.now().millisecondsSinceEpoch.toString().substring(0, 8)}';
    final receiptDate = payment['DATE'] ?? DateFormat('dd-MM-yyyy').format(DateTime.now());
    final admNo = student.id?.toString() ?? '-';
    final classSection = student.className;
    final thisPaid = (d['thisPaidAmount'] as double? ?? 0);
    final balance = (d['balance'] as double? ?? 0);
    final schoolFeeTotal = (d['schoolFeeTotal'] as double? ?? 0);
    final busFeeTotal = (d['busFeeTotal'] as double? ?? 0);
    final hostelFeeTotal = (d['hostelFeeTotal'] as double? ?? 0);
    final feeType = (d['feeType'] as String? ?? '');

    // Build rows for consolidated or single payment
    final rows = <Map<String, dynamic>>[];
    int sno = 1;

    // Check for consolidated items first
    if (payment.containsKey('items') && (payment['items'] as List).isNotEmpty) {
      final items = payment['items'] as List<Map<String, dynamic>>;
      for (final it in items) {
        rows.add({'sno': sno++, 'desc': it['desc'], 'amount': it['amount']});
      }
    } else {
      // Original single payment logic (fallback)
      if (feeType.toLowerCase().contains('bus fee') || (busFeeTotal > 0 && feeType.toLowerCase().contains('bus'))) {
        rows.add({'sno': sno++, 'desc': 'Bus Fee', 'amount': thisPaid});
      } else if (feeType.toLowerCase().contains('hostel')) {
        rows.add({'sno': sno++, 'desc': 'Hostel Fee', 'amount': thisPaid});
      } else if (feeType.toLowerCase().contains('books')) {
        rows.add({'sno': sno++, 'desc': 'Books Fee', 'amount': thisPaid});
      } else if (feeType.toLowerCase().contains('uniform')) {
        rows.add({'sno': sno++, 'desc': 'Uniform Fee', 'amount': thisPaid});
      } else if (feeType.toLowerCase().contains('administration') || feeType.toLowerCase().contains('admin')) {
        rows.add({'sno': sno++, 'desc': 'Administration Fee', 'amount': thisPaid});
      } else {
        rows.add({'sno': sno++, 'desc': 'School Fee', 'amount': thisPaid});
      }
    }

    final rowTotal = rows.fold<double>(0, (s, r) => s + (double.tryParse((r['amount'] as dynamic).toString()) ?? 0));

    return Container(
      decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 1.5)),
      child: Column(
        children: [
          // â”€â”€ Header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black))),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Logo from assets
                Image.asset(
                  'assets/images/Receipt_log.png',
                  width: 70, height: 70,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    children: [
                      Text('NALANDA IIT OLYMPIAD SCHOOL NARSIPATNAM',
                          style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center),
                      Text('Contact : 9666376288',
                          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
                          textAlign: TextAlign.center),
                      Text('Sarada Nagar, Narsipatnam, Andhra Pradesh 531116',
                          style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[700]),
                          textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // â”€â”€ Fee Receipt title â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Container(
            width: double.infinity,
            color: Colors.grey[200],
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text('Fee Receipt',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
          ),
          // â”€â”€ Student details 2-column â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Table(
              children: [
                _infoRow('Receipt No', receiptNo, 'Receipt Date', receiptDate),
                _infoRow('Adm No', admNo, 'Roll No', student.rollNo ?? '-'),
                _infoRow('Name', student.name, 'Class/Section', classSection),
                _infoRow('Father Name', student.fatherName, 'F-Mobile No', student.parentMobile),
              ],
            ),
          ),
          // â”€â”€ Fee table â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(border: Border.all(color: Colors.black)),
            child: Column(
              children: [
                // Header
                Container(
                  color: Colors.grey[100],
                  child: Table(
                    columnWidths: const {0: FixedColumnWidth(50), 2: FixedColumnWidth(100)},
                    children: [
                      TableRow(
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: Colors.black)),
                        ),
                        children: [
                          _tableCell('SNo', bold: true),
                          _tableCell('Description', bold: true),
                          _tableCell('Amount', bold: true, align: TextAlign.right),
                        ],
                      ),
                    ],
                  ),
                ),
                // Data rows
                Table(
                  columnWidths: const {0: FixedColumnWidth(50), 2: FixedColumnWidth(100)},
                  children: [
                    ...rows.map((r) => TableRow(
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: Colors.grey, width: 0.5)),
                      ),
                      children: [
                        _tableCell(r['sno'].toString()),
                        _tableCell(r['desc'] as String),
                        _tableCell('${(r['amount'] as double).toStringAsFixed(0)}', align: TextAlign.right),
                      ],
                    )),
                    // Total row
                    TableRow(
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: Colors.black)),
                      ),
                      children: [
                        _tableCell(''),
                        _tableCell('Total', bold: true, align: TextAlign.right),
                        _tableCell(rowTotal.toStringAsFixed(0), bold: true, align: TextAlign.right),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // â”€â”€ In Words â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text('In Words: ', style: GoogleFonts.poppins(fontSize: 12)),
                Expanded(
                  child: Text(_amountInWords(rowTotal),
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // â”€â”€ Footer: Balance + Signature â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                // Fee summary line (only if has hostel/bus)
                if (schoolFeeTotal > 0 || busFeeTotal > 0 || hostelFeeTotal > 0) ...[
                  Row(
                    children: [
                      Text('Thank You', style: GoogleFonts.poppins(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.green[700])),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.poppins(fontSize: 13, color: Colors.black),
                        children: [
                          const TextSpan(text: 'Balance: Rs. '),
                          TextSpan(
                            text: balance.toStringAsFixed(0),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                    Text('Authorized Signature',
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  TableRow _infoRow(String l1, String v1, String l2, String v2) {
    return TableRow(children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Text('$l1 : ', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Text(v1, style: const TextStyle(fontSize: 12)),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Text('$l2 : ', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Text(v2, style: const TextStyle(fontSize: 12)),
      ),
    ]);
  }

  Widget _tableCell(String text, {bool bold = false, TextAlign align = TextAlign.left}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(text,
          textAlign: align,
          style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
    );
  }

  // â”€â”€â”€ PDF download â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<void> _downloadReceiptPDF(Map<String, dynamic> payment, Map<String, dynamic> d) async {
    try {
      final student = _selectedStudent!;
      final pdf = pw.Document();
      final receiptNo = payment['RECEIPT_ID'] ?? 'REC${DateTime.now().millisecondsSinceEpoch.toString().substring(0, 8)}';
      final receiptDate = payment['DATE'] ?? DateFormat('dd-MM-yyyy').format(DateTime.now());
      final admNo = student.id?.toString() ?? '-';
      final thisPaid = (d['thisPaidAmount'] as double? ?? 0);
      final balance = (d['balance'] as double? ?? 0);
      final feeType = (d['feeType'] as String? ?? '');

      // Load logo image
      final logoData = await rootBundle.load('assets/images/Receipt_log.png');
      final logoImage = pw.MemoryImage(logoData.buffer.asUint8List());

      // Build fee rows
      final rows = <List<String>>[];
      int sno = 1;
      
      if (payment.containsKey('items') && (payment['items'] as List).isNotEmpty) {
        final items = payment['items'] as List<Map<String, dynamic>>;
        for (final it in items) {
          rows.add(['${sno++}', it['desc'] as String, (it['amount'] as num).toStringAsFixed(0)]);
        }
      } else {
        if (feeType.toLowerCase().contains('bus fee')) {
          rows.add(['${sno++}', 'Bus Fee', thisPaid.toStringAsFixed(0)]);
        } else if (feeType.toLowerCase().contains('hostel')) {
          rows.add(['${sno++}', 'Hostel Fee', thisPaid.toStringAsFixed(0)]);
        } else if (feeType.toLowerCase().contains('books')) {
          rows.add(['${sno++}', 'Books Fee', thisPaid.toStringAsFixed(0)]);
        } else if (feeType.toLowerCase().contains('uniform')) {
          rows.add(['${sno++}', 'Uniform Fee', thisPaid.toStringAsFixed(0)]);
        } else if (feeType.toLowerCase().contains('administration') || feeType.toLowerCase().contains('admin')) {
          rows.add(['${sno++}', 'Administration Fee', thisPaid.toStringAsFixed(0)]);
        } else {
          rows.add(['${sno++}', 'School Fee', thisPaid.toStringAsFixed(0)]);
        }
      }

      final total = rows.fold<double>(0, (s, r) => s + (double.tryParse(r[2]) ?? 0));

      // Half-A4 = A5 landscape (210mm x 148mm)
      const halfA4 = PdfPageFormat(210 * PdfPageFormat.mm, 148 * PdfPageFormat.mm);

      pdf.addPage(
        pw.Page(
          pageFormat: halfA4,
          margin: const pw.EdgeInsets.all(18),
          build: (pw.Context ctx) => pw.Container(
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 1.5)),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black))),
                  child: pw.Row(children: [
                    pw.Image(logoImage, width: 55, height: 55),
                    pw.SizedBox(width: 15),
                    pw.Expanded(child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text('NALANDA IIT OLYMPIAD SCHOOL NARSIPATNAM',
                            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                        pw.Text('Contact : 9666376288', style: pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.center),
                        pw.Text('Sarada Nagar, Narsipatnam, Andhra Pradesh 531116',
                            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700), textAlign: pw.TextAlign.center),
                      ],
                    )),
                  ]),
                ),
                // Title
                pw.Container(
                  width: double.infinity, color: PdfColors.grey300,
                  padding: const pw.EdgeInsets.symmetric(vertical: 5),
                  child: pw.Text('Fee Receipt', textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
                ),
                // Student info
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: pw.Table(children: [
                    _pdfInfoRow('Receipt No', receiptNo, 'Receipt Date', receiptDate),
                    _pdfInfoRow('Adm No', admNo, 'Roll No', student.rollNo ?? '-'),
                    _pdfInfoRow('Name', student.name, 'Class/Section', student.className),
                    _pdfInfoRow('Father Name', student.fatherName, 'F-Mobile No', student.parentMobile),
                  ]),
                ),
                // Fee table
                pw.Container(
                  margin: const pw.EdgeInsets.symmetric(horizontal: 14),
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black)),
                  child: pw.Table(
                    columnWidths: {0: const pw.FixedColumnWidth(40), 2: const pw.FixedColumnWidth(90)},
                    children: [
                      // Header
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(
                          color: PdfColors.grey200,
                          border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black)),
                        ),
                        children: [
                          _pdfCell('SNo', bold: true),
                          _pdfCell('Description', bold: true),
                          _pdfCell('Amount', bold: true, align: pw.TextAlign.right),
                        ],
                      ),
                      // Data
                      ...rows.map((r) => pw.TableRow(
                        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey, width: 0.5))),
                        children: [
                          _pdfCell(r[0]),
                          _pdfCell(r[1]),
                          _pdfCell(r[2], align: pw.TextAlign.right),
                        ],
                      )),
                      // Total
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: PdfColors.black))),
                        children: [
                          _pdfCell(''),
                          _pdfCell('Total', bold: true, align: pw.TextAlign.right),
                          _pdfCell(total.toStringAsFixed(0), bold: true, align: pw.TextAlign.right),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 14),
                  child: pw.Row(children: [
                    pw.Text('In Words: ', style: pw.TextStyle(fontSize: 10)),
                    pw.Expanded(child: pw.Text(_amountInWords(total),
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                  ]),
                ),
                pw.SizedBox(height: 30),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                    pw.RichText(text: pw.TextSpan(
                      style: const pw.TextStyle(fontSize: 11),
                      children: [
                        const pw.TextSpan(text: 'Balance: Rs. '),
                        pw.TextSpan(text: balance.toStringAsFixed(0),
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColors.red)),
                      ],
                    )),
                    pw.Text('Authorized Signature', style: const pw.TextStyle(fontSize: 11)),
                  ]),
                ),
              ],
            ),
          ),
        ),
      );

      final fileName = 'Receipt_${student.name}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final pdfBytes = await pdf.save();
      await _downloadFile(List<int>.from(pdfBytes), fileName);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF generation failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  pw.TableRow _pdfInfoRow(String l1, String v1, String l2, String v2) {
    return pw.TableRow(children: [
      pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Text('$l1 : ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
      pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Text(v1, style: const pw.TextStyle(fontSize: 9))),
      pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Text('$l2 : ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
      pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Text(v2, style: const pw.TextStyle(fontSize: 9))),
    ]);
  }

  pw.Widget _pdfCell(String text, {bool bold = false, pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Text(text, textAlign: align,
          style: pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : null, fontSize: 10)),
    );
  }

  // kept for compatibility - unused stub
  Widget _buildInvoiceContent(Map<String, dynamic> payment, double paidAmount, double calculatedBalance, double totalTermFee, double totalPaid) {
    return const SizedBox.shrink();
  }

  Future<void> _downloadInvoicePDF(Map<String, dynamic> payment) async {
    final d = await _fetchReceiptData(payment);
    await _downloadReceiptPDF(payment, d);
  }

  void _openStudentSearchDialog() {
    String searchText = '';
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Search Student'),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return SizedBox(
              width: 300,
              height: 400,
              child: Column(
                mainAxisSize: MainAxisSize.max,
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Enter student name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) => setDialogState(() => searchText = v),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _students.isEmpty
                        ? const Center(child: Text('No students found. Please select a class first.'))
                        : ListView(
                            children: _students
                                .where((s) => s.name.toLowerCase().contains(searchText.toLowerCase()))
                                .map((s) => ListTile(
                                  title: Text(s.name),
                                  subtitle: Text(s.parentMobile),
                                  onTap: () {
                                    setState(() => _selectedStudent = s);
                                    Navigator.pop(dialogContext);
                                  },
                                ))
                                .toList(),
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _populateAmountByFeeType(TextEditingController amountController, String classWithoutSection) async {
    try {
      if (_selectedPaymentType == 'Books Fee' && _selectedStudent != null) {
        final totalFee = await SupabaseService.getBooksFeeByClass(classWithoutSection);
        final paidFee = await SupabaseService.getTotalPaidByFeeType(_selectedStudent!.name, 'Books Fee');
        final remaining = (totalFee - paidFee).clamp(0, double.infinity);
        
        if (mounted) {
          setState(() {
            _booksFeeTotal = totalFee;
            _booksFeePaid = paidFee;
            _booksFeeAlreadyPaid = remaining <= 0 && totalFee > 0;
          });
        }
        amountController.text = _booksFeeAlreadyPaid ? '0.00' : remaining.toStringAsFixed(2);
      } else if (_selectedPaymentType == 'Uniform Fee' && _selectedStudent != null) {
        String gender = _selectedStudent!.gender ?? 'M';
        // Normalize gender to match 'M' or 'F' used in Supabase UNIFORM table
        if (gender.toLowerCase().startsWith('m')) {
          gender = 'M';
        } else if (gender.toLowerCase().startsWith('f')) {
          gender = 'F';
        }
        final totalFee = await SupabaseService.getUniformFeeByClassAndGender(classWithoutSection, gender);
        final paidFee = await SupabaseService.getTotalPaidByFeeType(_selectedStudent!.name, 'Uniform Fee');
        final remaining = (totalFee - paidFee).clamp(0, double.infinity);
        
        if (mounted) {
          setState(() {
            _uniformFeeTotal = totalFee;
            _uniformFeePaid = paidFee;
            _uniformFeeAlreadyPaid = remaining <= 0 && totalFee > 0;
          });
        }
        amountController.text = _uniformFeeAlreadyPaid ? '0.00' : remaining.toStringAsFixed(2);
      }
    } catch (e) {
      print('Error populating amount: $e');
    }
  }

  Future<void> _openPaymentScreen() async {
    if (_selectedPaymentType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a payment type first')),
      );
      return;
    }
    if (_selectedStudent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a student first')),
      );
      return;
    }

    // Check payment status for Books and Uniform fees
    // Checks for already paid status will now be handled inside _populateAmountByFeeType

    // Local controllers for this dialog
    final termMonthController = ValueNotifier<String?>(_selectedTermMonth);
    final termYearController = ValueNotifier<String?>(DateTime.now().year.toString());
    final amountController = TextEditingController();
    final hostelPaymentController = TextEditingController();
    final termSelections = Map<int, bool>.from(_termSelections);
    final hostelConcessionController = TextEditingController(text: _selectedStudent!.hostelFeeConcession.toStringAsFixed(2));
    final busConcessionController = TextEditingController(text: _selectedStudent!.busFeeConcession.toStringAsFixed(2));
    
    // Bus Fee state
    final hasBusRoute = _selectedStudent!.busRoute != null && _selectedStudent!.busRoute!.isNotEmpty;
    bool payBusFee = false;
    final busFeePaymentController = TextEditingController();
    // Extract class without section (e.g., "V-A" -> "V")

    final classWithoutSection = _selectedStudent!.className.split('-')[0];
    
    // Check if student has hostel facility
    final hasHostelFacility = _selectedStudent!.hostelFacility == 'Yes';
    bool payHostelFee = false;
    
    // Auto-populate amount based on payment type
    await _populateAmountByFeeType(amountController, classWithoutSection);
    
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 12,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [const Color(0xFF800000).withOpacity(0.05), const Color(0xFF800000).withOpacity(0.1)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: StatefulBuilder(
            builder: (context, setDialogState) => SizedBox(
              width: 600,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: InkWell(
                          onTap: () async {
                            final pickedDate = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (pickedDate != null) {
                              setDialogState(() {
                                _selectedDate = pickedDate;
                              });
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'Payment Date', border: OutlineInputBorder()),
                            child: Text(DateFormat('dd-MM-yyyy').format(_selectedDate ?? DateTime.now())),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF800000),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Payment Details',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 20, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF800000).withOpacity(0.05),
                          border: Border.all(color: const Color(0xFF800000).withOpacity(0.2), width: 1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Student: ${_selectedStudent!.name}',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: const Color(0xFF800000),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Class: ${_selectedStudent!.className}',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                                color: const Color(0xFF800000).withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    // Dynamic Status for Books and Uniform Fees
                    if (_selectedPaymentType == 'Books Fee' && _booksFeePaid > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: _booksFeeAlreadyPaid ? Colors.green[50] : Colors.orange[50],
                            border: Border.all(color: _booksFeeAlreadyPaid ? Colors.green : Colors.orange),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _booksFeeAlreadyPaid ? Icons.check_circle : Icons.warning_amber_rounded,
                                size: 16,
                                color: _booksFeeAlreadyPaid ? Colors.green[800] : Colors.orange[800],
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _booksFeeAlreadyPaid 
                                      ? 'Total Books fee paid: Rs.${_booksFeeTotal.toStringAsFixed(0)}' 
                                      : 'Books Fee: Total Rs.${_booksFeeTotal.toStringAsFixed(0)}, Paid Rs.${_booksFeePaid.toStringAsFixed(0)}, Remaining Rs.${(_booksFeeTotal - _booksFeePaid).toStringAsFixed(0)}',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600, 
                                    fontSize: 12, 
                                    color: _booksFeeAlreadyPaid ? Colors.green[800] : Colors.orange[800]
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (_selectedPaymentType == 'Uniform Fee' && _uniformFeePaid > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: _uniformFeeAlreadyPaid ? Colors.green[50] : Colors.orange[50],
                            border: Border.all(color: _uniformFeeAlreadyPaid ? Colors.green : Colors.orange),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _uniformFeeAlreadyPaid ? Icons.check_circle : Icons.warning_amber_rounded,
                                size: 16,
                                color: _uniformFeeAlreadyPaid ? Colors.green[800] : Colors.orange[800],
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _uniformFeeAlreadyPaid 
                                      ? 'Total Uniform fee paid: Rs.${_uniformFeeTotal.toStringAsFixed(0)}' 
                                      : 'Uniform Fee: Total Rs.${_uniformFeeTotal.toStringAsFixed(0)}, Paid Rs.${_uniformFeePaid.toStringAsFixed(0)}, Remaining Rs.${(_uniformFeeTotal - _uniformFeePaid).toStringAsFixed(0)}',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600, 
                                    fontSize: 12, 
                                    color: _uniformFeeAlreadyPaid ? Colors.green[800] : Colors.orange[800]
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.purple[50],
                          border: Border.all(color: Colors.purple[200]!, width: 1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Payment Type: ${_selectedPaymentType!.trim()}',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Colors.purple[900],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    // Already Paid Status for Books and Uniform Fees
                    if (_selectedPaymentType == 'Books Fee' && _booksFeeAlreadyPaid)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.orange[100],
                            border: Border.all(color: Colors.orange),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'âš ï¸ Already Paid',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.orange[800]),
                          ),
                        ),
                      ),
                    if (_selectedPaymentType == 'Uniform Fee' && _uniformFeeAlreadyPaid)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.orange[100],
                            border: Border.all(color: Colors.orange),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'âš ï¸ Already Paid',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.orange[800]),
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    // Term Month Dropdown - Only for School Fee
                    if (_selectedPaymentType == 'School Fee')
                      DropdownButtonFormField<String>(
                        value: termMonthController.value,
                        items: [
                          'June - September',
                          'November - February',
                          'March - June',
                        ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (v) => setDialogState(() => termMonthController.value = v),
                        decoration: const InputDecoration(labelText: 'Term Month', border: OutlineInputBorder()),
                      ),
                    if (_selectedPaymentType == 'School Fee')
                      const SizedBox(height: 16),
                    // Term Year Dropdown - Only for School Fee
                    if (_selectedPaymentType == 'School Fee')
                      DropdownButtonFormField<String>(
                        value: termYearController.value,
                        items: List.generate(
                                11, (index) => (2020 + index).toString())
                            .map((year) => DropdownMenuItem(
                                value: year, child: Text(year)))
                            .toList(),
                        onChanged: (v) => setDialogState(() => termYearController.value = v),
                        decoration: const InputDecoration(
                            labelText: 'Term Year',
                            border: OutlineInputBorder()),
                      ),
                    if (_selectedPaymentType == 'School Fee')
                      const SizedBox(height: 16),
                    // Amount
                    TextField(
                      controller: amountController,
                      enabled: !((_selectedPaymentType == 'Books Fee' && _booksFeeAlreadyPaid) ||
                               (_selectedPaymentType == 'Uniform Fee' && _uniformFeeAlreadyPaid)),
                      decoration: InputDecoration(
                        labelText: (_selectedPaymentType == 'Books Fee' && _booksFeeAlreadyPaid)
                            ? 'Total Books fee paid'
                            : (_selectedPaymentType == 'Uniform Fee' && _uniformFeeAlreadyPaid)
                                ? 'Total Uniform fee paid'
                                : 'Amount',
                        border: const OutlineInputBorder(),
                        suffixText: 'Rs.',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 16),
                    // Term No Checkboxes - Only for School Fee
                    if (_selectedPaymentType == 'School Fee') ...[
                      Text('Select Term No', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12)),
                      const SizedBox(height: 8),
                      FutureBuilder<Map<String, dynamic>?>(
                        future: SupabaseService.getFeeStructureByClass(_selectedStudent!.className),
                        builder: (context, _) { // We ignore the result of the first future
                          final classNameOnly = _selectedStudent!.className.split('-').first;
                          return FutureBuilder<Map<String, dynamic>?>(
                            future: SupabaseService.getFeeStructureByClass(classNameOnly),
                            builder: (context, finalStructureSnap) {
                          if (finalStructureSnap.connectionState == ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                            );
                          }
                          final structure = finalStructureSnap.data;
                          final totalFee = structure != null ? double.tryParse((structure['FEE'] as dynamic).toString()) ?? 0.0 : 0.0;
                          final concession = _selectedStudent!.schoolFeeConcession;
                          final termFees = SupabaseService.calculateTermFees(totalFee, concession.toDouble());
                          
                          return FutureBuilder<List<Map<String, dynamic>>>(
                            future: _selectedStudent != null ? SupabaseService.getFeesByStudent(_selectedStudent!.name) : Future.value([]),
                            builder: (context, feesSnap) {
                              final allFees = feesSnap.data ?? [];
                              
                              return AnimatedSize(
                                duration: const Duration(milliseconds: 300),
                                child: Column(
                                  children: List.generate(3, (index) {
                                  final termNum = index + 1;
                                  final termFee = termFees[termNum] ?? 0;
                                  
                                  // Calculate paid amount for this term
                                  double paidForTerm = 0;
                                  for (final fee in allFees) {
                                    final feeType = (fee['FEE TYPE'] as String? ?? '').toLowerCase().trim();
                                    final termNo = (fee['TERM NO'] as String? ?? '').toLowerCase().trim();
                                    if (feeType.contains('school fee') && termNo.contains('term $termNum')) {
                                      paidForTerm += double.tryParse((fee['AMOUNT'] as dynamic).toString()) ?? 0;
                                    }
                                  }
                                  
                                  final pendingForTerm = (termFee - paidForTerm).clamp(0, double.infinity);
                                  
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: termSelections[termNum]! ? const Color(0xFF800000).withOpacity(0.6) : Colors.grey[300]!,
                                          width: termSelections[termNum]! ? 2 : 1,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                        color: termSelections[termNum]! ? const Color(0xFF800000).withOpacity(0.1) : Colors.transparent,
                                      ),
                                      child: CheckboxListTile(
                                        value: termSelections[termNum],
                                        onChanged: (v) => setDialogState(() => termSelections[termNum] = v ?? false),
                                        title: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('Term $termNum'),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  'Pending: Rs.${pendingForTerm.toStringAsFixed(2)}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: pendingForTerm > 0 ? Colors.red : Colors.green,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        controlAffinity: ListTileControlAffinity.leading,
                                        dense: true,
                                      ),
                                    ),
                                  );
                                }),
                               ));
                            },
                          );
                        });
                        }),
                      const SizedBox(height: 16),
                      // Hostel Fee Section - Only for School Fee and if student has the facility
                      if (hasHostelFacility && _selectedPaymentType == 'School Fee')
                        FutureBuilder<double>(
                          future: SupabaseService.getHostelFeeByClass(classWithoutSection),
                          builder: (context, hostelFeeSnap) {
                            if (hostelFeeSnap.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            final hostelFeeAmount = hostelFeeSnap.data ?? 0;
                            
                            return FutureBuilder<double>(
                              future: _getHostelFeePaid(_selectedStudent!.name),
                              builder: (context, paidSnap) {
                                final hostelPaidAmount = paidSnap.data ?? 0;                                
                                final effectiveHostelFee = (hostelFeeAmount - _selectedStudent!.hostelFeeConcession).clamp(0, double.infinity);
                                final hostelFeeDue = (effectiveHostelFee - hostelPaidAmount).clamp(0, double.infinity);
                                final isHostelFullyPaid = hostelFeeDue <= 0 && hostelFeeAmount > 0;
                                
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF800000).withOpacity(0.05),
                                        border: Border.all(color: const Color(0xFF800000).withOpacity(0.2), width: 1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Hostel Fee', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14, color: const Color(0xFF800000))),
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text('Total Amount:', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                                              Text('Rs.${effectiveHostelFee.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                            ],
                                          ),
                                          if (hostelPaidAmount > 0) ...[
                                            const SizedBox(height: 6),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text('Already Paid:', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                                                Text('Rs.${hostelPaidAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green)),
                                              ],
                                            ),
                                          ],
                                          if (hostelFeeDue > 0) ...[
                                            const SizedBox(height: 6),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text('Remaining Due:', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                                                Text('Rs.${hostelFeeDue.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.red)),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    // Hostel Fee Concession Input
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                      child: TextField(
                                        controller: hostelConcessionController,
                                        decoration: InputDecoration(
                                          labelText: 'Hostel Fee Concession',
                                          border: const OutlineInputBorder(),
                                          suffixIcon: IconButton(
                                            icon: const Icon(Icons.save, color: Colors.green),
                                            onPressed: () async {
                                              final amount = double.tryParse(hostelConcessionController.text) ?? 0.0;
                                              final success = await SupabaseService.updateStudentConcession(
                                                _selectedStudent!.name,
                                                _selectedStudent!.schoolFeeConcession,
                                                _selectedStudent!.busFeeConcession,
                                                amount, // New hostel concession
                                                _selectedStudent!.tuitionFeeConcession,
                                              );
                                              if (success) {
                                                setDialogState(() {
                                                  _selectedStudent = _selectedStudent!.copyWith(hostelFeeConcession: amount);
                                                });
                                              }
                                            },
                                          ),
                                        ),
                                        keyboardType: TextInputType.number,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    if (!isHostelFullyPaid)
                                      StatefulBuilder(
                                        builder: (context, setPaymentState) => Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            CheckboxListTile(
                                              value: payHostelFee,
                                              onChanged: (v) {
                                                setDialogState(() => payHostelFee = v ?? false);
                                                if (!payHostelFee) {
                                                  hostelPaymentController.clear();
                                                }
                                              },
                                              title: const Text('Pay Hostel Fee', style: TextStyle(fontWeight: FontWeight.w600)),
                                              subtitle: Text('Rs.${hostelFeeDue.toStringAsFixed(2)} due'),
                                              controlAffinity: ListTileControlAffinity.leading,
                                            ),
                                            if (payHostelFee) ...[
                                              const SizedBox(height: 8),
                                              TextField(
                                                controller: hostelPaymentController,
                                                decoration: InputDecoration(
                                                  labelText: 'Amount to Pay (Max: Rs.${hostelFeeDue.toStringAsFixed(2)})',
                                                  hintText: 'Enter amount to pay',
                                                  border: const OutlineInputBorder(),
                                                  suffixText: 'Rs.',
                                                ),
                                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                onChanged: (value) => setPaymentState(() {}),
                                              ),
                                              if (hostelPaymentController.text.isNotEmpty) ...[
                                                const SizedBox(height: 8),
                                                Container(
                                                  padding: const EdgeInsets.all(10),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF800000).withOpacity(0.05),
                                                    border: Border.all(color: const Color(0xFF800000).withOpacity(0.2), width: 1),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text('Amount Paying:', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500)),
                                                          Text('Rs.${hostelPaymentController.text.isEmpty ? '0.00' : double.tryParse(hostelPaymentController.text)?.toStringAsFixed(2) ?? '0.00'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green)),
                                                        ],
                                                      ),
                                                      Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text('Remaining After Payment:', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500)),
                                                          Text('Rs.${(hostelFeeDue - (double.tryParse(hostelPaymentController.text) ?? 0)).clamp(0, double.infinity).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.red)),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ],
                                        ),
                                      )
                                    else
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.green[100],
                                          border: Border.all(color: Colors.green, width: 1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.check_circle, color: Colors.green[700]),
                                            const SizedBox(width: 8),
                                            Text('Hostel Fee Fully Paid', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.green[700])),
                                          ],
                                        ),
                                      ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                    ],
                    // Bus Fee Section - Only for School Fee
                    if (hasBusRoute && _selectedPaymentType == 'School Fee') ...[
                      const SizedBox(height: 16),
                      FutureBuilder<double>(
                        future: SupabaseService.getBusFeeByRoute(_selectedStudent!.busRoute!),
                        builder: (context, busFeeSnap) {
                          if (busFeeSnap.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          final busFeeAmount = busFeeSnap.data ?? 0;

                          return FutureBuilder<double>(
                            future: SupabaseService.getBusFeePaid(_selectedStudent!.name),
                            builder: (context, paidSnap) {
                              final effectiveBusFee = (busFeeAmount - _selectedStudent!.busFeeConcession).clamp(0, double.infinity);
                              final busPaidAmount = paidSnap.data ?? 0;
                              final busFeeDue = (effectiveBusFee - busPaidAmount).clamp(0, double.infinity);
                              final isBusFeeFullyPaid = busFeeDue == 0 && busFeeAmount > 0;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF800000).withOpacity(0.05),
                                      border: Border.all(color: const Color(0xFF800000).withOpacity(0.2), width: 1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Bus Fee (Route: ${_selectedStudent!.busRoute})', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14, color: const Color(0xFF800000))),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('Total Fee:', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                                            Text('Rs.${effectiveBusFee.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                          ],
                                        ),
                                        if (busPaidAmount > 0) ...[
                                          const SizedBox(height: 6),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text('Already Paid:', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                                              Text('Rs.${busPaidAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green)),
                                            ],
                                          ),
                                        ],
                                        if (busFeeDue > 0) ...[
                                          const SizedBox(height: 6),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text('Remaining Due:', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                                              Text('Rs.${busFeeDue.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.red)),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  // Bus Fee Concession Input
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                    child: TextField(
                                      controller: busConcessionController,
                                      decoration: InputDecoration(
                                        labelText: 'Bus Fee Concession',
                                        border: const OutlineInputBorder(),
                                        suffixIcon: IconButton(
                                          icon: const Icon(Icons.save, color: Colors.green),
                                          onPressed: () async {
                                            final amount = double.tryParse(busConcessionController.text) ?? 0.0;
                                            final success = await SupabaseService.updateStudentConcession(
                                              _selectedStudent!.name,
                                              _selectedStudent!.schoolFeeConcession,
                                              amount, // New bus concession
                                              _selectedStudent!.hostelFeeConcession,
                                              _selectedStudent!.tuitionFeeConcession,
                                            );
                                            if (success) {
                                              setDialogState(() {
                                                _selectedStudent = _selectedStudent!.copyWith(busFeeConcession: amount);
                                              });
                                            }
                                          },
                                        ),
                                      ),
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  if (!isBusFeeFullyPaid)
                                    StatefulBuilder(
                                      builder: (context, setPaymentState) => Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          CheckboxListTile(
                                            value: payBusFee,
                                            onChanged: (v) {
                                              setDialogState(() => payBusFee = v ?? false);
                                              if (!payBusFee) {
                                                busFeePaymentController.clear();
                                              }
                                            },
                                            title: const Text('Pay Bus Fee', style: TextStyle(fontWeight: FontWeight.w600)),
                                            subtitle: Text('Rs.${busFeeDue.toStringAsFixed(2)} due'),
                                            controlAffinity: ListTileControlAffinity.leading,
                                          ),
                                          if (payBusFee) ...[
                                            const SizedBox(height: 8),
                                            TextField(
                                              controller: busFeePaymentController,
                                              decoration: InputDecoration(
                                                labelText: 'Amount to Pay (Max: Rs.${busFeeDue.toStringAsFixed(2)})',
                                                hintText: 'Enter bus fee amount',
                                                border: const OutlineInputBorder(),
                                              ),
                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            ),
                                          ],
                                        ],
                                      ),
                                    )
                                  else
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(color: Colors.green[100], border: Border.all(color: Colors.green), borderRadius: BorderRadius.circular(8)),
                                      child: Row(children: [Icon(Icons.check_circle, color: Colors.green[700]), const SizedBox(width: 8), Text('Bus Fee Paid Completely', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.green[700]))]),
                                    ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF800000),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: (_isSubmitting || 
                          (_selectedPaymentType == 'Books Fee' && _booksFeeAlreadyPaid) ||
                          (_selectedPaymentType == 'Uniform Fee' && _uniformFeeAlreadyPaid)) 
                          ? null 
                          : () async {
                          // Validate term fields only for School Fee
                          if (_selectedPaymentType == 'School Fee') {
                            if (termMonthController.value == null) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('Please select Term Month')));
                              return;
                            }
                            if (termYearController.value == null || termYearController.value!.isEmpty) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('Please select Term Year')));
                              return;
                            }
                          }
                          
                          if (amountController.text.isEmpty) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('Please enter Amount')));
                            return;
                          }
                          
                          // For School Fee, validate term selection
                          String selectedTermNos = '';
                          if (_selectedPaymentType == 'School Fee') {
                            selectedTermNos = termSelections.entries.where((e) => e.value).map((e) => 'Term ${e.key}').join(',');
                            if (selectedTermNos.isEmpty) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('Please select at least one Term')));
                              return;
                            }
                          } else {
                            // For non-School fees, use a default term value
                            selectedTermNos = 'N/A';
                          }
                          
                          setState(() => _isSubmitting = true);
                          try {
                            final currentYear = DateTime.now().year.toString();
                            
                            // Prepare list for bulk insertion
                            final List<Map<String, dynamic>> feesToInsert = [];
                            
                            // 1. School fee entry
                            feesToInsert.add({
                              'STUDENT NAME': _selectedStudent!.name,
                              'FEE TYPE': _selectedPaymentType!.trim(),
                              'AMOUNT': amountController.text.trim(),
                              'TERM YEAR': _selectedPaymentType == 'School Fee' ? termYearController.value : currentYear,
                              'TERM MONTH': _selectedPaymentType == 'School Fee' ? termMonthController.value : '',
                              'TERM NO': selectedTermNos,
                              'DATE': DateFormat('dd-MM-yyyy').format(_selectedDate ?? DateTime.now()),
                            });

                            // 2. Bus fee entry if selected
                            if (_selectedPaymentType == 'School Fee' && payBusFee && hasBusRoute) {
                              final busPaymentAmount = busFeePaymentController.text.trim();
                              if (busPaymentAmount.isNotEmpty) {
                                feesToInsert.add({
                                  'STUDENT NAME': _selectedStudent!.name,
                                  'FEE TYPE': 'Bus Fee',
                                  'AMOUNT': busPaymentAmount,
                                  'TERM YEAR': (termYearController.value != null && termYearController.value!.isNotEmpty) ? termYearController.value : currentYear,
                                  'TERM MONTH': termMonthController.value ?? '',
                                  'TERM NO': 'N/A',
                                  'DATE': DateFormat('dd-MM-yyyy').format(_selectedDate ?? DateTime.now()),
                                });
                              }
                            }
                            
                            // 3. Hostel fee entry if selected
                            if (_selectedPaymentType == 'School Fee' && payHostelFee && hasHostelFacility) {
                              final hostelPaymentAmount = hostelPaymentController.text.trim();
                              if (hostelPaymentAmount.isNotEmpty) {
                                feesToInsert.add({
                                  'STUDENT NAME': _selectedStudent!.name,
                                  'FEE TYPE': 'Hostel Fee',
                                  'AMOUNT': hostelPaymentAmount,
                                  'TERM YEAR': termYearController.value ?? currentYear,
                                  'TERM MONTH': termMonthController.value ?? '',
                                  'TERM NO': 'N/A',
                                  'DATE': DateFormat('dd-MM-yyyy').format(_selectedDate ?? DateTime.now()),
                                });
                              }
                            }
                            
                            // Perform bulk insertion so they have identical created_at timestamps
                            await SupabaseService.insertFees(feesToInsert);

                            final consolidatedReceiptData = {
                              'STUDENT NAME': _selectedStudent!.name,
                              'DATE': DateFormat('dd-MM-yyyy').format(_selectedDate ?? DateTime.now()),
                              'FEE TYPE': 'Combined Payment',
                              'AMOUNT': (double.tryParse(amountController.text.trim()) ?? 0).toString(),
                              'TERM NO': selectedTermNos,
                              'items': feesToInsert.map((f) => {
                                'desc': '${f['FEE TYPE']}${f['TERM NO'] != 'N/A' ? " (${f['TERM NO']})" : ""}',
                                'amount': double.tryParse(f['AMOUNT'].toString()) ?? 0
                              }).toList()
                            };
                            
                            if (mounted) {
                              Navigator.pop(dialogContext);
                              _showPaymentInvoiceDialog(consolidatedReceiptData);
                              
                              List<String> paidItems = feesToInsert.map((f) => f['FEE TYPE'] as String).toList();

                              final feeMessage = '${paidItems.join(' and ')} paid successfully';
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(feeMessage), backgroundColor: Colors.green),
                              );
                              setState(() {
                                if (_showPaymentHistory) _loadPaymentHistory();
                              });
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                              );
                            }
                          } finally {
                            if (mounted) {
                              setState(() => _isSubmitting = false);
                            }
                          }
                        },
                        child: _isSubmitting
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                            : const Text('Submit Payment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Close', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ));
  }

  @override
  void dispose() {
    _termYear.dispose();
    _feeType.dispose();
    _amount.dispose();
    _concession.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentPage == 0) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [const Color(0xFF800000).withOpacity(0.05), const Color(0xFF800000).withOpacity(0.05)],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Fees', style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w700, color: const Color(0xFF800000))),
              const SizedBox(height: 30),
              _menuButton(icon: Icons.payments, title: 'Payments', onPressed: () => setState(() => _currentPage = 1), color: const Color(0xFF800000)),
              const SizedBox(height: 16),
              _menuButton(icon: Icons.request_quote, title: 'Dues', onPressed: () => setState(() => _currentPage = 2), color: Colors.orange),
            ],
          ),
        ),
      );
    } else if (_currentPage == 1) {
      return _buildPaymentsPage();
    } else {
      return _buildDuesPage();
    }
  }

  Widget _menuButton({required IconData icon, required String title, required VoidCallback onPressed, required Color color}) {
    return SizedBox(
      height: 120,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 8,
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 40, color: Colors.white),
          const SizedBox(height: 10),
          Text(title, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white))
        ]),
      ),
    );
  }

  Widget _buildPaymentsPage() {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: SingleChildScrollView( 
        padding: const EdgeInsets.all(16), 
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ 
          Align(
            alignment: Alignment.topLeft,
            child: InkWell(
              onTap: () => setState(() => _currentPage = 0),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.arrow_back, size: 20, color: Color(0xFF800000)),
                    const SizedBox(width: 8),
                    Text(
                      'Back to Menu',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF800000),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24), 
          Text('Fee Payments', style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))), 
          const SizedBox(height: 20), 
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Payment Type',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [ 
                    _buildPaymentChip('School Fee', const Color(0xFF800000)),
                    _buildPaymentChip('Books Fee', const Color(0xFF10B981)),
                    _buildPaymentChip('Uniform Fee', const Color(0xFFF59E0B)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20), 
          if (_selectedPaymentType != null) ...[  
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Student Selection',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 20), 
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedClass,
                          items: _classes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                          onChanged: _onClassSelectedInFees,
                          decoration: InputDecoration(
                            labelText: 'Class',
                            filled: true,
                            fillColor: const Color(0xFFF1F5F9),
                            prefixIcon: const Icon(Icons.school_outlined, color: Color(0xFF800000)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedSection,
                          items: _sections.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                          onChanged: _selectedClass == null ? null : _onSectionSelectedInFees,
                          decoration: InputDecoration(
                            labelText: 'Section',
                            filled: true,
                            fillColor: _selectedClass == null ? const Color(0xFFE2E8F0) : const Color(0xFFF1F5F9),
                            prefixIcon: const Icon(Icons.grid_view_outlined, color: Color(0xFF800000)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ), 
                  const SizedBox(height: 24), 
                  SizedBox( 
                    width: double.infinity, 
                    height: 56,
                    child: ElevatedButton.icon( 
                      onPressed: (_selectedClass != null && _selectedSection != null) ? _openStudentSearchDialog : null,
                      icon: const Icon(Icons.search_outlined), 
                      label: Text('Search & Select Student', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)), 
                      style: ElevatedButton.styleFrom( 
                        backgroundColor: const Color(0xFF800000).withOpacity(0.1),
                        foregroundColor: const Color(0xFF800000),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ), 
                    ), 
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (_selectedStudent != null) ...[  
            const SizedBox(height: 16), 
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF800000).withOpacity(0.05),
                border: Border.all(color: const Color(0xFF800000).withOpacity(0.2), width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Selected: ${_selectedStudent!.name} (${_selectedStudent!.className})',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF800000),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // School Fee Concession Input
            if (_selectedPaymentType == 'School Fee')
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.3), blurRadius: 8)],
                ),
                child: TextField(
                  controller: _concession..text = _selectedStudent!.schoolFeeConcession.toStringAsFixed(2),
                  decoration: InputDecoration(
                    labelText: 'School Fee Concession',
                    hintText: 'Enter concession amount',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: Colors.yellow[100],
                    prefixIcon: const Icon(Icons.money_off, color: Colors.orange),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.save, color: Colors.green),
                      onPressed: _saveConcession,
                      tooltip: 'Save Concession',
                    ),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            const SizedBox(height: 16), 
            SizedBox( 
              width: double.infinity, 
              child: ElevatedButton.icon( 
                onPressed: _openPaymentScreen, 
                icon: const Icon(Icons.payment), 
                label: const Text('Open Payment Screen', style: TextStyle(fontWeight: FontWeight.w600)), 
                style: ElevatedButton.styleFrom( 
                  backgroundColor: Colors.green, 
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ), 
              ), 
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loadPaymentHistory,
                icon: const Icon(Icons.history),
                label: const Text('Payment History', style: TextStyle(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            if (_showPaymentHistory) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.3), blurRadius: 8)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Payment History', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF800000))),
                        IconButton(
                          onPressed: () => setState(() {
                            _showPaymentHistory = false;
                            _paymentHistory = [];
                          }),
                          icon: const Icon(Icons.close),
                          tooltip: 'Close',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_paymentHistory.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Column(
                            children: [
                              Icon(Icons.receipt_long, size: 48, color: Colors.grey[400]),
                              const SizedBox(height: 12),
                              Text(
                                'No payment history',
                                style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...(() {
                        // Grouping payments by date/time to show consolidated history bills
                        final Map<String, List<Map<String, dynamic>>> grouped = {};
                        for (final p in _paymentHistory) {
                          final date = p['DATE'] ?? 'N/A';
                          final timestamp = p['created_at'] != null ? p['created_at'].toString() : date; // Group ONLY by exact timestamp
                          grouped.putIfAbsent(timestamp, () => []).add(p);
                        }

                        return grouped.entries.map((entry) {
                          final items = entry.value;
                          final first = items.first;
                          final totalAmt = items.fold<double>(0, (sum, it) => sum + (double.tryParse(it['AMOUNT'].toString()) ?? 0));
                          final names = items.map((it) => it['FEE TYPE']).join(', ');
                          
                          // Format time and session ID for history display
                          String timeStr = '';
                          String sessionID = 'Fee_receipt_${first['DATE']}';
                          if (first['created_at'] != null) {
                            try {
                              final dt = DateTime.parse(first['created_at'].toString()).toLocal();
                              timeStr = DateFormat('HH:mm').format(dt);
                              sessionID = 'Fee_receipt_${DateFormat('yyyyMMdd_HHmm').format(dt)}';
                            } catch (_) {}
                          }

                          // Prepare data for the consolidated receipt viewer
                          final consolidatedMap =Map<String, dynamic>.from(first);
                          consolidatedMap['AMOUNT'] = totalAmt.toString();
                          consolidatedMap['RECEIPT_ID'] = sessionID; // Use session ID for display consistency
                          consolidatedMap['items'] = items.map((it) => {
                            'desc': '${it['FEE TYPE']} ${it['TERM NO'] != 'N/A' ? " (${it['TERM NO']})" : ""}',
                            'amount': double.tryParse(it['AMOUNT'].toString()) ?? 0
                          }).toList();

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 4,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            color: Colors.amber[50],
                            child: ListTile(
                              leading: Icon(Icons.receipt_long, color: Colors.deepOrange),
                              title: Text(
                                sessionID,
                                style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: const Color(0xFF800000)),
                              ),
                              subtitle: RichText(
                                text: TextSpan(
                                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700]),
                                  children: [
                                    TextSpan(text: '$names\n', style: const TextStyle(fontWeight: FontWeight.w600)),
                                    TextSpan(text: 'Total: Rs.${totalAmt.toStringAsFixed(0)} - ${first['DATE']} at $timeStr'),
                                  ],
                                ),
                              ),
                              isThreeLine: true,
                              trailing: ElevatedButton.icon(
                                onPressed: () => _showPaymentInvoiceDialog(consolidatedMap),
                                icon: const Icon(Icons.preview),
                                label: const Text('View', style: TextStyle(fontSize: 12)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                ),
                              ),
                            ),
                          );
                        });
                      })(),
                  ],
                ),
              ),
            ],
          ], 
        ]), 
      ),
    ); 
  }
  Widget _buildDuesPage() {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Align(
            alignment: Alignment.topLeft,
            child: InkWell(
              onTap: () => setState(() => _currentPage = 0),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.arrow_back, size: 20, color: Color(0xFF800000)),
                    const SizedBox(width: 8),
                    Text(
                      'Back to Menu',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF800000),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Outstanding Dues', style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fee Category',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildSelectionChip('School Fee', 'School & Bus Fees Due', const Color(0xFFF43F5E)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_selectedDueType != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Class Filter',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedDueClass,
                          items: _classes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                          onChanged: _onClassSelectedInDues,
                          decoration: InputDecoration(
                            labelText: 'Class',
                            filled: true,
                            fillColor: const Color(0xFFF1F5F9),
                            prefixIcon: const Icon(Icons.school_outlined, color: Color(0xFFF43F5E)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedDueSection,
                          items: _dueSections.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                          onChanged: _selectedDueClass == null ? null : _onSectionSelectedInDues,
                          decoration: InputDecoration(
                            labelText: 'Section',
                            filled: true,
                            fillColor: _selectedDueClass == null ? const Color(0xFFE2E8F0) : const Color(0xFFF1F5F9),
                            prefixIcon: const Icon(Icons.grid_view_outlined, color: Color(0xFFF43F5E)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Term Selection Checkboxes
            if (_selectedDueClass != null)
              Container(
                margin: const EdgeInsets.only(top: 20),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Term Visibility',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      title: const Text('Term 1', style: TextStyle(fontWeight: FontWeight.w600)),
                      value: _dueTerms['Term1'],
                      activeColor: const Color(0xFFF43F5E),
                      onChanged: (v) => setState(() => _dueTerms['Term1'] = v ?? false),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    CheckboxListTile(
                      title: const Text('Term 2', style: TextStyle(fontWeight: FontWeight.w600)),
                      value: _dueTerms['Term2'],
                      activeColor: const Color(0xFFF43F5E),
                      onChanged: (v) => setState(() => _dueTerms['Term2'] = v ?? false),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    CheckboxListTile(
                      title: const Text('Term 3', style: TextStyle(fontWeight: FontWeight.w600)),
                      value: _dueTerms['Term3'],
                      activeColor: const Color(0xFFF43F5E),
                      onChanged: (v) => setState(() => _dueTerms['Term3'] = v ?? false),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            // Excel Export Button
            if (_selectedDueClass != null && _dueStudents.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 24.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.download_outlined),
                    label: Text('Export Outstanding Dues (Excel)', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
                    onPressed: () => _exportDuesToExcel(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            if (_dueStudents.isNotEmpty && _selectedDueType != null) ...[
              Text('Students', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.orange[900])),
              const SizedBox(height: 12),
              for (final s in _dueStudents)
              if (_selectedDueType == 'School Fee')
                FutureBuilder<Map<String, dynamic>?>(
                  future: SupabaseService.getFeeStructureByClass(s.className.split('-').first),
                  builder: (context, structureSnap) {
                    final classNameOnly = s.className.split('-').first;
                    if (structureSnap.connectionState == ConnectionState.waiting) {
                      return const SizedBox();
                    }
                    final structure = structureSnap.data;
                    if (structure == null) return const SizedBox();
                    
                    // Get the fee structure amount and calculate term fees with 40/40/20 split
                    return FutureBuilder<Map<String, dynamic>?>(
                      future: SupabaseService.getFeeStructureByClass(classNameOnly),
                      builder: (context, finalStructureSnap) {
                    final structureFee = finalStructureSnap.data != null ? double.tryParse((finalStructureSnap.data!['FEE'] as dynamic).toString()) ?? 0 : 0;
                    final concession = s.schoolFeeConcession ;
                    final termFees = SupabaseService.calculateTermFees(structureFee.toDouble(), concession.toDouble());
                    
                    return FutureBuilder<List<Map<String, dynamic>>>(
                      future: SupabaseService.getFeesByStudent(s.name),
                      builder: (context, feesSnap) {
                        if (feesSnap.connectionState == ConnectionState.waiting) return const SizedBox();
                        final fees = feesSnap.data ?? [];
                        
                        final termsWithDue = <int, double>{};
                        for (int term = 1; term <= 3; term++) {
                          // Check if term is selected for filtering
                          final termKey = 'Term$term';
                          if (!(_dueTerms[termKey] ?? false) && _dueTerms.values.any((v) => v)) {
                            continue; // Skip if filtering by terms and this term not selected
                          }
                          
                          final termKeyFull = 'Term $term';
                          double paidAmount = 0;
                          
                          // Sum all payments for this specific term
                          for (final fee in fees) {
                            final feeType = (fee['FEE TYPE'] as String? ?? '').toLowerCase().trim();
                            final termNo = (fee['TERM NO'] as String? ?? '').toLowerCase().trim();
                            
                            // Match school fee payments for this term
                            if (feeType.contains('school fee') && termNo.contains(termKeyFull.toLowerCase())) {
                              final amt = double.tryParse((fee['AMOUNT'] as dynamic).toString()) ?? 0;
                              paidAmount += amt;
                            }
                          }
                          
                          // Get term fee from 40/40/20 calculation
                          final termFeeAmount = termFees[term] ?? 0;
                          
                          // Calculate due: term fee - total paid for this term
                          if (termFeeAmount > 0) {
                            final due = termFeeAmount - paidAmount;
                            if (due > 0) {
                              termsWithDue[term] = due;
                            }
                          }
                        }
                        
                        bool busFeeAlreadyPaid = false;
                        if (s.busRoute != null && s.busRoute!.isNotEmpty) {
                          final busPaidAmount = fees
                              .where((f) => (f['FEE TYPE'] as String? ?? '').contains('Bus Fee'))
                              .fold<double>(0, (sum, f) => sum + (double.tryParse((f['AMOUNT'] as dynamic).toString()) ?? 0));
                          busFeeAlreadyPaid = busPaidAmount > 0;
                        }
                        
                        return FutureBuilder<double>(
                          future: (s.busRoute != null && s.busRoute!.isNotEmpty && !busFeeAlreadyPaid)
                              ? SupabaseService.getBusFeeByRoute(s.busRoute!)
                              : Future.value(0),
                          builder: (context, busFeeSnap) {
                            if (busFeeSnap.connectionState == ConnectionState.waiting) return const SizedBox();
                            
                            final busFee = busFeeSnap.data ?? 0;
                            final hasBusFeesDue = busFee > 0 && !busFeeAlreadyPaid;
                            
                            if (termsWithDue.isEmpty && !hasBusFeesDue) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green[50],
                                  border: Border.all(color: Colors.green[300]!, width: 1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ListTile(
                                  title: Text(s.name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.green[900])),
                                  subtitle: const Text('All fees paid', style: TextStyle(color: Colors.green)),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('PAID', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                  ),
                                ),
                              );
                            }
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 4,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              color: Colors.red[50],
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.name,
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                        color: Colors.red[900],
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    if (termsWithDue.isNotEmpty) ...[
                                      Text(
                                        'School Fee:',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: Colors.orange[800],
                                        ),
                                      ),
                                      for (final term in termsWithDue.keys)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 6),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text('  Due Term $term', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.red[100],
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  'Rs.${termsWithDue[term]!.toStringAsFixed(2)}',
                                                  style: TextStyle(color: Colors.red[900], fontWeight: FontWeight.bold, fontSize: 14),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                    if (hasBusFeesDue) ...[
                                      if (termsWithDue.isNotEmpty) const SizedBox(height: 12),
                                      Text(
                                        'Bus Fee:',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: Colors.orange[800],
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 6),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('  Route: ${s.busRoute}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.red[100],
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                'Rs.${busFee.toStringAsFixed(2)}',
                                                style: TextStyle(color: Colors.red[900], fontWeight: FontWeight.bold, fontSize: 14),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    if ((termsWithDue.isNotEmpty || hasBusFeesDue) && (termsWithDue.length > 1 || (termsWithDue.isNotEmpty && hasBusFeesDue)))
                                      Padding(
                                        padding: const EdgeInsets.only(top: 16),
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.deepOrange[100],
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'Total Due',
                                                style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: Colors.deepOrange[900]),
                                              ),
                                              Text(
                                                'Rs.${(termsWithDue.values.fold<double>(0, (a, b) => a + b) + (hasBusFeesDue ? busFee : 0)).toStringAsFixed(2)}',
                                                style: TextStyle(
                                                  color: Colors.deepOrange[900],
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                      }
                    );
                  },
                ),
            ],
          ],
        ]),
      ),
    );
  }

  Widget _buildPaymentChip(String type, Color color) {
    bool isSelected = _selectedPaymentType == type;
    return InkWell(
      onTap: () => setState(() => _selectedPaymentType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : color.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: Text(
          type,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? Colors.white : color,
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionChip(String type, String title, Color color) {
    bool isSelected = _selectedDueType == type;
    return InkWell(
      onTap: () => setState(() => _selectedDueType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : [],
          border: Border.all(color: isSelected ? color : Colors.grey[200]!),
        ),
        child: Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }
}

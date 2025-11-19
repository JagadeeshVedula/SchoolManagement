import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:school_management/services/supabase_service.dart';
import 'package:school_management/models/student.dart';
import 'dart:io' show File;
import 'dart:typed_data' show Uint8List;
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html;

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
  List<Student> _dueStudents = [];
  final Map<String, bool> _dueTerms = {'Term1': false, 'Term2': false, 'Term3': false};
  
  // Payment History
  List<Map<String, dynamic>> _paymentHistory = [];
  bool _showPaymentHistory = false;

  // Track payment status for Books and Uniform fees
  bool _booksFeeAlreadyPaid = false;
  bool _uniformFeeAlreadyPaid = false;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    final classes = await SupabaseService.getUniqueClasses();
    setState(() => _classes = classes);
  }

  Future<void> _loadStudentsForClass(String className) async {
    final students = await SupabaseService.getStudentsByClass(className);
    setState(() {
      _students = students;
      _selectedStudent = null;
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fee recorded')));
      _selectedTermMonth = null;
      _termYear.clear(); _feeType.clear(); _amount.clear();
      _termSelections.updateAll((key, value) => false);
      setState(() { _currentPage = 0; _selectedPaymentType = null; _selectedClass = null; _students = []; _selectedStudent = null; });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to record fee')));
    }
  }

  Future<void> _saveConcession() async {
    if (_selectedStudent == null || _selectedPaymentType == null) return;
    
    final concessionAmount = double.tryParse(_concession.text.trim()) ?? 0;
    
    // Determine which concession to update
    double newSchoolFeeConcession = _selectedStudent!.schoolFeeConcession;
    double newTuitionFeeConcession = _selectedStudent!.tuitionFeeConcession;
    
    if (_selectedPaymentType == 'School Fee') {
      newSchoolFeeConcession = concessionAmount;
    }
    
    // Call supabase service to update
    final ok = await SupabaseService.updateStudentConcession(
      _selectedStudent!.name,
      newSchoolFeeConcession,
      newTuitionFeeConcession,
    );
    
    if (!mounted) return;
    
    if (ok) {
      // Update local student object to reflect new concession
      setState(() {
        _selectedStudent = Student(
          id: _selectedStudent!.id,
          name: _selectedStudent!.name,
          className: _selectedStudent!.className,
          fatherName: _selectedStudent!.fatherName,
          motherName: _selectedStudent!.motherName,
          parentMobile: _selectedStudent!.parentMobile,
          schoolFeeConcession: newSchoolFeeConcession,
          tuitionFeeConcession: newTuitionFeeConcession,
        );
        _concession.clear();
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Concession saved successfully'), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save concession'), backgroundColor: Colors.red),
      );
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
      for (final s in _students) {
        final structure = await SupabaseService.getFeeStructureByClass(s.className);
        if (structure == null) continue;
        
        final totalFee = double.tryParse((structure['FEE'] as dynamic).toString()) ?? 0;
        final concession = s.schoolFeeConcession;
        final termFees = SupabaseService.calculateTermFees(totalFee, concession);
        
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
        
        // For School Fee, show School Fee and Bus Fee
        if (_selectedPaymentType == 'School Fee') {
          return feeType.contains('School Fee') || feeType.contains('Bus Fee');
        }
        
        // For Books Fee and Uniform Fee, show only that specific fee type
        return feeType.contains(_selectedPaymentType!.trim());
      }).toList();
      
      setState(() {
        _paymentHistory = filteredPayments;
        _showPaymentHistory = true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading payment history: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _downloadInvoicePDF(Map<String, dynamic> payment) async {
    try {
      final pdf = pw.Document();
      
      final date = DateTime.now().toString().split(' ')[0];
      final receiptNo = 'REC${DateTime.now().millisecondsSinceEpoch.toString().substring(0, 8)}';
      final paidAmount = double.tryParse((payment['AMOUNT'] as dynamic).toString()) ?? 0;
      
      // Calculate balance amount
      double balanceAmount = 0;
      if (_selectedStudent != null && (payment['FEE TYPE'] as String? ?? '').contains('School Fee')) {
        final structure = await SupabaseService.getFeeStructureByClass(_selectedStudent!.className);
        if (structure != null) {
          final totalFee = double.tryParse((structure['FEE'] as dynamic).toString()) ?? 0;
          final concession = _selectedStudent!.schoolFeeConcession;
          final termFees = SupabaseService.calculateTermFees(totalFee, concession);
          
          // Extract term numbers from payment
          final termNoStr = payment['TERM NO'] as String? ?? '';
          final termNos = termNoStr.split(',').map((t) => int.tryParse(t.trim().replaceAll('Term ', '')) ?? 0).where((t) => t > 0).toList();
          
          double totalTermFee = 0;
          for (final term in termNos) {
            totalTermFee += termFees[term] ?? 0;
          }
          
          balanceAmount = (totalTermFee - paidAmount).clamp(0, double.infinity);
        }
      }
      
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text('FEE RECEIPT', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 12),
              pw.Divider(),
              pw.SizedBox(height: 12),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Receipt No:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text(receiptNo),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Date:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text(date),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Divider(),
              pw.SizedBox(height: 12),
              pw.Text('STUDENT DETAILS', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Name:'),
                  pw.Text(_selectedStudent!.name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Class:'),
                  pw.Text(_selectedStudent!.className, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Parent Mobile:'),
                  pw.Text(_selectedStudent!.parentMobile),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Divider(),
              pw.SizedBox(height: 12),
              pw.Text('PAYMENT DETAILS', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Fee Type:'),
                  pw.Text(payment['FEE TYPE'] as String, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Term(s):'),
                  pw.Text(payment['TERM NO'] as String),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Amount Paid:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('Rs. ${paidAmount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              if (balanceAmount > 0) ...[
                pw.SizedBox(height: 6),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Balance Due:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text('Rs. ${balanceAmount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.red)),
                  ],
                ),
              ],
              pw.SizedBox(height: 16),
              pw.Divider(),
              pw.SizedBox(height: 12),
              pw.Center(
                child: pw.Text('Payment received successfully', style: pw.TextStyle(fontSize: 12, fontStyle: pw.FontStyle.italic)),
              ),
            ],
          ),
        ),
      );
      
      final fileName = 'Invoice_${_selectedStudent!.name}_${DateTime.now().toString().split(' ')[0]}.pdf';
      final pdfBytes = await pdf.save();
      // Convert to List<int> for download
      final byteList = List<int>.from(pdfBytes);
      await _downloadFile(byteList, fileName);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF download failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showPaymentInvoiceDialog(Map<String, dynamic> payment) {
    final paidAmount = double.tryParse((payment['AMOUNT'] as dynamic).toString()) ?? 0;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment Invoice'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 400,
            child: FutureBuilder<Map<String, dynamic>?>(
              future: (payment['FEE TYPE'] as String? ?? '').contains('School Fee') && _selectedStudent != null
                  ? SupabaseService.getFeeStructureByClass(_selectedStudent!.className)
                  : Future.value(null),
              builder: (context, structureSnap) {
                if (structureSnap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                double calculatedBalance = 0;
                if (structureSnap.hasData && structureSnap.data != null && _selectedStudent != null) {
                  final structure = structureSnap.data!;
                  final totalFee = double.tryParse((structure['FEE'] as dynamic).toString()) ?? 0;
                  final concession = _selectedStudent!.schoolFeeConcession;
                  final termFees = SupabaseService.calculateTermFees(totalFee, concession);
                  
                  final termNoStr = payment['TERM NO'] as String? ?? '';
                  final termNos = termNoStr.split(',').map((t) => int.tryParse(t.trim().replaceAll('Term ', '')) ?? 0).where((t) => t > 0).toList();
                  
                  double totalTermFee = 0;
                  for (final term in termNos) {
                    totalTermFee += termFees[term] ?? 0;
                  }
                  
                  // Now fetch all payments for this student to calculate actual balance
                  return FutureBuilder<List<Map<String, dynamic>>>(
                    future: SupabaseService.getFeesByStudent(_selectedStudent!.name),
                    builder: (context, feesSnap) {
                      if (feesSnap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      final fees = feesSnap.data ?? [];
                      double totalPaidForTerms = 0;
                      
                      // Sum all payments for these specific terms
                      for (final term in termNos) {
                        final termKeyFull = 'Term $term';
                        for (final fee in fees) {
                          final feeType = (fee['FEE TYPE'] as String? ?? '').toLowerCase().trim();
                          final termNo = (fee['TERM NO'] as String? ?? '').toLowerCase().trim();
                          
                          if (feeType.contains('school fee') && termNo.contains(termKeyFull.toLowerCase())) {
                            final amt = double.tryParse((fee['AMOUNT'] as dynamic).toString()) ?? 0;
                            totalPaidForTerms += amt;
                          }
                        }
                      }
                      
                      calculatedBalance = (totalTermFee - totalPaidForTerms).clamp(0, double.infinity);
                      
                      return _buildInvoiceContent(payment, paidAmount, calculatedBalance, totalTermFee, totalPaidForTerms);
                    },
                  );
                }
                
                return _buildInvoiceContent(payment, paidAmount, calculatedBalance, 0, 0);
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _downloadInvoicePDF(payment),
            child: const Text('Download PDF'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceContent(Map<String, dynamic> payment, double paidAmount, double calculatedBalance, double totalTermFee, double totalPaid) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: Text('FEE RECEIPT', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        const Divider(),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Receipt No:', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            Text('REC${DateTime.now().millisecondsSinceEpoch.toString().substring(0, 8)}'),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Date:', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            Text(DateTime.now().toString().split(' ')[0]),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(),
        Text('STUDENT DETAILS', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Name:'),
            Text(_selectedStudent!.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Class:'),
            Text(_selectedStudent!.className, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Parent Mobile:'),
            Text(_selectedStudent!.parentMobile),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(),
        Text('PAYMENT DETAILS', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Fee Type:'),
            Text(payment['FEE TYPE'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Term(s):'),
            Text(payment['TERM NO'] as String),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Amount Paid (This Payment):', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            Text('₹${paidAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
          ],
        ),
        if (totalTermFee > 0) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Term Fee:', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              Text('₹${totalTermFee.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Paid (All Payments):', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              Text('₹${totalPaid.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blue)),
            ],
          ),
        ],
        if (calculatedBalance > 0) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Remaining Balance Due:', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              Text('₹${calculatedBalance.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red)),
            ],
          ),
        ] else if (totalTermFee > 0) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Status:', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              Text('FULLY PAID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green[700])),
            ],
          ),
        ],
        const SizedBox(height: 16),
        const Divider(),
        Center(
          child: Text('Payment received successfully', style: GoogleFonts.poppins(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.green)),
        ),
      ],
    );
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
      if (_selectedPaymentType == 'Books Fee') {
        final fee = await SupabaseService.getBooksFeeByClass(classWithoutSection);
        amountController.text = fee.toStringAsFixed(2);
      } else if (_selectedPaymentType == 'Uniform Fee' && _selectedStudent != null) {
        final gender = _selectedStudent!.gender ?? 'Male';
        final fee = await SupabaseService.getUniformFeeByClassAndGender(classWithoutSection, gender);
        amountController.text = fee.toStringAsFixed(2);
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
    if (_selectedPaymentType == 'Books Fee') {
      final isPaid = await _checkBooksFeeAlreadyPaid(_selectedStudent!.name);
      if (mounted) {
        setState(() => _booksFeeAlreadyPaid = isPaid);
      }
    } else if (_selectedPaymentType == 'Uniform Fee') {
      final isPaid = await _checkUniformFeeAlreadyPaid(_selectedStudent!.name);
      if (mounted) {
        setState(() => _uniformFeeAlreadyPaid = isPaid);
      }
    }

    // Local controllers for this dialog
    final termMonthController = ValueNotifier<String?>(_selectedTermMonth);
    final termYearController = TextEditingController();
    final amountController = TextEditingController();
    final termSelections = Map<int, bool>.from(_termSelections);
    
    // Extract class without section (e.g., "V-A" -> "V")
    final classWithoutSection = _selectedStudent!.className.split('-')[0];
    
    // Auto-populate amount based on payment type
    _populateAmountByFeeType(amountController, classWithoutSection);
    
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
              colors: [Colors.blue[50]!, Colors.indigo[100]!],
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
                          color: Colors.indigo[600],
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
                          color: Colors.blue[50],
                          border: Border.all(color: Colors.blue[200]!, width: 1),
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
                                color: Colors.blue[900],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Class: ${_selectedStudent!.className}',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                                color: Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
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
                            '⚠️ Already Paid',
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
                            '⚠️ Already Paid',
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
                    // Term Year - Only for School Fee
                    if (_selectedPaymentType == 'School Fee')
                      TextField(
                        controller: termYearController,
                        decoration: const InputDecoration(labelText: 'Term Year', border: OutlineInputBorder()),
                      ),
                    if (_selectedPaymentType == 'School Fee')
                      const SizedBox(height: 16),
                    // Amount
                    TextField(
                      controller: amountController,
                      decoration: const InputDecoration(labelText: 'Amount', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    // Term No Checkboxes - Only for School Fee
                    if (_selectedPaymentType == 'School Fee') ...[
                      Text('Select Term No', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12)),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        value: termSelections[1],
                        onChanged: (v) => setDialogState(() => termSelections[1] = v ?? false),
                        title: const Text('Term 1'),
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                      ),
                      CheckboxListTile(
                        value: termSelections[2],
                        onChanged: (v) => setDialogState(() => termSelections[2] = v ?? false),
                        title: const Text('Term 2'),
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                      ),
                      CheckboxListTile(
                        value: termSelections[3],
                        onChanged: (v) => setDialogState(() => termSelections[3] = v ?? false),
                        title: const Text('Term 3'),
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
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
                            if (termYearController.text.isEmpty) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('Please enter Term Year')));
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
                            final feeData = {
                              'STUDENT NAME': _selectedStudent!.name,
                              'FEE TYPE': _selectedPaymentType!.trim(),
                              'AMOUNT': amountController.text.trim(),
                              'TERM YEAR': _selectedPaymentType == 'School Fee' ? termYearController.text.trim() : currentYear,
                              'TERM MONTH': _selectedPaymentType == 'School Fee' ? termMonthController.value : '',
                              'TERM NO': selectedTermNos,
                            };
                            await SupabaseService.insertFee(feeData);
                            if (mounted) {
                              Navigator.pop(dialogContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('${_selectedPaymentType!.trim()} paid successfully'), backgroundColor: Colors.green),
                              );
                              setState(() {
                                _selectedPaymentType = null;
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
            colors: [Colors.blue[50]!, Colors.indigo[100]!],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Fees', style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.indigo[900])),
              const SizedBox(height: 30),
              _menuButton(icon: Icons.payments, title: 'Payments', onPressed: () => setState(() => _currentPage = 1), color: Colors.blue),
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
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue[50]!, Colors.cyan[100]!],
        ),
      ),
      child: SingleChildScrollView( 
        padding: const EdgeInsets.all(16), 
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ 
          ElevatedButton.icon( 
            onPressed: () => setState(() => _currentPage = 0), 
            icon: const Icon(Icons.arrow_back), 
            label: const Text('Back'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
            ),
          ), 
          const SizedBox(height: 16), 
          Text('Payments', style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.indigo[900])), 
          const SizedBox(height: 20), 
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.3), blurRadius: 8)],
            ),
            child: Wrap(spacing: 10, runSpacing: 10, children: [ 
              ChoiceChip( 
                label: const Text('School Fee', style: TextStyle(fontWeight: FontWeight.w600)), 
                selected: _selectedPaymentType == 'School Fee',
                backgroundColor: Colors.grey[200],
                selectedColor: Colors.blue,
                labelStyle: TextStyle(
                  color: _selectedPaymentType == 'School Fee' ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w600,
                ),
                onSelected: (_) => setState(() {
                  _selectedPaymentType = 'School Fee';
                  _showPaymentHistory = false;
                }), 
              ), 
              ChoiceChip( 
                label: const Text('Books Fee', style: TextStyle(fontWeight: FontWeight.w600)), 
                selected: _selectedPaymentType == 'Books Fee',
                backgroundColor: Colors.grey[200],
                selectedColor: Colors.green,
                labelStyle: TextStyle(
                  color: _selectedPaymentType == 'Books Fee' ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w600,
                ),
                onSelected: (_) => setState(() {
                  _selectedPaymentType = 'Books Fee';
                  _showPaymentHistory = false;
                }), 
              ), 
              ChoiceChip( 
                label: const Text('Uniform Fee', style: TextStyle(fontWeight: FontWeight.w600)), 
                selected: _selectedPaymentType == 'Uniform Fee',
                backgroundColor: Colors.grey[200],
                selectedColor: Colors.orange,
                labelStyle: TextStyle(
                  color: _selectedPaymentType == 'Uniform Fee' ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w600,
                ),
                onSelected: (_) => setState(() {
                  _selectedPaymentType = 'Uniform Fee';
                  _showPaymentHistory = false;
                }), 
              ), 
            ]),
          ),
          const SizedBox(height: 20), 
          if (_selectedPaymentType != null) ...[  
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
                  Text('Select Class', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.indigo[800])), 
                  const SizedBox(height: 12), 
                  DropdownButtonFormField<String>( 
                    value: _selectedClass, 
                    items: _classes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), 
                    onChanged: (v) { 
                      setState(() { 
                        _selectedClass = v; 
                        _selectedStudent = null; 
                        _students = []; 
                      }); 
                      if (v != null) _loadStudentsForClass(v); 
                    }, 
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ), 
                  ), 
                  const SizedBox(height: 16), 
                  SizedBox( 
                    width: double.infinity, 
                    child: ElevatedButton.icon( 
                      onPressed: _openStudentSearchDialog, 
                      icon: const Icon(Icons.search), 
                      label: const Text('Search & Select Student', style: TextStyle(fontWeight: FontWeight.w600)), 
                      style: ElevatedButton.styleFrom( 
                        backgroundColor: Colors.blue, 
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ), 
                    ), 
                  ),
                ],
              ),
            ),
          ], 
          if (_selectedStudent != null) ...[  
            const SizedBox(height: 16), 
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                border: Border.all(color: Colors.blue[200]!, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Selected: ${_selectedStudent!.name} (${_selectedStudent!.className})',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[900],
                ),
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
            if (_showPaymentHistory && _paymentHistory.isNotEmpty) ...[
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
                    Text('Payment History', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.indigo[900])),
                    const SizedBox(height: 16),
                    ..._paymentHistory.map((payment) => Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      color: Colors.amber[50],
                      child: ListTile(
                        leading: Icon(Icons.receipt_long, color: Colors.deepOrange),
                        title: Text(
                          payment['FEE TYPE'] as String,
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.indigo[900]),
                        ),
                        subtitle: Text('₹${payment['AMOUNT']} - ${payment['TERM NO']}', style: const TextStyle(color: Colors.grey)),
                        trailing: ElevatedButton.icon(
                          onPressed: () => _showPaymentInvoiceDialog(payment),
                          icon: const Icon(Icons.preview),
                          label: const Text('View', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                          ),
                        ),
                      ),
                    )).toList(),
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
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.orange[50]!, Colors.amber[100]!],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ElevatedButton.icon(
            onPressed: () => setState(() => _currentPage = 0), 
            icon: const Icon(Icons.arrow_back), 
            label: const Text('Back'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
            ),
          ),
          const SizedBox(height: 16),
          Text('Dues', style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.orange[900])),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.3), blurRadius: 8)],
            ),
            child: Wrap(spacing: 10, children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedDueType == 'School Fee' ? Colors.deepOrange : Colors.grey[300],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => setState(() => _selectedDueType = 'School Fee'),
                child: Text(
                  'School & Bus Fees Due',
                  style: TextStyle(
                    color: _selectedDueType == 'School Fee' ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          if (_selectedDueType != null) ...[
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
                  Text('Select Class', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.orange[800])),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedClass,
                    items: _classes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) {
                      setState(() { _selectedClass = v; _students = []; _selectedStudent = null; });
                      if (v != null) _loadStudentsForClass(v);
                    },
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Term Selection Checkboxes
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
                  Text('Filter by Terms', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.orange[800])),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    title: const Text('Term 1', style: TextStyle(fontWeight: FontWeight.w600)),
                    value: _dueTerms['Term1'],
                    activeColor: Colors.deepOrange,
                    onChanged: (v) => setState(() => _dueTerms['Term1'] = v ?? false),
                  ),
                  CheckboxListTile(
                    title: const Text('Term 2', style: TextStyle(fontWeight: FontWeight.w600)),
                    value: _dueTerms['Term2'],
                    activeColor: Colors.deepOrange,
                    onChanged: (v) => setState(() => _dueTerms['Term2'] = v ?? false),
                  ),
                  CheckboxListTile(
                    title: const Text('Term 3', style: TextStyle(fontWeight: FontWeight.w600)),
                    value: _dueTerms['Term3'],
                    activeColor: Colors.deepOrange,
                    onChanged: (v) => setState(() => _dueTerms['Term3'] = v ?? false),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Excel Export Button
            if (_selectedClass != null && _students.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.download),
                  label: const Text('Export to Excel', style: TextStyle(fontWeight: FontWeight.w600)),
                  onPressed: () => _exportDuesToExcel(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            if (_students.isNotEmpty && _selectedDueType != null) ...[
              Text('Students', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.orange[900])),
              const SizedBox(height: 12),
              for (final s in _students)
              if (_selectedDueType == 'School Fee')
                FutureBuilder<Map<String, dynamic>?>(
                  future: SupabaseService.getFeeStructureByClass(s.className),
                  builder: (context, structureSnap) {
                    if (structureSnap.connectionState == ConnectionState.waiting) {
                      return const SizedBox();
                    }
                    final structure = structureSnap.data;
                    if (structure == null) return const SizedBox();
                    
                    // Get the fee structure amount and calculate term fees with 40/40/20 split
                    final structureFee = double.tryParse((structure['FEE'] as dynamic).toString()) ?? 0;
                    final concession = s.schoolFeeConcession;
                    final termFees = SupabaseService.calculateTermFees(structureFee, concession);
                    
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
                                                  '₹${termsWithDue[term]!.toStringAsFixed(2)}',
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
                                                '₹${busFee.toStringAsFixed(2)}',
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
                                                '₹${(termsWithDue.values.fold<double>(0, (a, b) => a + b) + (hasBusFeesDue ? busFee : 0)).toStringAsFixed(2)}',
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
                  },
                ),
            ],
          ],]
        ),
  
      ),
    );
  }
}

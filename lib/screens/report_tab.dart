import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:school_management/models/staff.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:school_management/services/supabase_service.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io' show File;
import 'dart:typed_data' show Uint8List;
import 'dart:html' as html;

class ReportTab extends StatefulWidget {
  const ReportTab({super.key});

  @override
  State<ReportTab> createState() => _ReportTabState();
}

class _ReportTabState extends State<ReportTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Fee Report State
  String? _selectedFeeType = 'School Fee'; // Only 'School Fee' now
  String? _selectedFeeClass;
  List<String> _classes = [];
  List<Map<String, dynamic>> _feeReportData = [];
  bool _isFeeLoading = false;

  // Diesel Report State
  DateTimeRange? _dieselDateRange;
  List<Map<String, dynamic>> _dieselReportData = [];
  bool _isDieselLoading = false;

  // Transactions Report State
  DateTimeRange? _transactionsDateRange;
  List<Map<String, dynamic>> _transactionsReportData = [];
  bool _isTransactionsLoading = false;

  // Staff Leave Report State
  List<Staff> _staffList = [];
  Staff? _selectedStaff;
  String _selectedLeaveMonth = DateFormat('yyyy-MM').format(DateTime.now());
  List<Map<String, dynamic>> _staffLeaveReportData = [];
  bool _isStaffLeaveLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadClasses();
    _loadStaff();
    _dieselDateRange = DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 7)),
      end: DateTime.now(),
    );
    _transactionsDateRange = DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 7)),
      end: DateTime.now(),
    );

    // Add a listener to the TabController to load data when a tab is selected.
    _tabController.addListener(() {
      // Rebuild the widget to update tab colors
      setState(() {});

      if (_tabController.indexIsChanging) {
        switch (_tabController.index) {
          case 1: // Diesel Report
            if (_dieselReportData.isEmpty) _loadDieselReportData();
            break;
          case 2: // Transactions Report
            if (_transactionsReportData.isEmpty) _loadTransactionsReportData();
            break;
          case 3: // Staff Leave Report
            if (_staffLeaveReportData.isEmpty && _selectedStaff != null) _loadStaffLeaveReportData();
            break;
        }
      }
    });
  }

  Future<void> _loadClasses() async {
    final classes = await SupabaseService.getUniqueClasses();
    setState(() => _classes = classes);
  }

  Future<void> _loadStaff() async {
    final staff = await SupabaseService.getAllStaff();
    setState(() => _staffList = staff);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // #region Data Loading Methods

  Future<void> _loadFeeReportData() async {
    if (_selectedFeeType == null || _selectedFeeClass == null) return;

    setState(() => _isFeeLoading = true);

    try {
      final students = await SupabaseService.getStudentsByClass(_selectedFeeClass!);
      final reportData = <Map<String, dynamic>>[];

      for (final student in students) {
        final fees = await SupabaseService.getFeesByStudent(student.name);
        final feeStructure = await SupabaseService.getFeeStructureByClass(student.className);
        if (feeStructure == null) continue;

        final totalFee = double.tryParse((feeStructure['FEE'] as dynamic).toString()) ?? 0;
        final concession = student.schoolFeeConcession;
        
        // Calculate term fees
        final termFees = SupabaseService.calculateTermFees(totalFee, concession);

        // Calculate bus fee info
        final busFee = await SupabaseService.getStudentBusFee(student.name);
        double busFeeCheckPaid = 0;
        for (final fee in fees) {
          if ((fee['FEE TYPE'] as String? ?? '') == 'Bus Fee') {
            busFeeCheckPaid += double.tryParse((fee['AMOUNT'] as dynamic).toString()) ?? 0;
          }
        }
        final busFeedue = busFee > 0 ? (busFee - busFeeCheckPaid).clamp(0, double.infinity) : 0;

        // Get Books Fee and Uniform Fee
        final booksFeeFull = await SupabaseService.getBooksFeeByClass(student.className);
        double booksFeePaid = 0;
        for (final fee in fees) {
          if ((fee['FEE TYPE'] as String? ?? '').contains('Books Fee')) {
            booksFeePaid += double.tryParse((fee['AMOUNT'] as dynamic).toString()) ?? 0;
          }
        }
        final booksFeedue = booksFeeFull > 0 ? (booksFeeFull - booksFeePaid).clamp(0, double.infinity) : 0;

        final uniformFeeFull = await SupabaseService.getUniformFeeByClassAndGender(student.className, student.gender ?? 'Male');
        double uniformFeePaid = 0;
        for (final fee in fees) {
          if ((fee['FEE TYPE'] as String? ?? '').contains('Uniform Fee')) {
            uniformFeePaid += double.tryParse((fee['AMOUNT'] as dynamic).toString()) ?? 0;
          }
        }
        final uniformFeedue = uniformFeeFull > 0 ? (uniformFeeFull - uniformFeePaid).clamp(0, double.infinity) : 0;

        // Build term data for each term (single row per student with term1, term2, term3 columns)
        final Map<String, dynamic> termData = {
          'Student Name': student.name,
          'Class': student.className,
          'Gender': student.gender ?? 'N/A',
        };

        // Process each term
        for (int term = 1; term <= 3; term++) {
          final termKey = 'Term $term';
          double termPaidAmount = 0;

          for (final fee in fees) {
            final feeType = (fee['FEE TYPE'] as String? ?? '').trim().toLowerCase();
            final termNo = (fee['TERM NO'] as String? ?? '').trim();

            if (feeType == 'school fee' && termNo.contains(termKey)) {
              termPaidAmount += double.tryParse((fee['AMOUNT'] as dynamic).toString()) ?? 0;
            }
          }

          final termFee = termFees[term] ?? 0;
          final termDue = (termFee - termPaidAmount).clamp(0, double.infinity);
          
          termData['Term$term Fee'] = termFee;
          termData['Term$term Paid'] = termPaidAmount;
          termData['Term$term Due'] = termDue;
        }

        // Add Bus Fee details
        termData['Bus Fee'] = busFee;
        termData['Bus Fee Paid'] = busFeeCheckPaid;
        termData['Bus Fee Due'] = busFeedue;

        // Add Books Fee details
        termData['Books Fee'] = booksFeeFull;
        termData['Books Fee Paid'] = booksFeePaid;
        termData['Books Fee Due'] = booksFeedue;

        // Add Uniform Fee details
        termData['Uniform Fee'] = uniformFeeFull;
        termData['Uniform Fee Paid'] = uniformFeePaid;
        termData['Uniform Fee Due'] = uniformFeedue;

        // Calculate overall status
        final totalDue = termData['Term1 Due'] + termData['Term2 Due'] + termData['Term3 Due'] + busFeedue + booksFeedue + uniformFeedue;
        termData['Overall Status'] = totalDue <= 0 ? 'PAID' : 'PENDING';

        reportData.add(termData);
      }

      setState(() {
        _feeReportData = reportData;
        _isFeeLoading = false;
      });
    } catch (e) {
      setState(() => _isFeeLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading report: $e')),
      );
    }
  }

  Future<void> _loadDieselReportData() async {
    if (_dieselDateRange == null) return;
    setState(() => _isDieselLoading = true);
    final data = await SupabaseService.getDieselDataForReport(
      _dieselDateRange!.start,
      _dieselDateRange!.end,
    );
    setState(() {
      _dieselReportData = data;
      _isDieselLoading = false;
    });
  }

  Future<void> _loadTransactionsReportData() async {
    if (_transactionsDateRange == null) return;
    setState(() => _isTransactionsLoading = true);
    final data = await SupabaseService.getTransactionsForReport(
      _transactionsDateRange!.start,
      _transactionsDateRange!.end,
    );
    setState(() {
      _transactionsReportData = data;
      _isTransactionsLoading = false;
    });
  }

  Future<void> _loadStaffLeaveReportData() async {
    if (_selectedStaff == null) return;
    setState(() => _isStaffLeaveLoading = true);
    final data = await SupabaseService.getStaffLeaveForReport(
      staffName: _selectedStaff!.name,
      monthYear: _selectedLeaveMonth,
    );
    setState(() {
      _staffLeaveReportData = data;
      _isStaffLeaveLoading = false;
    });
  }

  // #endregion

  // #region Excel Export Methods

  Future<void> _downloadFeeExcel() async {
    if (_feeReportData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data to download')),
      );
      return;
    }

    try {
      final excel = excel_pkg.Excel.createExcel();
      final sheet = excel['Sheet1'];

      // Add header with proper columns for single-row-per-student format
      final headers = [
        'Student Name', 'Class', 'Gender',
        'Term1 Fee', 'Term1 Paid', 'Term1 Due',
        'Term2 Fee', 'Term2 Paid', 'Term2 Due',
        'Term3 Fee', 'Term3 Paid', 'Term3 Due',
        'Bus Fee', 'Bus Fee Paid', 'Bus Fee Due',
        'Books Fee', 'Books Fee Paid', 'Books Fee Due',
        'Uniform Fee', 'Uniform Fee Paid', 'Uniform Fee Due',
        'Overall Status'
      ];

      for (int i = 0; i < headers.length; i++) {
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).value = headers[i];
      }

      // Add data rows (one row per student)
      for (int rowIndex = 0; rowIndex < _feeReportData.length; rowIndex++) {
        final data = _feeReportData[rowIndex];
        int colIndex = 0;
        
        // Student info
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex + 1)).value = data['Student Name'];
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex + 1)).value = data['Class'];
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex + 1)).value = data['Gender'];
        
        // Term 1-3 columns
        for (int term = 1; term <= 3; term++) {
          sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex + 1)).value = _formatAmount(data['Term$term Fee'] as double?);
          sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex + 1)).value = _formatAmount(data['Term$term Paid'] as double?);
          sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex + 1)).value = _formatAmount(data['Term$term Due'] as double?);
        }
        
        // Bus Fee
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex + 1)).value = _formatAmount(data['Bus Fee'] as double?);
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex + 1)).value = _formatAmount(data['Bus Fee Paid'] as double?);
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex + 1)).value = _formatAmount(data['Bus Fee Due'] as double?);
        
        // Books Fee
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex + 1)).value = _formatAmount(data['Books Fee'] as double?);
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex + 1)).value = _formatAmount(data['Books Fee Paid'] as double?);
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex + 1)).value = _formatAmount(data['Books Fee Due'] as double?);
        
        // Uniform Fee
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex + 1)).value = _formatAmount(data['Uniform Fee'] as double?);
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex + 1)).value = _formatAmount(data['Uniform Fee Paid'] as double?);
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex + 1)).value = _formatAmount(data['Uniform Fee Due'] as double?);
        
        // Overall Status
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex + 1)).value = data['Overall Status'];
      }

      // Get bytes and download
      final bytes = excel.encode();
      if (bytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error encoding Excel file')),
        );
        return;
      }

      final fileName = 'School_Fee_Report_${DateFormat('yyyy-MM-dd_HHmmss').format(DateTime.now())}.xlsx';
      
      // Platform-specific download
      if (kIsWeb) {
        // Web: create download link
        _downloadFileWeb(bytes, fileName);
      } else {
        // Mobile/Desktop: save to Downloads directory
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving file: $e')),
          );
          return;
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Report downloaded: $fileName')),
      );
    } catch (e) {
      print('Error downloading report: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error downloading report: $e')),
      );
    }
  }

  Future<void> _downloadGenericExcel(List<Map<String, dynamic>> data, String fileNamePrefix) async {
    if (data.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data to download')),
      );
      return;
    }

    try {
      final excel = excel_pkg.Excel.createExcel();
      final sheet = excel['Sheet1'];

      // Headers from the keys of the first map
      final headers = data.first.keys.toList();
      sheet.appendRow(headers);

      // Data rows
      for (final rowData in data) {
        final row = headers.map((header) => rowData[header]).toList();
        sheet.appendRow(row);
      }

      final bytes = excel.encode();
      if (bytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error encoding Excel file')),
        );
        return;
      }

      final fileName = '${fileNamePrefix}_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.xlsx';
      await _downloadFile(bytes, fileName);

    } catch (e) {
      print('Error downloading generic excel: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error downloading report: $e')),
      );
    }
  }

  // #endregion

  // #region Helper and Build Methods

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

  Future<void> _downloadFile(List<int> bytes, String fileName) async {
    if (kIsWeb) {
      _downloadFileWeb(bytes, fileName);
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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          // Header with gradient background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[700]!, Colors.blue[400]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fee Reports',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Generate and download fee collection reports by class and fee type',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabController,
            indicatorColor: _getTabColor(_tabController.index),
            indicatorWeight: 4.0,
            labelColor: _getTabColor(_tabController.index),
            unselectedLabelColor: Colors.grey[600],
            isScrollable: true,
            tabs: const [
              Tab(text: 'Fee Report'),
              Tab(text: 'Diesel Report'),
              Tab(text: 'Transactions Report'),
              Tab(text: 'Staff Leave Report'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildFeeReportTab(),
                _buildDieselReportTab(),
                _buildTransactionsReportTab(),
                _buildStaffLeaveReportTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeeReportTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),

          // Fee Type Selection
          Text(
            'Select Fee Type',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildFeeTypeChip('School Fee', Colors.green),
            ],
          ),
          const SizedBox(height: 24),

          // Class Selection
          if (_selectedFeeType != null) ...[
            Text(
              'Select Class',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blue[300]!, width: 2),
                borderRadius: BorderRadius.circular(8),
                color: Colors.blue[50],
              ),
              child: DropdownButton<String>(
                isExpanded: true,
                value: _selectedFeeClass,
                hint: Text(
                  'Choose a class',
                  style: GoogleFonts.poppins(color: Colors.grey),
                ),
                underline: const SizedBox(),
                items: _classes
                    .map((className) => DropdownMenuItem<String>(
                          value: className,
                          child: Text(
                            className,
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                          ),
                        ))
                    .toList(),
                onChanged: (className) {
                  setState(() {
                    _selectedFeeClass = className;
                    _feeReportData = [];
                  });
                  if (className != null) {
                    _loadFeeReportData();
                  }
                },
              ),
            ),
            const SizedBox(height: 24),

            // Report Data Display
            if (_isFeeLoading)
              const Center(child: CircularProgressIndicator())
            else if (_feeReportData.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Report Data (${_feeReportData.length} records)',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _downloadFeeExcel,
                    icon: const Icon(Icons.download),
                    label: const Text('Download Excel'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Report Table
              _buildFeeReportTable(),
            ] else if (_selectedFeeClass != null && !_isFeeLoading)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.info_outline, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No fee data found for selected class',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildDieselReportTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          ListTile(
            title: const Text('Select Date Range'),
            subtitle: Text(
              '${DateFormat.yMMMd().format(_dieselDateRange!.start)} - ${DateFormat.yMMMd().format(_dieselDateRange!.end)}',
            ),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                initialDateRange: _dieselDateRange,
              );
              if (picked != null) {
                setState(() => _dieselDateRange = picked);
                _loadDieselReportData();
              }
            },
          ),
          ElevatedButton.icon(
            onPressed: () => _downloadGenericExcel(_dieselReportData, 'Diesel_Report'),
            icon: const Icon(Icons.download),
            label: const Text('Export to Excel'),
          ),
          Expanded(
            child: _isDieselLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    children: [
                      DataTable(
                        columns: const [
                          DataColumn(label: Text('Date')),
                          DataColumn(label: Text('Route No')),
                          DataColumn(label: Text('Litres')),
                          DataColumn(label: Text('Amount')),
                        ],
                        rows: _dieselReportData
                            .map((row) => DataRow(cells: [
                                  DataCell(Text(row['FilledDate']?.toString() ?? '')),
                                  DataCell(Text(row['RouteNo']?.toString() ?? '')),
                                  DataCell(Text(row['FilledLitres']?.toString() ?? '')),
                                  DataCell(Text(row['Amount']?.toString() ?? '')),
                                ]))
                            .toList(),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsReportTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          ListTile(
            title: const Text('Select Date Range'),
            subtitle: Text(
              '${DateFormat.yMMMd().format(_transactionsDateRange!.start)} - ${DateFormat.yMMMd().format(_transactionsDateRange!.end)}',
            ),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                initialDateRange: _transactionsDateRange,
              );
              if (picked != null) {
                setState(() => _transactionsDateRange = picked);
                _loadTransactionsReportData();
              }
            },
          ),
          ElevatedButton.icon(
            onPressed: () => _downloadGenericExcel(_transactionsReportData, 'Transactions_Report'),
            icon: const Icon(Icons.download),
            label: const Text('Export to Excel'),
          ),
          Expanded(
            child: _isTransactionsLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    children: [
                      DataTable(
                        columns: const [
                          DataColumn(label: Text('Date')),
                          DataColumn(label: Text('Account')),
                          DataColumn(label: Text('Description')),
                          DataColumn(label: Text('Type')),
                          DataColumn(label: Text('Amount')),
                        ],
                        rows: _transactionsReportData
                            .map((row) => DataRow(cells: [
                                  DataCell(Text(row['DATE']?.toString() ?? '')),
                                  DataCell(Text(row['ACCOUNT']?.toString() ?? '')),
                                  DataCell(Text(row['DESCRIPTION']?.toString() ?? '')),
                                  DataCell(Text(row['TYPE']?.toString() ?? '')),
                                  DataCell(Text(row['AMOUNT']?.toString() ?? '')),
                                ]))
                            .toList(),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffLeaveReportTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          DropdownButtonFormField<Staff>(
            value: _selectedStaff,
            hint: const Text('Select Staff'),
            items: _staffList.map((staff) => DropdownMenuItem(value: staff, child: Text(staff.name))).toList(),
            onChanged: (staff) {
              setState(() => _selectedStaff = staff);
              if (staff != null) _loadStaffLeaveReportData();
            },
          ),
          DropdownButtonFormField<String>(
            value: _selectedLeaveMonth,
            hint: const Text('Select Month'),
            items: List.generate(12, (i) {
              final date = DateTime(DateTime.now().year, DateTime.now().month - i, 1);
              return DateFormat('yyyy-MM').format(date);
            }).map((month) => DropdownMenuItem(value: month, child: Text(month))).toList(),
            onChanged: (month) {
              setState(() => _selectedLeaveMonth = month!);
              if (_selectedStaff != null) _loadStaffLeaveReportData();
            },
          ),
          ElevatedButton.icon(
            onPressed: () => _downloadGenericExcel(_staffLeaveReportData, 'Staff_Leave_Report'),
            icon: const Icon(Icons.download),
            label: const Text('Export to Excel'),
          ),
          Expanded(
            child: _isStaffLeaveLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    children: [
                      DataTable(
                        columns: const [
                          DataColumn(label: Text('Staff Name')),
                          DataColumn(label: Text('Leave Date')),
                          DataColumn(label: Text('Reason')),
                          DataColumn(label: Text('Status')),
                        ],
                        rows: _staffLeaveReportData
                            .map((row) => DataRow(cells: [
                                  DataCell(Text(row['LEAVEDATE']?.toString() ?? '')),
                                  DataCell(Text(row['STAFF']?.toString() ?? '')),
                                  DataCell(Text(row['REASON']?.toString() ?? '')),
                                  DataCell(
                                    Text(
                                      (row['APPROVED'] == 'YES')
                                          ? 'Approved'
                                          : (row['REJECTED'] == 'YES' ? 'Rejected' : 'Pending'),
                                    ),
                                  ),
                                ]))
                            .toList(),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeeTypeChip(String label, Color color) {
    final isSelected = _selectedFeeType == label;
    return ChoiceChip(
      label: Text(
        label,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          color: isSelected ? Colors.white : color,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFeeType = selected ? label : null;
          _selectedFeeClass = null;
          _feeReportData = [];
        });
      },
      backgroundColor: Colors.white,
      selectedColor: color,
      side: BorderSide(
        color: color,
        width: 2,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }

  Widget _buildFeeReportTable() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: DataTable(
            headingRowColor: MaterialStateProperty.all(Colors.blue[700]),
            headingRowHeight: 56,
            dataRowHeight: 80,
            columns: [
              DataColumn(
                label: Text(
                  'Student Name',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'Class',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'Gender',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              // Term 1 columns
              DataColumn(
                label: Text(
                  'T1 Fee',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              DataColumn(
                label: Text(
                  'T1 Paid',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              DataColumn(
                label: Text(
                  'T1 Due',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              // Term 2 columns
              DataColumn(
                label: Text(
                  'T2 Fee',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              DataColumn(
                label: Text(
                  'T2 Paid',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              DataColumn(
                label: Text(
                  'T2 Due',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              // Term 3 columns
              DataColumn(
                label: Text(
                  'T3 Fee',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              DataColumn(
                label: Text(
                  'T3 Paid',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              DataColumn(
                label: Text(
                  'T3 Due',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              DataColumn(
                label: Text(
                  'Bus\n(F/P/D)',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              DataColumn(
                label: Text(
                  'Books\n(F/P/D)',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              DataColumn(
                label: Text(
                  'Uniform\n(F/P/D)',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              DataColumn(
                label: Text(
                  'Status',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
            rows: [
              for (final data in _feeReportData)
                DataRow(
                  color: MaterialStateProperty.all(
                    data['Overall Status'] == 'PAID'
                        ? Colors.green[50]
                        : Colors.red[50],
                  ),
                  cells: [
                    DataCell(
                      Text(
                        data['Student Name'] ?? '',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                      ),
                    ),
                    DataCell(
                      Text(
                        data['Class'] ?? '',
                        style: GoogleFonts.poppins(),
                      ),
                    ),
                    DataCell(
                      Text(
                        data['Gender'] ?? '',
                        style: GoogleFonts.poppins(),
                      ),
                    ),
                    // Term 1 data
                    DataCell(
                      Text(
                        '₹${(data['Term1 Fee'] ?? 0).toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(fontSize: 10),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    DataCell(
                      Text(
                        '₹${(data['Term1 Paid'] ?? 0).toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(fontSize: 10, color: Colors.green[700]),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    DataCell(
                      Text(
                        '₹${(data['Term1 Due'] ?? 0).toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(fontSize: 10, color: (data['Term1 Due'] as double? ?? 0) > 0 ? Colors.red[700] : Colors.green[700]),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    // Term 2 data
                    DataCell(
                      Text(
                        '₹${(data['Term2 Fee'] ?? 0).toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(fontSize: 10),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    DataCell(
                      Text(
                        '₹${(data['Term2 Paid'] ?? 0).toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(fontSize: 10, color: Colors.green[700]),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    DataCell(
                      Text(
                        '₹${(data['Term2 Due'] ?? 0).toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(fontSize: 10, color: (data['Term2 Due'] as double? ?? 0) > 0 ? Colors.red[700] : Colors.green[700]),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    // Term 3 data
                    DataCell(
                      Text(
                        '₹${(data['Term3 Fee'] ?? 0).toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(fontSize: 10),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    DataCell(
                      Text(
                        '₹${(data['Term3 Paid'] ?? 0).toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(fontSize: 10, color: Colors.green[700]),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    DataCell(
                      Text(
                        '₹${(data['Term3 Due'] ?? 0).toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(fontSize: 10, color: (data['Term3 Due'] as double? ?? 0) > 0 ? Colors.red[700] : Colors.green[700]),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    DataCell(
                      Text(
                        '₹${(data['Bus Fee'] ?? 0).toStringAsFixed(0)}/₹${(data['Bus Fee Paid'] ?? 0).toStringAsFixed(0)}/₹${(data['Bus Fee Due'] ?? 0).toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(fontSize: 10),
                      ),
                    ),
                    DataCell(
                      Text(
                        '₹${(data['Books Fee'] ?? 0).toStringAsFixed(0)}/₹${(data['Books Fee Paid'] ?? 0).toStringAsFixed(0)}/₹${(data['Books Fee Due'] ?? 0).toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(fontSize: 10),
                      ),
                    ),
                    DataCell(
                      Text(
                        '₹${(data['Uniform Fee'] ?? 0).toStringAsFixed(0)}/₹${(data['Uniform Fee Paid'] ?? 0).toStringAsFixed(0)}/₹${(data['Uniform Fee Due'] ?? 0).toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(fontSize: 10),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: data['Overall Status'] == 'PAID'
                              ? Colors.green
                              : Colors.orange,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          data['Overall Status'] ?? '',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatAmount(double? amount) {
    if (amount == null) return '0';
    return amount.toStringAsFixed(2);
  }
  // #endregion

  Color _getTabColor(int index) {
    switch (index) {
      case 0:
        return Colors.blue[700]!;
      case 1:
        return Colors.orange[700]!;
      case 2:
        return Colors.purple[700]!;
      case 3:
        return Colors.teal[700]!;
      default:
        return Colors.blue[700]!;
    }
  }
}

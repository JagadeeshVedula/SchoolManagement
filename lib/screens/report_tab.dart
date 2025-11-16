import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:school_management/services/supabase_service.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io' show File;
import 'dart:html' as html;

class ReportTab extends StatefulWidget {
  const ReportTab({super.key});

  @override
  State<ReportTab> createState() => _ReportTabState();
}

class _ReportTabState extends State<ReportTab> {
  String? _selectedFeeType; // 'Bus Fee', 'School Fee', 'Tuition Fee'
  String? _selectedClass;
  List<String> _classes = [];
  List<Map<String, dynamic>> _reportData = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    final classes = await SupabaseService.getUniqueClasses();
    setState(() => _classes = classes);
  }

  Future<void> _loadReportData() async {
    if (_selectedFeeType == null || _selectedClass == null) return;

    setState(() => _isLoading = true);

    try {
      final students = await SupabaseService.getStudentsByClass(_selectedClass!);
      final reportData = <Map<String, dynamic>>[];

      for (final student in students) {
        final fees = await SupabaseService.getFeesByStudent(student.name);

        if (_selectedFeeType == 'Bus Fee') {
          // Bus Fee - aggregate by year
          final currentYear = DateTime.now().year.toString();
          double paidAmount = 0;

          for (final fee in fees) {
            final feeType = (fee['FEE TYPE'] as String? ?? '').trim();
            final feeYear = (fee['TERM YEAR'] as String? ?? '').trim();

            if (feeType == 'Bus Fee' && feeYear == currentYear) {
              paidAmount += double.tryParse((fee['AMOUNT'] as dynamic).toString()) ?? 0;
            }
          }

          reportData.add({
            'Student Name': student.name,
            'Class': student.className,
            'Fee Type': 'Bus Fee',
            'Year': currentYear,
            'Paid Amount': paidAmount,
            'Due Amount': 0.0, // Bus fee due needs route lookup
            'Status': paidAmount > 0 ? 'PAID' : 'UNPAID',
          });
        } else {
          // School Fee / Tuition Fee - show by terms with fee structure
          final feeStructure = await SupabaseService.getFeeStructureByClass(student.className);
          if (feeStructure == null) continue;

          final totalFee = double.tryParse((feeStructure['FEE'] as dynamic).toString()) ?? 0;
          
          // Get concession for this fee type
          final concession = _selectedFeeType == 'School Fee' 
              ? student.schoolFeeConcession 
              : student.tuitionFeeConcession;
          
          // Calculate term fees
          final termFees = SupabaseService.calculateTermFees(totalFee, concession);

          for (int term = 1; term <= 3; term++) {
            final termKey = 'Term $term';
            double paidAmount = 0;

            for (final fee in fees) {
              final feeType = (fee['FEE TYPE'] as String? ?? '').trim().toLowerCase();
              final termNo = (fee['TERM NO'] as String? ?? '').trim();
              final selectedFeeTypeLower = (_selectedFeeType ?? '').toLowerCase();

              if (feeType == selectedFeeTypeLower && termNo.contains(termKey)) {
                paidAmount += double.tryParse((fee['AMOUNT'] as dynamic).toString()) ?? 0;
              }
            }

            final termFee = termFees[term] ?? 0;
            final dueAmount = (termFee - paidAmount).clamp(0, double.infinity);

            reportData.add({
              'Student Name': student.name,
              'Class': student.className,
              'Fee Type': _selectedFeeType,
              'Term': termKey,
              'Term Fee': termFee,
              'Paid Amount': paidAmount,
              'Due Amount': dueAmount,
              'Status': dueAmount <= 0 ? 'PAID' : 'PENDING',
            });
          }
        }
      }

      setState(() {
        _reportData = reportData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading report: $e')),
      );
    }
  }

  Future<void> _downloadExcel() async {
    if (_reportData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data to download')),
      );
      return;
    }

    try {
      final excel = excel_pkg.Excel.createExcel();
      final sheet = excel['Sheet1'];

      // Add header with proper columns
      final headers = _selectedFeeType == 'Bus Fee'
          ? ['Student Name', 'Class', 'Fee Type', 'Year', 'Paid Amount', 'Due Amount', 'Status']
          : ['Student Name', 'Class', 'Fee Type', 'Term', 'Term Fee', 'Paid Amount', 'Due Amount', 'Status'];

      for (int i = 0; i < headers.length; i++) {
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).value = headers[i];
      }

      // Add data rows
      for (int rowIndex = 0; rowIndex < _reportData.length; rowIndex++) {
        final data = _reportData[rowIndex];
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex + 1)).value = data['Student Name'];
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex + 1)).value = data['Class'];
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex + 1)).value = data['Fee Type'];
        
        if (_selectedFeeType == 'Bus Fee') {
          sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex + 1)).value = data['Year'];
          sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex + 1)).value = _formatAmount(data['Paid Amount'] as double?);
          sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex + 1)).value = _formatAmount(data['Due Amount'] as double?);
          sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex + 1)).value = data['Status'];
        } else {
          sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex + 1)).value = data['Term'];
          sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex + 1)).value = _formatAmount(data['Term Fee'] as double?);
          sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex + 1)).value = _formatAmount(data['Paid Amount'] as double?);
          sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex + 1)).value = _formatAmount(data['Due Amount'] as double?);
          sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex + 1)).value = data['Status'];
        }
      }

      // Get bytes and download
      final bytes = excel.encode();
      if (bytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error encoding Excel file')),
        );
        return;
      }

      final fileName = '${_selectedFeeType}_Report_${DateFormat('yyyy-MM-dd_HHmmss').format(DateTime.now())}.xlsx';
      
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

  void _downloadFileWeb(List<int> bytes, String fileName) {
    // Web download using Blob and download link
    try {
      final blob = html.Blob([bytes]);
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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
              _buildFeeTypeChip('Bus Fee', Colors.orange),
              _buildFeeTypeChip('School Fee', Colors.green),
              _buildFeeTypeChip('Tuition Fee', Colors.purple),
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
                value: _selectedClass,
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
                    _selectedClass = className;
                    _reportData = [];
                  });
                  if (className != null) {
                    _loadReportData();
                  }
                },
              ),
            ),
            const SizedBox(height: 24),

            // Report Data Display
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_reportData.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Report Data (${_reportData.length} records)',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _downloadExcel,
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
              _buildReportTable(),
            ] else if (_selectedClass != null && !_isLoading)
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
          _selectedClass = null;
          _reportData = [];
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

  Widget _buildReportTable() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: DataTable(
            headingRowColor: MaterialStateProperty.all(Colors.blue[700]),
            headingRowHeight: 56,
            dataRowHeight: 56,
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
              if (_selectedFeeType == 'Bus Fee')
                DataColumn(
                  label: Text(
                    'Year',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                )
              else
                DataColumn(
                  label: Text(
                    'Term',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              if (_selectedFeeType != 'Bus Fee')
                DataColumn(
                  label: Text(
                    'Term Fee',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              DataColumn(
                label: Text(
                  'Paid Amount',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'Due Amount',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
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
              for (final data in _reportData)
                DataRow(
                  color: MaterialStateProperty.all(
                    data['Status'] == 'PAID'
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
                        _selectedFeeType == 'Bus Fee' ? (data['Year'] ?? '') : (data['Term'] ?? ''),
                        style: GoogleFonts.poppins(),
                      ),
                    ),
                    if (_selectedFeeType != 'Bus Fee')
                      DataCell(
                        Text(
                          '₹${(data['Term Fee'] ?? 0).toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[700],
                          ),
                        ),
                      ),
                    DataCell(
                      Text(
                        '₹${(data['Paid Amount'] ?? 0).toStringAsFixed(2)}',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: Colors.green[700],
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        '₹${(data['Due Amount'] ?? 0).toStringAsFixed(2)}',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: (data['Due Amount'] as double? ?? 0) > 0 ? Colors.red[700] : Colors.green[700],
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: data['Status'] == 'PAID'
                              ? Colors.green
                              : Colors.orange,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          data['Status'] ?? '',
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
}


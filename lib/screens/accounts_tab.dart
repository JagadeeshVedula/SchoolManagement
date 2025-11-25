import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:school_management/services/supabase_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html;
import 'dart:io' show File;
import 'package:path_provider/path_provider.dart';

class AccountsTab extends StatefulWidget {
  const AccountsTab({super.key});

  @override
  State<AccountsTab> createState() => _AccountsTabState();
}

class _AccountsTabState extends State<AccountsTab> {
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = false;
  double _totalCredit = 0.0;
  double _totalDebit = 0.0;
  double _previousDayClosingBalance = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
  }

  Future<void> _fetchTransactions() async {
    setState(() => _isLoading = true);

    // Fetch previous day's closing balance
    final previousDay = _selectedDate.subtract(const Duration(days: 1));
    final prevBalance = await SupabaseService.getClosingBalanceForDate(previousDay);

    final transactions = await SupabaseService.getTransactionsByDate(_selectedDate);

    double credit = 0.0;
    double debit = 0.0;

    for (var t in transactions) {
      if (t['type'] == 'credit') {
        credit += t['amount'] as double;
      } else {
        debit += t['amount'] as double;
      }
    }

    setState(() {
      _transactions = transactions;
      _totalCredit = credit;
      _totalDebit = debit;
      _isLoading = false;
      _previousDayClosingBalance = prevBalance;
    });

    // Auto-save the new closing balance
    final newClosingBalance = _previousDayClosingBalance + _totalCredit - _totalDebit;
    await _saveClosingBalance(newClosingBalance);
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _fetchTransactions();
    }
  }

  Future<void> _saveClosingBalance(double closingBalance) async {
    final success = await SupabaseService.saveClosingBalance(_selectedDate, closingBalance);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Closing balance saved successfully!' : 'Failed to save closing balance.'),
          backgroundColor: success ? Colors.green : Colors.red,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
        ),
      );
    }
  }

  Future<void> _exportToExcel() async {
    if (_isLoading) return;

    final excel = excel_pkg.Excel.createExcel();
    final sheet = excel['Sheet1'];

    // Title
    sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value = 'Day Transactions Report';
    sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).value = 'Date: ${DateFormat('dd-MM-yyyy').format(_selectedDate)}';

    // Summary
    sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 3)).value = 'Opening Balance';
    sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 3)).value = _previousDayClosingBalance;
    sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 4)).value = 'Total Credit';
    sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 4)).value = _totalCredit;
    sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 5)).value = 'Total Debit';
    sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 5)).value = _totalDebit;
    sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 6)).value = 'Closing Balance';
    sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 6)).value = _previousDayClosingBalance + _totalCredit - _totalDebit;

    // Transaction Headers
    sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 8)).value = 'Transaction';
    sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 8)).value = 'Credit';
    sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 8)).value = 'Debit';

    // Transaction Data
    for (int i = 0; i < _transactions.length; i++) {
      final transaction = _transactions[i];
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 9 + i)).value = transaction['description'];
      if (transaction['type'] == 'credit') {
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 9 + i)).value = transaction['amount'];
      } else {
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 9 + i)).value = transaction['amount'];
      }
    }

    final bytes = excel.save();
    if (bytes == null) return;

    final fileName = 'Day_Transactions_${DateFormat('yyyy-MM-dd').format(_selectedDate)}.xlsx';

    if (kIsWeb) {
      final blob = html.Blob([bytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute("download", fileName)
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      try {
        final directory = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$fileName');
        await file.writeAsBytes(bytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Downloaded to ${file.path}')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving file: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final closingBalance = _previousDayClosingBalance + _totalCredit - _totalDebit;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Day Transactions',
                style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w700),
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _selectDate(context),
                    icon: const Icon(Icons.calendar_today),
                    label: Text(DateFormat('dd-MM-yyyy').format(_selectedDate)),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    icon: const Icon(Icons.download),
                    onPressed: _exportToExcel,
                    tooltip: 'Export to Excel',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Transactions Table
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _transactions.isEmpty
                    ? const Center(child: Text('No transactions for this date.'))
                    : SingleChildScrollView(
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Transaction')),
                            DataColumn(label: Text('Credit'), numeric: true),
                            DataColumn(label: Text('Debit'), numeric: true),
                          ],
                          rows: [
                            ..._transactions.map((transaction) {
                              return DataRow(
                                cells: [
                                  DataCell(Text(transaction['description'] as String)),
                                  DataCell(Text(transaction['type'] == 'credit' ? (transaction['amount'] as double).toStringAsFixed(2) : '')),
                                  DataCell(Text(transaction['type'] == 'debit' ? (transaction['amount'] as double).toStringAsFixed(2) : '')),
                                ],
                              );
                            }).toList(),
                          ],
                        ),
                      ),
          ),

          // Totals and Closing Balance
          const Divider(thickness: 2),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Column(
              children: [
                _buildSummaryRow('Previous Day\'s Closing Balance:', '₹${_previousDayClosingBalance.toStringAsFixed(2)}', Colors.black),
                const SizedBox(height: 4),
                _buildSummaryRow('Total Credit:', '₹${_totalCredit.toStringAsFixed(2)}', Colors.green),
                const SizedBox(height: 4),
                _buildSummaryRow('Total Debit:', '₹${_totalDebit.toStringAsFixed(2)}', Colors.red),
                const Divider(),
                _buildSummaryRow('Closing Balance:', '₹${closingBalance.toStringAsFixed(2)}', Colors.blue, isBold: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String title, String value, Color color, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
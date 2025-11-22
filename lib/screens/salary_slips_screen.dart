import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:school_management/services/supabase_service.dart';
import 'package:school_management/screens/pay_slip_view_screen.dart';

class SalarySlipsScreen extends StatefulWidget {
  const SalarySlipsScreen({super.key});

  @override
  State<SalarySlipsScreen> createState() => _SalarySlipsScreenState();
}

class _SalarySlipsScreenState extends State<SalarySlipsScreen> {
  String _selectedMonth = DateFormat('MM-yyyy').format(DateTime.now());
  List<Map<String, dynamic>> _paySlips = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchPaySlips();
  }

  Future<void> _fetchPaySlips() async {
    setState(() => _isLoading = true);
    final paySlips = await SupabaseService.getPaySlipsForMonth(_selectedMonth);
    setState(() {
      _paySlips = paySlips;
      _isLoading = false;
    });
  }

  Future<void> _generatePaySlips() async {
    return showDialog(
      context: context,
      builder: (context) => _GeneratePaySlipDialog(
        onGenerate: (monthYear, workingDays) async {
          Navigator.pop(context);
          await _generateAndSavePaySlips(monthYear, workingDays);
        },
      ),
    );
  }

  Future<void> _generateAndSavePaySlips(String monthYear, int workingDays) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    try {
      setState(() => _isLoading = true);

      // Get all staff
      final staffList = await SupabaseService.getAllStaffForPaySlips();

      int successCount = 0;
      for (var staff in staffList) {
        final staffName = staff['Name'] ?? '';
        if (staffName.isEmpty) continue;

        // Generate pay slip
        final paySlip = await SupabaseService.generatePaySlip(
          staffName: staffName,
          workingDays: workingDays,
          monthYear: monthYear,
        );

        if (paySlip.isNotEmpty) {
          // Save to database
          final saved = await SupabaseService.savePaySlip(paySlip);
          if (saved) successCount++;
        }
      }

      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              'Pay slips generated for $successCount staff members',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green[600],
          ),
        );

        // Refresh the list
        _selectedMonth = monthYear;
        _fetchPaySlips();
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              'Error generating pay slips: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<String> _getLastSixMonths() {
    List<String> months = [];
    DateTime now = DateTime.now();
    for (int i = 0; i < 6; i++) {
      final date = DateTime(now.year, now.month - i, 1);
      months.add(DateFormat('MM-yyyy').format(date));
    }
    return months;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Header with month filter and generate button
          Row(
            children: [
              Expanded(
                child: DropdownButton<String>(
                  value: _selectedMonth,
                  isExpanded: true,
                  items: _getLastSixMonths().map((month) {
                    return DropdownMenuItem(
                      value: month,
                      child: Text(month, style: GoogleFonts.poppins()),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedMonth = value);
                      _fetchPaySlips();
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _generatePaySlips,
                icon: const Icon(Icons.add),
                label: Text(
                  'Generate',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Pay slips list
          if (_isLoading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_paySlips.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  'No pay slips for this month',
                  style: GoogleFonts.poppins(color: Colors.grey[600]),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _paySlips.length,
                itemBuilder: (context, index) {
                  final paySlip = _paySlips[index];
                  final staffName = paySlip['STAFF'] ?? 'Unknown';
                  final monthlySalary = double.tryParse(paySlip['MONTHLY_SALARY']?.toString() ?? '0.0') ?? 0.0;

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      title: Text(
                        staffName,
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        'Salary: ₹${monthlySalary.toStringAsFixed(2)}',
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                      trailing: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PaySlipViewScreen(
                                paySlipData: paySlip,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[600],
                          foregroundColor: Colors.white,
                        ),
                        child: Text(
                          'View',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// Dialog for generating pay slips
class _GeneratePaySlipDialog extends StatefulWidget {
  final Function(String monthYear, int workingDays) onGenerate;

  const _GeneratePaySlipDialog({required this.onGenerate});

  @override
  State<_GeneratePaySlipDialog> createState() => _GeneratePaySlipDialogState();
}

class _GeneratePaySlipDialogState extends State<_GeneratePaySlipDialog> {
  String _selectedMonth = DateFormat('MM-yyyy').format(DateTime.now());
  final _workingDaysController = TextEditingController();

  @override
  void dispose() {
    _workingDaysController.dispose();
    super.dispose();
  }

  List<String> _getLastSixMonths() {
    List<String> months = [];
    DateTime now = DateTime.now();
    for (int i = 0; i < 12; i++) {
      final date = DateTime(now.year, now.month - i, 1);
      months.add(DateFormat('MM-yyyy').format(date));
    }
    return months;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Generate Pay Slip',
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Month selector
            Text(
              'Select Month:',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            DropdownButton<String>(
              value: _selectedMonth,
              isExpanded: true,
              items: _getLastSixMonths().map((month) {
                return DropdownMenuItem(
                  value: month,
                  child: Text(month, style: GoogleFonts.poppins()),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedMonth = value);
                }
              },
            ),
            const SizedBox(height: 20),

            // Working days input
            Text(
              'Enter Working Days:',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _workingDaysController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'e.g., 26',
                border: const OutlineInputBorder(),
                hintStyle: GoogleFonts.poppins(),
              ),
              style: GoogleFonts.poppins(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: GoogleFonts.poppins(),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            final workingDays = int.tryParse(_workingDaysController.text);
            if (workingDays == null || workingDays <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Please enter valid working days',
                    style: GoogleFonts.poppins(),
                  ),
                ),
              );
              return;
            }
            widget.onGenerate(_selectedMonth, workingDays);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[600],
            foregroundColor: Colors.white,
          ),
          child: Text(
            'Generate',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}

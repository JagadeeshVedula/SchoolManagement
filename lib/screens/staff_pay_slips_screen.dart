import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:school_management/services/supabase_service.dart';
import 'package:school_management/screens/pay_slip_view_screen.dart';

class StaffPaySlipsScreen extends StatefulWidget {
  final String staffName;

  const StaffPaySlipsScreen({
    super.key,
    required this.staffName,
  });

  @override
  State<StaffPaySlipsScreen> createState() => _StaffPaySlipsScreenState();
}

class _StaffPaySlipsScreenState extends State<StaffPaySlipsScreen> {
  late List<Map<String, dynamic>> _paySlips = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchPaySlips();
  }

  Future<void> _fetchPaySlips() async {
    setState(() => _isLoading = true);
    try {
      final paySlips = await SupabaseService.getPaySlipsForStaff(widget.staffName);
      setState(() {
        _paySlips = paySlips;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error loading pay slips: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red[600],
          ),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Pay Slips',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.blue[600],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _paySlips.isEmpty
              ? Center(
                  child: Text(
                    'No pay slips generated yet',
                    style: GoogleFonts.poppins(color: Colors.grey[600]),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchPaySlips,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _paySlips.length,
                    itemBuilder: (context, index) {
                      final paySlip = _paySlips[index];
                      final monthYear = paySlip['MONTH'] ?? 'N/A';
                      final monthlySalary = double.tryParse(paySlip['MONTHLY_SALARY']?.toString() ?? '0.0') ?? 0.0;

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Month: $monthYear',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Salary: ₹${monthlySalary.toStringAsFixed(2)}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: Colors.green[700],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
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
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

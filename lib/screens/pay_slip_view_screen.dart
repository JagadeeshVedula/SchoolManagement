import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:html' as html;

class PaySlipViewScreen extends StatefulWidget {
  final Map<String, dynamic> paySlipData;

  const PaySlipViewScreen({
    super.key,
    required this.paySlipData,
  });

  @override
  State<PaySlipViewScreen> createState() => _PaySlipViewScreenState();
}

class _PaySlipViewScreenState extends State<PaySlipViewScreen> {
  bool _isGeneratingPDF = false;

  Future<void> _downloadPaySlipPDF() async {
    setState(() => _isGeneratingPDF = true);
    try {
      final pdf = pw.Document();
      
      final staffName = widget.paySlipData['STAFF'] ?? 'N/A';
      final monthYear = widget.paySlipData['MONTH'] ?? 'N/A';
      final workingDays = int.tryParse(widget.paySlipData['WORKING_DAYS']?.toString() ?? '0') ?? 0;
      final leaveCount = int.tryParse(widget.paySlipData['LEAVE_COUNT']?.toString() ?? '0') ?? 0;
      final payableDays = int.tryParse(widget.paySlipData['PAYABLE_DAYS']?.toString() ?? '0') ?? 0;
      final salary = double.tryParse(widget.paySlipData['SALARY']?.toString() ?? '0.0') ?? 0.0;
      final dailyRate = double.tryParse(widget.paySlipData['DAILY_RATE']?.toString() ?? '0.0') ?? 0.0;
      final monthlySalary = double.tryParse(widget.paySlipData['MONTHLY_SALARY']?.toString() ?? '0.0') ?? 0.0;
      
      final now = DateTime.now();
      final generatedDate = '${now.day}-${now.month}-${now.year}';

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text('PAY SLIP', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 12),
              pw.Divider(),
              pw.SizedBox(height: 12),
              
              // Header Info
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Staff Name:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text(staffName),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Month:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text(monthYear),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Generated Date:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text(generatedDate),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Divider(),
              
              // Attendance Section
              pw.SizedBox(height: 12),
              pw.Text('ATTENDANCE', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Working Days:'),
                  pw.Text(workingDays.toString(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Leaves Taken:'),
                  pw.Text(leaveCount.toString(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Payable Days:'),
                  pw.Text(payableDays.toString(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.green)),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Divider(),
              
              // Salary Section
              pw.SizedBox(height: 12),
              pw.Text('SALARY DETAILS', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Monthly Salary:'),
                  pw.Text('Rs. ${salary.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Daily Rate:'),
                  pw.Text('Rs. ${dailyRate.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Calculation:'),
                  pw.Text('(${salary.toStringAsFixed(2)} ÷ $workingDays) × $payableDays'),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Divider(),
              
              // Net Salary
              pw.SizedBox(height: 12),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.green),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('NET SALARY FOR ${monthYear.split('-')[0]}/${monthYear.split('-')[1]}:', 
                      style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Rs. ${monthlySalary.toStringAsFixed(2)}', 
                      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.green)),
                  ],
                ),
              ),
              pw.SizedBox(height: 24),
              
              // Footer
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text('This is a system-generated pay slip', 
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              ),
            ],
          ),
        ),
      );

      // Generate PDF bytes
      final bytes = await pdf.save();

      // Download for web
      final fileName = 'PaySlip_${staffName.replaceAll(' ', '_')}_${monthYear.replaceAll('-', '_')}.pdf';
      _downloadFileWeb(bytes, fileName);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pay slip downloaded successfully', style: GoogleFonts.poppins()),
            backgroundColor: Colors.green[600],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e', style: GoogleFonts.poppins()),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    } finally {
      setState(() => _isGeneratingPDF = false);
    }
  }

  void _downloadFileWeb(List<int> bytes, String fileName) {
    try {
      final blob = html.Blob([bytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      html.Url.revokeObjectUrl(url);
    } catch (e) {
      print('Error preparing web download: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final staffName = widget.paySlipData['STAFF'] ?? 'N/A';
    final monthYear = widget.paySlipData['MONTH'] ?? 'N/A';
    
    // Parse string values from database
    final workingDays = int.tryParse(widget.paySlipData['WORKING_DAYS']?.toString() ?? '0') ?? 0;
    final leaveCount = int.tryParse(widget.paySlipData['LEAVE_COUNT']?.toString() ?? '0') ?? 0;
    final payableDays = int.tryParse(widget.paySlipData['PAYABLE_DAYS']?.toString() ?? '0') ?? 0;
    final salary = double.tryParse(widget.paySlipData['SALARY']?.toString() ?? '0.0') ?? 0.0;
    final dailyRate = double.tryParse(widget.paySlipData['DAILY_RATE']?.toString() ?? '0.0') ?? 0.0;
    final monthlySalary = double.tryParse(widget.paySlipData['MONTHLY_SALARY']?.toString() ?? '0.0') ?? 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Pay Slip - $staffName',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.blue[600],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SALARY SLIP',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.blue[900],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow('Staff Name:', staffName),
                  _buildInfoRow('Month:', monthYear),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Attendance section
            _buildSection(
              title: 'Attendance',
              children: [
                _buildDetailRow('Working Days:', '$workingDays days'),
                _buildDetailRow('Leaves Taken:', '$leaveCount days'),
                _buildDetailRow('Payable Days:', '$payableDays days', isHighlight: true),
              ],
            ),
            const SizedBox(height: 20),

            // Salary calculation section
            _buildSection(
              title: 'Salary Calculation',
              children: [
                _buildDetailRow('Monthly Salary:', '₹${salary.toStringAsFixed(2)}'),
                _buildDetailRow('Daily Rate:', '₹${dailyRate.toStringAsFixed(2)}'),
                _buildDetailRow(
                  'Formula:',
                  '(${salary.toStringAsFixed(2)} ÷ $workingDays) × $payableDays',
                  isMuted: true,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Final salary section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Net Salary for ${monthYear.split('-')[0]}/${monthYear.split('-')[1]}:',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.green[900],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '₹${monthlySalary.toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.green[700],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Download PDF button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isGeneratingPDF ? null : _downloadPaySlipPDF,
                icon: const Icon(Icons.download_sharp),
                label: Text(
                  _isGeneratingPDF ? 'Generating PDF...' : 'Download as PDF',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isHighlight = false, bool isMuted = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w500,
              color: isMuted ? Colors.grey[600] : Colors.grey[800],
              fontSize: isMuted ? 12 : 14,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w600,
              color: isHighlight ? Colors.blue[700] : Colors.black87,
              fontSize: isHighlight ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.blue[900],
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

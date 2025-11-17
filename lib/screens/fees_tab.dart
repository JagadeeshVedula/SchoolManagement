import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:school_management/services/supabase_service.dart';
import 'package:school_management/models/student.dart';

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

  // Books and Uniform Fee year selection
  String? _selectedBooksYear;
  String? _selectedUniformYear;

  // Dues
  String? _selectedDueType; // 'School'

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
    final booksFeePaid = fees
        .where((f) => (f['FEE TYPE'] as String? ?? '').contains('Books Fee'))
        .fold<double>(0, (sum, f) => sum + (double.tryParse((f['AMOUNT'] as dynamic).toString()) ?? 0));
    return booksFeePaid > 0;
  }

  Future<bool> _checkUniformFeeAlreadyPaid(String studentName) async {
    final fees = await SupabaseService.getFeesByStudent(studentName);
    final uniformFeePaid = fees
        .where((f) => (f['FEE TYPE'] as String? ?? '').contains('Uniform Fee'))
        .fold<double>(0, (sum, f) => sum + (double.tryParse((f['AMOUNT'] as dynamic).toString()) ?? 0));
    return uniformFeePaid > 0;
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
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Fees', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            _menuButton(icon: Icons.payments, title: 'Payments', onPressed: () => setState(() => _currentPage = 1)),
            const SizedBox(height: 12),
            _menuButton(icon: Icons.request_quote, title: 'Dues', onPressed: () => setState(() => _currentPage = 2)),
          ],
        ),
      );
    } else if (_currentPage == 1) {
      return _buildPaymentsPage();
    } else {
      return _buildDuesPage();
    }
  }

  Widget _menuButton({required IconData icon, required String title, required VoidCallback onPressed}) {
    return SizedBox(
      height: 110,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 36), const SizedBox(height: 8), Text(title, style: GoogleFonts.poppins(fontSize: 16))]),
      ),
    );
  }

  Widget _buildPaymentsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ElevatedButton.icon(onPressed: () => setState(() => _currentPage = 0), icon: const Icon(Icons.arrow_back), label: const Text('Back')),
        const SizedBox(height: 12),
        Text('Payments', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          ChoiceChip(label: const Text('School Fee'), selected: _selectedPaymentType == 'School Fee', onSelected: (_) => setState(() => _selectedPaymentType = 'School Fee')),
          ChoiceChip(label: const Text('Books Fee'), selected: _selectedPaymentType == 'Books Fee', onSelected: (_) => setState(() => _selectedPaymentType = 'Books Fee')),
          ChoiceChip(label: const Text('Uniform Fee'), selected: _selectedPaymentType == 'Uniform Fee', onSelected: (_) => setState(() => _selectedPaymentType = 'Uniform Fee')),
        ]),
        const SizedBox(height: 16),
        if (_selectedPaymentType != null) ...[
          const Text('Select Class', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedClass,
            items: _classes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) {
              setState(() { _selectedClass = v; _selectedStudent = null; _students = []; });
              if (v != null) _loadStudentsForClass(v);
            },
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
        ],
        if (_students.isNotEmpty) ...[
          const Text('Students', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          for (final s in _students)
            ListTile(
              title: Text(s.name),
              subtitle: Text(s.parentMobile),
              trailing: _selectedStudent == s ? const Icon(Icons.check_circle, color: Colors.green) : null,
              onTap: () => setState(() => _selectedStudent = s),
            ),
          const SizedBox(height: 12),
        ],
        if (_selectedStudent != null) ...[
          const SizedBox(height: 16),
          // Concession input section
          Container(
            decoration: BoxDecoration(
              color: Colors.amber[50],
              border: Border.all(color: Colors.amber[200]!),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Concession Amount', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: _concession,
                  decoration: InputDecoration(
                    labelText: _selectedPaymentType == 'School Fee' 
                        ? 'School Fee Concession (Current: ₹${_selectedStudent!.schoolFeeConcession.toStringAsFixed(2)})'
                        : 'No Concession for this Fee Type',
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  enabled: _selectedPaymentType == 'School Fee',
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: ElevatedButton(
                    onPressed: _saveConcession,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                    ),
                    child: const Text('Save Concession', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Fee Structure for ${_selectedStudent!.className}', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (_selectedPaymentType == 'School Fee')
            FutureBuilder<Map<String, dynamic>?>(
              future: SupabaseService.getFeeStructureByClass(_selectedStudent!.className),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final structure = snap.data;
                if (structure == null) {
                  return const Text('No fee structure found', style: TextStyle(color: Colors.red));
                }
                final totalFee = double.tryParse((structure['FEE'] as dynamic).toString()) ?? 0;
                final concession = _selectedStudent!.schoolFeeConcession;
                final termFees = SupabaseService.calculateTermFees(totalFee, concession);
                
                return Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(color: Colors.blue[100]),
                      child: Row(
                        children: [
                          Expanded(child: Padding(padding: const EdgeInsets.all(8), child: Text('Term', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)))),
                          Expanded(child: Padding(padding: const EdgeInsets.all(8), child: Text('Amount', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)))),
                          Expanded(child: Padding(padding: const EdgeInsets.all(8), child: Text('Due', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)))),
                        ],
                      ),
                    ),
                    for (int i = 1; i <= 3; i++)
                      Container(
                        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[300]!))),
                        child: Row(
                          children: [
                            Expanded(child: Padding(padding: const EdgeInsets.all(8), child: Text('Term $i'))),
                            Expanded(child: Padding(padding: const EdgeInsets.all(8), child: Text('₹${termFees[i]!.toStringAsFixed(2)}'))),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: FutureBuilder<Map<String, dynamic>>(
                                  future: SupabaseService.calculateStudentDue(
                                    _selectedStudent!.name, 
                                    'School Fee',
                                    i,
                                    termFees[i]!
                                  ),
                                  builder: (context, dueSn) {
                                    final due = dueSn.data?['due'] as double? ?? 0;
                                    return Text('₹${due.toStringAsFixed(2)}', style: TextStyle(color: due > 0 ? Colors.red : Colors.green));
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.amber[50],
                      border: Border(bottom: BorderSide(color: Colors.grey[300]!))
                    ),
                    child: Row(
                      children: [
                        Expanded(child: Padding(padding: const EdgeInsets.all(8), child: Text('Concession', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)))),
                        Expanded(child: Padding(padding: const EdgeInsets.all(8), child: Text('-₹${concession.toStringAsFixed(2)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600)))),
                        Expanded(child: Padding(padding: const EdgeInsets.all(8), child: const Text(''))),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      border: Border(bottom: BorderSide(color: Colors.grey[300]!))
                    ),
                    child: Row(
                      children: [
                        Expanded(child: Padding(padding: const EdgeInsets.all(8), child: Text('Total (after Concession)', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)))),
                        Expanded(child: Padding(padding: const EdgeInsets.all(8), child: Text('₹${(totalFee - concession).clamp(0, double.infinity).toStringAsFixed(2)}', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)))),
                        Expanded(child: Padding(padding: const EdgeInsets.all(8), child: const Text(''))),
                      ],
                    ),
                  ),
                ],
              );
              }
            ),
          // Books Fee Section
          if (_selectedPaymentType == 'Books Fee')
            FutureBuilder<double>(
              future: SupabaseService.getBooksFeeByClass(_selectedStudent!.className),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final booksFee = snap.data ?? 0;
                
                return FutureBuilder<bool>(
                  future: _checkBooksFeeAlreadyPaid(_selectedStudent!.name),
                  builder: (context, paidSnap) {
                    final booksFeeAlreadyPaid = paidSnap.data ?? false;
                    
                    return Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.orange),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Books Fee', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),
                          if (!booksFeeAlreadyPaid) ...[
                            // Fee amount
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Amount:', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                                Text('₹${booksFee.toStringAsFixed(2)}', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.blue)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Year selection
                            Text('Select Year:', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12)),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: _selectedBooksYear,
                              items: List.generate(5, (i) {
                                final year = (DateTime.now().year - i).toString();
                                return DropdownMenuItem(value: year, child: Text(year));
                              }).toList(),
                              onChanged: (v) => setState(() => _selectedBooksYear = v),
                              decoration: InputDecoration(
                                hintText: 'Choose year',
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Pay button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: _selectedBooksYear != null ? () async {
                                  if (_selectedStudent != null) {
                                    setState(() => _isSubmitting = true);
                                    try {
                                      final feeData = {
                                        'STUDENT NAME': _selectedStudent!.name,
                                        'FEE TYPE': 'Books Fee',
                                        'AMOUNT': booksFee,
                                        'TERM YEAR': _selectedBooksYear,
                                        'TERM MONTH': 'Full Year',
                                        'TERM NO': 'Books',
                                      };
                                      await SupabaseService.insertFee(feeData);
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Books Fee paid successfully')),
                                        );
                                        setState(() {
                                          _selectedPaymentType = null;
                                          _selectedBooksYear = null;
                                        });
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Error: $e')),
                                        );
                                      }
                                    } finally {
                                      setState(() => _isSubmitting = false);
                                    }
                                  }
                                } : null,
                                child: _isSubmitting
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                                      )
                                    : const Text('Pay Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ] else
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                border: Border.all(color: Colors.green),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle, color: Colors.green),
                                  const SizedBox(width: 8),
                                  Text('Fee Already Paid', style: GoogleFonts.poppins(color: Colors.green, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          // Uniform Fee Section
          if (_selectedPaymentType == 'Uniform Fee')
            FutureBuilder<double>(
              future: SupabaseService.getUniformFeeByClassAndGender(
                _selectedStudent!.className, 
                _selectedStudent!.gender ?? 'Male'
              ),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final uniformFee = snap.data ?? 0;
                
                return FutureBuilder<bool>(
                  future: _checkUniformFeeAlreadyPaid(_selectedStudent!.name),
                  builder: (context, paidSnap) {
                    final uniformFeeAlreadyPaid = paidSnap.data ?? false;
                    
                    return Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.purple),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Uniform Fee', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),
                          if (!uniformFeeAlreadyPaid) ...[
                            // Fee amount
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Amount:', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                                Text('₹${uniformFee.toStringAsFixed(2)}', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.purple)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Year selection
                            Text('Select Year:', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12)),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: _selectedUniformYear,
                              items: List.generate(5, (i) {
                                final year = (DateTime.now().year - i).toString();
                                return DropdownMenuItem(value: year, child: Text(year));
                              }).toList(),
                              onChanged: (v) => setState(() => _selectedUniformYear = v),
                              decoration: InputDecoration(
                                hintText: 'Choose year',
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Pay button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.purple,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: _selectedUniformYear != null ? () async {
                                  if (_selectedStudent != null) {
                                    setState(() => _isSubmitting = true);
                                    try {
                                      final feeData = {
                                        'STUDENT NAME': _selectedStudent!.name,
                                        'FEE TYPE': 'Uniform Fee',
                                        'AMOUNT': uniformFee,
                                        'TERM YEAR': _selectedUniformYear,
                                        'TERM MONTH': 'Full Year',
                                        'TERM NO': 'Uniform',
                                      };
                                      await SupabaseService.insertFee(feeData);
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Uniform Fee paid successfully')),
                                        );
                                        setState(() {
                                          _selectedPaymentType = null;
                                          _selectedUniformYear = null;
                                        });
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Error: $e')),
                                        );
                                      }
                                    } finally {
                                      setState(() => _isSubmitting = false);
                                    }
                                  }
                                } : null,
                                child: _isSubmitting
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                                      )
                                    : const Text('Pay Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ] else
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                border: Border.all(color: Colors.green),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle, color: Colors.green),
                                  const SizedBox(width: 8),
                                  Text('Fee Already Paid', style: GoogleFonts.poppins(color: Colors.green, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          const SizedBox(height: 16),
          // Bus Fee Checkbox (only for School Fee)
          if (_selectedPaymentType == 'School Fee' && (_selectedStudent?.busRoute?.isNotEmpty ?? false))
            FutureBuilder<bool>(
              future: _checkBusFeeAlreadyPaid(_selectedStudent!.name),
              builder: (context, busFeeStatusSnap) {
                final busFeeAlreadyPaid = busFeeStatusSnap.data ?? false;
                
                return Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.orange[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: _payBusFee,
                            onChanged: busFeeAlreadyPaid
                                ? null
                                : (value) => setState(() => _payBusFee = value ?? false),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Add Bus Fee',
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  'Route: ${_selectedStudent!.busRoute}',
                                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                                ),
                                if (busFeeAlreadyPaid)
                                  Text(
                                    'Already Paid',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.green,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (_payBusFee && !busFeeAlreadyPaid)
                        FutureBuilder<double>(
                          future: SupabaseService.getBusFeeByRoute(_selectedStudent!.busRoute ?? ''),
                          builder: (context, busFeeSnap) {
                            final busFee = busFeeSnap.data ?? 0;
                            return Padding(
                              padding: const EdgeInsets.only(top: 12, left: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Bus Fee:',
                                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    '₹${busFee.toStringAsFixed(2)}',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 16),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedTermMonth,
            items: [
              'June - September',
              'November - February',
              'March - June',
            ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (v) => setState(() => _selectedTermMonth = v),
            decoration: const InputDecoration(labelText: 'Term Month', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          TextField(controller: _termYear, decoration: const InputDecoration(labelText: 'Term Year', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: _feeType, decoration: InputDecoration(labelText: 'Fee Type', hintText: _selectedPaymentType, border: const OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: _amount, decoration: const InputDecoration(labelText: 'Amount', border: OutlineInputBorder()), keyboardType: TextInputType.number),
          const SizedBox(height: 8),
          if (_selectedPaymentType != 'Bus Fee') ...[
            const Text('Select Term No', style: TextStyle(fontWeight: FontWeight.w600)),
            CheckboxListTile(
              value: _termSelections[1],
              onChanged: (v) => setState(() => _termSelections[1] = v ?? false),
              title: const Text('Term 1'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            CheckboxListTile(
              value: _termSelections[2],
              onChanged: (v) => setState(() => _termSelections[2] = v ?? false),
              title: const Text('Term 2'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            CheckboxListTile(
              value: _termSelections[3],
              onChanged: (v) => setState(() => _termSelections[3] = v ?? false),
              title: const Text('Term 3'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, height: 48, child: ElevatedButton(onPressed: _isSubmitting ? null : _submitFee, child: _isSubmitting ? const CircularProgressIndicator() : const Text('Submit Fee'))),
        ],
      ]),
    );
  }

  Widget _buildDuesPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ElevatedButton.icon(onPressed: () => setState(() => _currentPage = 0), icon: const Icon(Icons.arrow_back), label: const Text('Back')),
        const SizedBox(height: 12),
        Text('Dues', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _selectedDueType == 'School Fee' ? Colors.blue : Colors.grey,
            ),
            onPressed: () => setState(() => _selectedDueType = 'School Fee'),
            child: const Text('School & Bus Fees Due'),
          ),
        ]),
        const SizedBox(height: 12),
        if (_selectedDueType != null) ...[
          const Text('Select Class', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedClass,
            items: _classes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) {
              setState(() { _selectedClass = v; _students = []; _selectedStudent = null; });
              if (v != null) _loadStudentsForClass(v);
            },
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          if (_students.isNotEmpty && _selectedDueType != null) ...[
            const Text('Students', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            for (final s in _students)
              if (_selectedDueType == 'School Fee')
                // School and Bus Fee combined logic: show due based on terms
                FutureBuilder<Map<String, dynamic>?>(
                  future: SupabaseService.getFeeStructureByClass(s.className),
                  builder: (context, structureSnap) {
                    if (structureSnap.connectionState == ConnectionState.waiting) {
                      return const SizedBox();
                    }
                    final structure = structureSnap.data;
                    if (structure == null) return const SizedBox();
                    
                    final totalFee = double.tryParse((structure['FEE'] as dynamic).toString()) ?? 0;
                    final concession = s.schoolFeeConcession;
                    
                    // Calculate term fees with concession
                    final termFees = SupabaseService.calculateTermFees(totalFee, concession);
                    
                    return FutureBuilder<List<Map<String, dynamic>>>(
                      future: SupabaseService.getFeesByStudent(s.name),
                      builder: (context, feesSnap) {
                        if (feesSnap.connectionState == ConnectionState.waiting) {
                          return const SizedBox();
                        }
                        final fees = feesSnap.data ?? [];
                        
                        // Find terms with remaining due (paid < term fee)
                        final termsWithDue = <int, double>{};
                        for (int term = 1; term <= 3; term++) {
                          final termKey = 'Term $term';
                          double paidAmount = 0;
                          
                          // Calculate paid amount for this term (School Fee only)
                          for (final fee in fees) {
                            if ((fee['FEE TYPE'] as String? ?? '').contains('School Fee') &&
                                (fee['TERM NO'] as String? ?? '').contains(termKey)) {
                              final amt = double.tryParse((fee['AMOUNT'] as dynamic).toString()) ?? 0;
                              paidAmount += amt;
                            }
                          }
                          
                          final termFee = termFees[term]!;
                          if (paidAmount < termFee) {
                            termsWithDue[term] = termFee - paidAmount;
                          }
                        }
                        
                        // Check if student has bus route and bus fee due
                        bool busFeeAlreadyPaid = false;
                        
                        if (s.busRoute != null && s.busRoute!.isNotEmpty) {
                          // Check if bus fee paid
                          final busPaidAmount = fees
                              .where((f) => (f['FEE TYPE'] as String? ?? '').contains('Bus Fee'))
                              .fold<double>(0, (sum, f) => sum + (double.tryParse((f['AMOUNT'] as dynamic).toString()) ?? 0));
                          
                          if (busPaidAmount > 0) {
                            busFeeAlreadyPaid = true;
                          } else {
                            // Fetch bus fee for this route
                            // This will be done via FutureBuilder below
                          }
                        }
                        
                        return FutureBuilder<double>(
                          future: (s.busRoute != null && s.busRoute!.isNotEmpty && !busFeeAlreadyPaid)
                              ? SupabaseService.getBusFeeByRoute(s.busRoute!)
                              : Future.value(0),
                          builder: (context, busFeeSnap) {
                            if (busFeeSnap.connectionState == ConnectionState.waiting) {
                              return const SizedBox();
                            }
                            
                            final busFee = busFeeSnap.data ?? 0;
                            final hasBusFeesDue = busFee > 0 && !busFeeAlreadyPaid;
                            
                            if (termsWithDue.isEmpty && !hasBusFeesDue) {
                              return ListTile(
                                title: Text(s.name),
                                subtitle: const Text('All fees paid'),
                                trailing: const Text('PAID', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                              );
                            }
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    const SizedBox(height: 8),
                                    if (termsWithDue.isNotEmpty) ...[
                                      const Text('School Fee:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey)),
                                      for (final term in termsWithDue.keys)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 4),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text('  Due Term $term', style: const TextStyle(fontSize: 14)),
                                              Text('₹${termsWithDue[term]!.toStringAsFixed(2)}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14)),
                                            ],
                                          ),
                                        ),
                                    ],
                                    if (hasBusFeesDue) ...[
                                      if (termsWithDue.isNotEmpty) const SizedBox(height: 8),
                                      const Text('Bus Fee:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey)),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('  Route: ${s.busRoute}', style: const TextStyle(fontSize: 14)),
                                            Text('₹${busFee.toStringAsFixed(2)}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14)),
                                          ],
                                        ),
                                      ),
                                    ],
                                    if ((termsWithDue.isNotEmpty || hasBusFeesDue) && (termsWithDue.length > 1 || (termsWithDue.isNotEmpty && hasBusFeesDue)))
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('Total Due', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                                            Text(
                                              '₹${(termsWithDue.values.fold<double>(0, (a, b) => a + b) + (hasBusFeesDue ? busFee : 0)).toStringAsFixed(2)}',
                                              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14),
                                            ),
                                          ],
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
        ],
      ]),
    );
  }
}

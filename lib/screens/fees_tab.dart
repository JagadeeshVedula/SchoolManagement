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
  String? _selectedPaymentType; // 'School Fee','Tuition Fee','Bus Fee'
  String? _selectedClass;
  List<String> _classes = [];
  List<Student> _students = [];
  Student? _selectedStudent;

  // Fee form fields
  String? _selectedTermMonth;
  final _termYear = TextEditingController();
  final _feeType = TextEditingController();
  final _amount = TextEditingController();
  final _busRoute = TextEditingController(); // For Bus Fee route selection
  final _concession = TextEditingController(); // Concession amount input
  // Term No selections (checkboxes)
  final Map<int, bool> _termSelections = {1: false, 2: false, 3: false};

  // Dues
  String? _selectedDueType; // 'School', 'Bus'

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
    } else if (_selectedPaymentType == 'Tuition Fee') {
      newTuitionFeeConcession = concessionAmount;
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

  @override
  void dispose() {
    _termYear.dispose();
    _feeType.dispose();
    _amount.dispose();
    _busRoute.dispose();
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
          ChoiceChip(label: const Text('Tuition Fee'), selected: _selectedPaymentType == 'Tuition Fee', onSelected: (_) => setState(() => _selectedPaymentType = 'Tuition Fee')),
          ChoiceChip(label: const Text('Bus Fee'), selected: _selectedPaymentType == 'Bus Fee', onSelected: (_) => setState(() => _selectedPaymentType = 'Bus Fee')),
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
                        : _selectedPaymentType == 'Tuition Fee'
                            ? 'Tuition Fee Concession (Current: ₹${_selectedStudent!.tuitionFeeConcession.toStringAsFixed(2)})'
                            : 'Bus Fee (No Concession)',
                    border: const OutlineInputBorder(),
                    enabled: _selectedPaymentType != 'Bus Fee',
                  ),
                  keyboardType: TextInputType.number,
                  enabled: _selectedPaymentType != 'Bus Fee',
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: ElevatedButton(
                    onPressed: _selectedPaymentType == 'Bus Fee' ? null : _saveConcession,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      disabledBackgroundColor: Colors.grey[300],
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
              
              // Determine concession based on selected payment type
              final concession = _selectedPaymentType == 'School Fee' 
                  ? _selectedStudent!.schoolFeeConcession
                  : (_selectedPaymentType == 'Tuition Fee'
                      ? _selectedStudent!.tuitionFeeConcession
                      : 0.0);
              
              // For Bus Fee, show route selection and fetch fee from TRANSPORT table
              if (_selectedPaymentType == 'Bus Fee') {
                return FutureBuilder<List<String>>(
                  future: SupabaseService.getUniqueRoutes(),
                  builder: (context, routesSnap) {
                    if (routesSnap.connectionState == ConnectionState.waiting) {
                      return const CircularProgressIndicator();
                    }
                    final routes = routesSnap.data ?? [];
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Select Route:', style: TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                value: _busRoute.text.isEmpty ? null : _busRoute.text,
                                items: routes.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                                onChanged: (route) {
                                  if (route != null) {
                                    setState(() => _busRoute.text = route);
                                  }
                                },
                                decoration: const InputDecoration(
                                  labelText: 'Choose Route',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              if (_busRoute.text.isNotEmpty)
                                FutureBuilder<double>(
                                  future: SupabaseService.getBusFeeByRoute(_busRoute.text),
                                  builder: (context, feeSnap) {
                                    final fee = feeSnap.data ?? 0;
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 12),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('Bus Fee for ${_busRoute.text}:', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                                          Text('₹${fee.toStringAsFixed(2)}', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.green)),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              }
              
              // Calculate term fees with concession for School and Tuition Fee
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
                                  _selectedPaymentType ?? '',
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
            },
          ),
          const SizedBox(height: 16),
          const Text('Payment Details', style: TextStyle(fontWeight: FontWeight.w600)),
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
            child: const Text('School Fees Due'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _selectedDueType == 'Tuition Fee' ? Colors.blue : Colors.grey,
            ),
            onPressed: () => setState(() => _selectedDueType = 'Tuition Fee'),
            child: const Text('Tuition Fees Due'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _selectedDueType == 'Bus Fee' ? Colors.blue : Colors.grey,
            ),
            onPressed: () => setState(() => _selectedDueType = 'Bus Fee'),
            child: const Text('Bus Fees Due'),
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
              if (_selectedDueType == 'Bus Fee')
                // Bus Fee logic: Calculate due based on FEE TYPE = 'Bus Fee' and current TERM YEAR
                FutureBuilder<Map<String, dynamic>>(
                  future: SupabaseService.getBusFeeDueForCurrentYear(s.name),
                  builder: (context, busDueSnap) {
                    if (busDueSnap.connectionState == ConnectionState.waiting) {
                      return const SizedBox();
                    }
                    
                    final busData = busDueSnap.data ?? {};
                    final paidAmount = (busData['paid'] as num?)?.toDouble() ?? 0;
                    final year = (busData['year'] as String?) ?? DateTime.now().year.toString();
                    
                    // If no Bus Fee payment records exist, mark as due (unpaid)
                    if (paidAmount == 0) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Bus Fee Due ($year)', style: const TextStyle(fontSize: 14)),
                                  Text('Unpaid', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              const Text('No payment recorded for this year', style: TextStyle(color: Colors.orange, fontSize: 12)),
                            ],
                          ),
                        ),
                      );
                    }
                    
                    // If bus fee has been paid, show paid status
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 4),
                                Text('₹${paidAmount.toStringAsFixed(2)} paid', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                            const Text('PAID', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    );
                  },
                )
              else
                // School and Tuition Fee logic: show due based on terms
                FutureBuilder<Map<String, dynamic>?>(
                  future: SupabaseService.getFeeStructureByClass(s.className),
                  builder: (context, structureSnap) {
                    if (structureSnap.connectionState == ConnectionState.waiting) {
                      return const SizedBox();
                    }
                    final structure = structureSnap.data;
                    if (structure == null) return const SizedBox();
                    
                    final totalFee = double.tryParse((structure['FEE'] as dynamic).toString()) ?? 0;
                    
                    // Determine concession based on selected due type
                    final concession = _selectedDueType == 'School Fee' 
                        ? s.schoolFeeConcession
                        : s.tuitionFeeConcession;
                    
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
                          
                          // Calculate paid amount for this term and fee type
                          for (final fee in fees) {
                            if ((fee['FEE TYPE'] as String? ?? '').contains(_selectedDueType ?? '') &&
                                (fee['TERM NO'] as String? ?? '').contains(termKey)) {
                              final amt = double.tryParse((fee['AMOUNT'] as dynamic).toString()) ?? 0;
                              paidAmount += amt;
                            }
                          }
                          
                          // If paid < term fee, add to due list
                          final termFee = termFees[term]!;
                          if (paidAmount < termFee) {
                            termsWithDue[term] = termFee - paidAmount;
                          }
                        }
                        
                        if (termsWithDue.isEmpty) {
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
                                for (final term in termsWithDue.keys)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Due Term $term', style: const TextStyle(fontSize: 14)),
                                        Text('₹${termsWithDue[term]!.toStringAsFixed(2)}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14)),
                                      ],
                                    ),
                                  ),
                                if (termsWithDue.length > 1)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Total Due', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                                        Text('₹${termsWithDue.values.reduce((a, b) => a + b).toStringAsFixed(2)}', 
                                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14)),
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
                ),
          ],
        ],
      ]),
    );
  }
}

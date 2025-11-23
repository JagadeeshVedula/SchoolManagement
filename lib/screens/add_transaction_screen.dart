import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:school_management/services/supabase_service.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedAccount;
  String? _selectedType;
  DateTime? _selectedDate;
  final _amountController = TextEditingController();
  final _commentController = TextEditingController();
  bool _isLoading = false;
  List<String> _accounts = [];

  @override
  void initState() {
    super.initState();
    _fetchAccounts();
  }

  Future<void> _fetchAccounts() async {
    setState(() => _isLoading = true);
    final accounts = await SupabaseService.getAccounts();
    setState(() {
      _accounts = accounts;
      _isLoading = false;
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please select a date.', style: GoogleFonts.poppins()),
          ),
        );
        return;
      }
      setState(() => _isLoading = true);
      final success = await SupabaseService.addTransaction({
        'ACCOUNT': _selectedAccount,
        'DATE': DateFormat('yyyy-MM-dd').format(_selectedDate!),
        'TYPE': _selectedType,
        'AMOUNT': double.parse(_amountController.text),
        'COMMENT': _commentController.text,
      });
      setState(() => _isLoading = false);
      if (success) {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add transaction.', style: GoogleFonts.poppins()),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Transaction', style: GoogleFonts.poppins()),
        backgroundColor: Colors.green[600],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green[50]!, Colors.green[100]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildDropdown(_selectedAccount, 'Select Account', _accounts, (newValue) {
                        setState(() {
                          _selectedAccount = newValue;
                        });
                      }),
                      const SizedBox(height: 16),
                      _buildDropdown(_selectedType, 'Select Type', ['Credit', 'Debit'], (newValue) {
                        setState(() {
                          _selectedType = newValue;
                        });
                      }),
                      const SizedBox(height: 16),
                      _buildTextFormField(_amountController, 'Amount', TextInputType.number),
                      const SizedBox(height: 16),
                      _buildTextFormField(_commentController, 'Comment', TextInputType.text),
                      const SizedBox(height: 16),
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: ListTile(
                          title: Text(
                            _selectedDate == null
                                ? 'Select Date'
                                : DateFormat('yyyy-MM-dd').format(_selectedDate!),
                            style: GoogleFonts.poppins(),
                          ),
                          trailing: const Icon(Icons.calendar_today),
                          onTap: () => _selectDate(context),
                        ),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[600],
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(
                          'Submit',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildDropdown(
    String? value,
    String hint,
    List<String> items,
    void Function(String?) onChanged,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: DropdownButtonFormField<String>(
          value: value,
          decoration: InputDecoration(
            labelText: hint,
            labelStyle: GoogleFonts.poppins(),
            border: InputBorder.none,
          ),
          hint: Text(hint, style: GoogleFonts.poppins()),
          isExpanded: true,
          items: items.map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value, style: GoogleFonts.poppins()),
            );
          }).toList(),
          onChanged: onChanged,
          validator: (value) => value == null ? 'Please select a value' : null,
        ),
      ),
    );
  }

  Widget _buildTextFormField(
    TextEditingController controller,
    String label,
    TextInputType keyboardType,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: TextFormField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            labelStyle: GoogleFonts.poppins(),
            border: InputBorder.none,
          ),
          keyboardType: keyboardType,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a $label';
            }
            if (keyboardType == TextInputType.number && double.tryParse(value) == null) {
              return 'Please enter a valid number';
            }
            return null;
          },
        ),
      ),
    );
  }
}

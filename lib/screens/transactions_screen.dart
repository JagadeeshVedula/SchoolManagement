import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:school_management/screens/add_transaction_screen.dart';
import 'package:school_management/services/supabase_service.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  List<Map<String, dynamic>> _transactions = [];
  List<String> _accounts = [];
  String? _selectedAccount;
  DateTime? _selectedDate;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    final accounts = await SupabaseService.getAccounts();
    final transactions = await SupabaseService.getTransactions(
      account: _selectedAccount,
      date: _selectedDate,
    );
    setState(() {
      _accounts = accounts;
      _transactions = transactions;
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
      _fetchData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Transactions', style: GoogleFonts.poppins()),
        backgroundColor: Colors.green[600],
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, size: 30),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddTransactionScreen(),
                ),
              );
              if (result == true) {
                _fetchData();
              }
            },
          ),
        ],
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
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedAccount,
                                decoration: InputDecoration(
                                  labelText: 'Account',
                                  labelStyle: GoogleFonts.poppins(),
                                  border: InputBorder.none,
                                ),
                                hint: Text('All Accounts', style: GoogleFonts.poppins()),
                                isExpanded: true,
                                items: [
                                  const DropdownMenuItem<String>(
                                    value: null,
                                    child: Text('All Accounts'),
                                  ),
                                  ..._accounts.map((String value) {
                                    return DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(value, style: GoogleFonts.poppins()),
                                    );
                                  }).toList(),
                                ],
                                onChanged: (String? newValue) {
                                  setState(() {
                                    _selectedAccount = newValue;
                                  });
                                  _fetchData();
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            TextButton.icon(
                              onPressed: () => _selectDate(context),
                              icon: const Icon(Icons.calendar_today),
                              label: Text(
                                _selectedDate == null
                                    ? 'Select Date'
                                    : DateFormat('yyyy-MM-dd').format(_selectedDate!),
                                style: GoogleFonts.poppins(),
                              ),
                            ),
                            if (_selectedDate != null)
                              IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setState(() {
                                    _selectedDate = null;
                                  });
                                  _fetchData();
                                },
                              )
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _transactions.length,
                      itemBuilder: (context, index) {
                        final transaction = _transactions[index];
                        final isCredit = transaction['TYPE'] == 'Credit';
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: isCredit ? Colors.green[200]! : Colors.red[200]!,
                              width: 1,
                            ),
                          ),
                          child: ListTile(
                            leading: Icon(
                              isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                              color: isCredit ? Colors.green : Colors.red,
                            ),
                            title: Text(
                              transaction['ACCOUNT'] ?? '',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              '${transaction['COMMENT'] ?? ''}',
                              style: GoogleFonts.poppins(),
                            ),
                            trailing: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '₹${transaction['AMOUNT']?.toString() ?? '0'}',
                                  style: GoogleFonts.poppins(
                                    color: isCredit ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  transaction['DATE'] != null
                                      ? DateFormat('dd MMM yyyy')
                                          .format(DateFormat('dd-MM-yyyy').parse(transaction['DATE']))
                                      : '',
                                  style: GoogleFonts.poppins(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:school_management/services/supabase_service.dart';
import 'package:intl/intl.dart';

class DieselDataScreen extends StatefulWidget {
  const DieselDataScreen({super.key});

  @override
  State<DieselDataScreen> createState() => _DieselDataScreenState();
}

class _DieselDataScreenState extends State<DieselDataScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _routeNoController = TextEditingController();
  final _busNoController = TextEditingController();
  final _litresFilledController = TextEditingController();
  final _amountController = TextEditingController();
  DateTime? _selectedDate;
  List<String> _busNumbers = [];
  List<String> _busRegistrations = [];
  String? _selectedBusNumber;
  String? _selectedBusReg;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTransportData();
  }

  Future<void> _loadTransportData() async {
    try {
      final transportData = await SupabaseService.getTransportDetails();
      setState(() {
        _busNumbers = transportData['busNumbers'] ?? [];
        _busRegistrations = transportData['busRegistrations'] ?? [];
      });
    } catch (e) {
      print('Error loading transport data: $e');
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (pickedDate != null && pickedDate != _selectedDate) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  Future<void> _submitDieselData() async {
    if (_selectedBusNumber == null ||
        _selectedBusReg == null ||
        _selectedDate == null ||
        _litresFilledController.text.isEmpty ||
        _amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please fill all fields',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red[600],
        ),
      );
      return;
    }

    try {
      final data = {
        'RouteNo': _selectedBusNumber,
        'BusNo': _selectedBusReg,
        'FilledDate': _selectedDate?.toIso8601String().split('T')[0],
        'FilledLitres': double.parse(_litresFilledController.text),
        'Amount': double.parse(_amountController.text),
      };

      final success = await SupabaseService.insertDieselData(data);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Diesel data added successfully!',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green[600],
          ),
        );

        // Clear form
        _selectedBusNumber = null;
        _selectedBusReg = null;
        _selectedDate = null;
        _litresFilledController.clear();
        _amountController.clear();
        setState(() {});
      }
    } catch (e) {
      print('Error submitting diesel data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: ${e.toString()}',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _routeNoController.dispose();
    _busNoController.dispose();
    _litresFilledController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Diesel Data Management',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          backgroundColor: Colors.deepOrange[700],
          elevation: 2,
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            tabs: [
              Tab(
                child: Text(
                  'Add Diesel Data',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Tab(
                child: Text(
                  'View Current Day Data',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildAddDieselDataForm(),
            _buildViewCurrentDayData(),
          ],
        ),
      ),
    );
  }

  Widget _buildAddDieselDataForm() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange[50]!, Colors.deepOrange[50]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add Diesel Fuel Data',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.deepOrange[900],
              ),
            ),
            const SizedBox(height: 24),
            // Route No Dropdown (BusNumber)
            Text(
              'Route No (Bus Number)',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.deepOrange[300]!, width: 1),
              ),
              child: DropdownButton<String>(
                value: _selectedBusNumber,
                isExpanded: true,
                underline: const SizedBox(),
                hint: Padding(
                  padding: const EdgeInsets.only(left: 16.0),
                  child: Text(
                    'Select Route No',
                    style: GoogleFonts.poppins(color: Colors.grey[600]),
                  ),
                ),
                items: _busNumbers.map((busNumber) {
                  return DropdownMenuItem(
                    value: busNumber,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16.0),
                      child: Text(
                        busNumber,
                        style: GoogleFonts.poppins(),
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedBusNumber = value;
                  });
                },
              ),
            ),
            const SizedBox(height: 20),
            // Bus No Dropdown (BusReg)
            Text(
              'Bus No (Registration)',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.deepOrange[300]!, width: 1),
              ),
              child: DropdownButton<String>(
                value: _selectedBusReg,
                isExpanded: true,
                underline: const SizedBox(),
                hint: Padding(
                  padding: const EdgeInsets.only(left: 16.0),
                  child: Text(
                    'Select Bus Registration',
                    style: GoogleFonts.poppins(color: Colors.grey[600]),
                  ),
                ),
                items: _busRegistrations.map((busReg) {
                  return DropdownMenuItem(
                    value: busReg,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16.0),
                      child: Text(
                        busReg,
                        style: GoogleFonts.poppins(),
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedBusReg = value;
                  });
                },
              ),
            ),
            const SizedBox(height: 20),
            // Date Picker
            Text(
              'Date',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _selectDate(context),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.deepOrange[300]!, width: 1),
                  color: Colors.white,
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: Colors.deepOrange[600]),
                    const SizedBox(width: 12),
                    Text(
                      _selectedDate == null
                          ? 'Select Date'
                          : DateFormat('yyyy-MM-dd').format(_selectedDate!),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: _selectedDate == null ? Colors.grey[600] : Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Litres Filled
            Text(
              'Litres Filled',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _litresFilledController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: 'Enter litres',
                hintStyle: GoogleFonts.poppins(color: Colors.grey[600]),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.deepOrange[300]!, width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.deepOrange[300]!, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.deepOrange[700]!, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              style: GoogleFonts.poppins(),
            ),
            const SizedBox(height: 20),
            // Amount
            Text(
              'Amount',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: 'Enter amount',
                hintStyle: GoogleFonts.poppins(color: Colors.grey[600]),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.deepOrange[300]!, width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.deepOrange[300]!, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.deepOrange[700]!, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              style: GoogleFonts.poppins(),
            ),
            const SizedBox(height: 32),
            // Update Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitDieselData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange[700],
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
                child: Text(
                  'Update',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewCurrentDayData() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange[50]!, Colors.deepOrange[50]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: SupabaseService.getDieselDataByDate(DateTime.now()),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Colors.deepOrange[600]),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading data',
                style: GoogleFonts.poppins(color: Colors.red[600]),
              ),
            );
          }

          final dieselData = snapshot.data ?? [];

          if (dieselData.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.local_gas_station,
                    size: 64,
                    color: Colors.deepOrange[600],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No Diesel Data Today',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.deepOrange[900],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No fuel data recorded for today',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: dieselData.length,
            itemBuilder: (context, index) {
              final data = dieselData[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      colors: [Colors.white, Colors.orange[50]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.deepOrange[100],
                            ),
                            child: Icon(
                              Icons.local_gas_station,
                              color: Colors.deepOrange[700],
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Route: ${data['RouteNo'] ?? 'N/A'}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.deepOrange[800],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Bus: ${data['BusNo'] ?? 'N/A'}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Litres',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${data['FilledLitres'] ?? 0.0} L',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.deepOrange[800],
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Amount',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '₹${data['Amount'] ?? 0.0}',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.green[700],
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Date',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('dd/MM/yyyy').format(
                                  DateTime.parse(data['FilledDate'] ?? DateTime.now().toIso8601String()),
                                ),
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.deepOrange[800],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

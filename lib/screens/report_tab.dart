import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:school_management/models/staff.dart';
import 'package:school_management/models/student.dart';
import 'package:school_management/screens/due_report_tab.dart';
import 'package:school_management/services/supabase_service.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io' show File;
import 'dart:typed_data' show Uint8List;
import 'dart:html' as html;

class ReportTab extends StatefulWidget {
  const ReportTab({super.key});

  @override
  State<ReportTab> createState() => _ReportTabState();
}

class _ReportTabState extends State<ReportTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Fee Report State
  String? _selectedFeeType = 'School Fee'; // Only 'School Fee' now
  String? _selectedFeeSection;
  String? _selectedFeeClass;
  Map<String, List<String>> _classData = {};
  List<String> _classes = [];
  List<Map<String, dynamic>> _feeReportData = [];
  bool _isFeeLoading = false;

  // Diesel Report State
  DateTimeRange? _dieselDateRange;
  List<Map<String, dynamic>> _dieselReportData = [];
  bool _isDieselLoading = false;

  // Transactions Report State
  DateTimeRange? _transactionsDateRange;
  List<Map<String, dynamic>> _transactionsReportData = [];
  bool _isTransactionsLoading = false;

  // Staff Leave Report State
  List<Staff> _staffList = [];
  Staff? _selectedStaff;
  String _selectedLeaveMonth = DateFormat('yyyy-MM').format(DateTime.now());
  List<Map<String, dynamic>> _staffLeaveReportData = [];
  bool _isStaffLeaveLoading = false;

  // Daily Report State
  DateTime _selectedDailyDate = DateTime.now();
  List<Map<String, dynamic>> _dailyReportData = [];
  bool _isDailyLoading = false;

  // Bus Due Report State
  String? _selectedBusNumber;
  List<String> _busNumbers = [];
  List<Map<String, dynamic>> _busDueReportData = [];
  bool _isBusDueLoading = false;

  // Due Statement State
  DateTime _selectedDueStatementDate = DateTime.now();
  List<Map<String, dynamic>> _dueStatementReportData = [];
  bool _isDueStatementLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
    _loadClasses();
    _loadStaff();
    _loadDailyReportData(); // Initial load for daily report tab
    _loadBusNumbers(); // Load bus numbers for bus due report tab
    _dieselDateRange = DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 7)),
      end: DateTime.now(),
    );
    _transactionsDateRange = DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 7)),
      end: DateTime.now(),
    );

    // Add a listener to the TabController to load data when a tab is selected.
    _tabController.addListener(() {
      // Rebuild the widget to update tab colors
      setState(() {});

      if (_tabController.indexIsChanging) {
        switch (_tabController.index) {
          case 1: // Diesel Report
            if (_dieselReportData.isEmpty) _loadDieselReportData();
            break;
          case 2: // Transactions Report
            if (_transactionsReportData.isEmpty) _loadTransactionsReportData();
            break;
          case 3: // Staff Leave Report
            if (_staffLeaveReportData.isEmpty && _selectedStaff != null) _loadStaffLeaveReportData();
            break;
          case 4: // Due Report
            break;
          case 5: // Daily Report
            if (_dailyReportData.isEmpty) _loadDailyReportData();
            break;
          case 6: // Bus Due Report
            if (_busNumbers.isEmpty) _loadBusNumbers();
            break;
          case 7: // Due Statement
            if (_dueStatementReportData.isEmpty) _loadDueStatementReportData();
            break;
        }
      }
    });
  }

  Future<void> _loadClasses() async {
    final classData = await SupabaseService.getUniqueClassesAndSections();
    if (mounted) {
      setState(() {
        _classData = classData;
        _classes = classData.keys.toList();
      });
    }
  }

  Future<void> _loadStaff() async {
    final staff = await SupabaseService.getAllStaff();
    setState(() => _staffList = staff);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // #region Data Loading Methods

  Future<void> _loadFeeReportData() async {
    if (_selectedFeeType == null || _selectedFeeClass == null) {
      setState(() => _feeReportData = []);
      return;
    }

    setState(() => _isFeeLoading = true);

    try {
      final List<Student> students;
      if (_selectedFeeSection != null) {
        students = await SupabaseService.getStudentsByClass('$_selectedFeeClass-$_selectedFeeSection');
      } else {
        students = await SupabaseService.getStudentsByClassPrefix(_selectedFeeClass!);
      }

      if (students.isEmpty) {
        setState(() {
          _feeReportData = [];
          _isFeeLoading = false;
        });
        return;
      }

      // --- OPTIMIZED BATCH FETCHING ---
      final studentNames = students.map((s) => s.name).toList();
      
      // Fetch all required data in parallel
      final futures = await Future.wait([
        SupabaseService.getFeesForStudents(studentNames),
        SupabaseService.client.from('FEE STRUCTURE').select(),
        SupabaseService.client.from('TRANSPORT').select(),
        SupabaseService.client.from('BOOKS').select(),
        SupabaseService.client.from('UNIFORM').select(),
      ].map((e) => e as Future<dynamic>));

      final allFeesByStudent = futures[0] as Map<String, List<Map<String, dynamic>>>;
      final feeStructures = futures[1] as List;
      final transportFees = futures[2] as List;
      final booksData = futures[3] as List;
      final uniformData = futures[4] as List;

      // Create lookup maps for performance
      final feeStructureMap = {for (var f in feeStructures) f['CLASS']: f};
      final transportMap = {for (var t in transportFees) t['Route']: double.tryParse(t['Fees'].toString()) ?? 0.0};
      final booksMap = {for (var b in booksData) b['CLASS']: double.tryParse(b['BOOKS FEE'].toString()) ?? 0.0};
      final uniformMap = {for (var u in uniformData) '${u['CLASS']}-${u['GENDER']}': double.tryParse(u['UNIFORM FEE'].toString()) ?? 0.0};

      final reportData = <Map<String, dynamic>>[];

      for (final student in students) {
        final fees = allFeesByStudent[student.name] ?? [];
        final classNameOnly = student.className.split('-').first;
        final feeStructure = feeStructureMap[classNameOnly] ?? {};
        
        if (feeStructure.isEmpty) continue;

        final totalFee = double.tryParse(feeStructure['FEE']?.toString() ?? '0') ?? 0;
        final concession = student.schoolFeeConcession;
        final termFees = SupabaseService.calculateTermFees(totalFee, concession);

        // Bus Fee
        double busFeeFull = 0;
        if (student.busFacility?.toLowerCase() == 'yes' && student.busRoute != null) {
          final rawBusFee = transportMap[student.busRoute] ?? 0.0;
          busFeeFull = (rawBusFee - student.busFeeConcession).clamp(0, double.infinity);
        }
        final busFeePaid = fees.where((f) => (f['FEE TYPE'] as String? ?? '').toLowerCase().contains('bus fee')).fold<double>(0, (sum, f) => sum + (double.tryParse(f['AMOUNT']?.toString() ?? '0') ?? 0));
        final busFeeDue = (busFeeFull - busFeePaid).clamp(0, double.infinity);

        // Books Fee
        final booksFeeFull = booksMap[classNameOnly] ?? 0.0;
        final booksFeePaid = fees.where((f) => (f['FEE TYPE'] as String? ?? '').toLowerCase().contains('books fee')).fold<double>(0, (sum, f) => sum + (double.tryParse(f['AMOUNT']?.toString() ?? '0') ?? 0));
        final booksFeeDue = (booksFeeFull - booksFeePaid).clamp(0, double.infinity);

        // Uniform Fee
        final gender = student.gender ?? 'Male';
        final uniformFeeFull = uniformMap['$classNameOnly-$gender'] ?? 0.0;
        final uniformFeePaid = fees.where((f) => (f['FEE TYPE'] as String? ?? '').toLowerCase().contains('uniform fee')).fold<double>(0, (sum, f) => sum + (double.tryParse(f['AMOUNT']?.toString() ?? '0') ?? 0));
        final uniformFeeDue = (uniformFeeFull - uniformFeePaid).clamp(0, double.infinity);

        final Map<String, dynamic> termData = {
          'Student Name': student.name,
          'Class': student.className,
          'Gender': gender,
          'Bus Fee': busFeeFull,
          'Bus Fee Paid': busFeePaid,
          'Bus Fee Due': busFeeDue,
          'Books Fee': booksFeeFull,
          'Books Fee Paid': booksFeePaid,
          'Books Fee Due': booksFeeDue,
          'Uniform Fee': uniformFeeFull,
          'Uniform Fee Paid': uniformFeePaid,
          'Uniform Fee Due': uniformFeeDue,
        };

        // Term calculations
        for (int term = 1; term <= 3; term++) {
          final termKey = 'Term $term';
          double termPaid = 0;
          for (final fee in fees) {
            final type = (fee['FEE TYPE'] as String? ?? '').toLowerCase();
            final termNo = (fee['TERM NO'] as String? ?? '');
            if (type.contains('school fee') && termNo.contains(termKey)) {
              termPaid += double.tryParse(fee['AMOUNT']?.toString() ?? '0') ?? 0;
            }
          }
          final termFee = termFees[term] ?? 0.0;
          termData['Term$term Fee'] = termFee;
          termData['Term$term Paid'] = termPaid;
          termData['Term$term Due'] = (termFee - termPaid).clamp(0, double.infinity);
        }

        final totalDue = termData['Term1 Due'] + termData['Term2 Due'] + termData['Term3 Due'] + busFeeDue + booksFeeDue + uniformFeeDue;
        termData['Overall Status'] = totalDue <= 0 ? 'PAID' : 'PENDING';

        reportData.add(termData);
      }

      setState(() {
        _feeReportData = reportData;
        _isFeeLoading = false;
      });
    } catch (e) {
      print('Error loading report: $e');
      setState(() => _isFeeLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading report: $e')),
      );
    }
  }

  Future<void> _loadDieselReportData() async {
    if (_dieselDateRange == null) return;
    setState(() => _isDieselLoading = true);
    final data = await SupabaseService.getDieselDataForReport(
      _dieselDateRange!.start,
      _dieselDateRange!.end,
    );
    setState(() {
      _dieselReportData = data;
      _isDieselLoading = false;
    });
  }

  Future<void> _loadTransactionsReportData() async {
    if (_transactionsDateRange == null) return;
    setState(() => _isTransactionsLoading = true);
    final data = await SupabaseService.getTransactionsForReport(
      _transactionsDateRange!.start,
      _transactionsDateRange!.end,
    );
    setState(() {
      _transactionsReportData = data;
      _isTransactionsLoading = false;
    });
  }

  Future<void> _loadStaffLeaveReportData() async {
    if (_selectedStaff == null) return;
    setState(() => _isStaffLeaveLoading = true);
    final data = await SupabaseService.getStaffLeaveForReport(
      staffName: _selectedStaff!.name,
      monthYear: _selectedLeaveMonth,
    );
    setState(() {
      _staffLeaveReportData = data;
      _isStaffLeaveLoading = false;
    });
  }

  Future<void> _loadDailyReportData() async {
    setState(() => _isDailyLoading = true);
    try {
      final data = await SupabaseService.getDailyReportData(_selectedDailyDate);
      setState(() {
        _dailyReportData = data;
        _isDailyLoading = false;
      });
    } catch (e) {
      setState(() => _isDailyLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading daily report: $e')),
      );
    }
  }

  Future<void> _loadBusNumbers() async {
    final busNumbers = await SupabaseService.getBusNumbersList();
    setState(() {
      _busNumbers = busNumbers;
    });
  }

  Future<void> _loadBusDueReportData() async {
    if (_selectedBusNumber == null) return;
    setState(() => _isBusDueLoading = true);
    try {
      final students = await SupabaseService.getStudentsByBusNo(_selectedBusNumber!);
      final List<Map<String, dynamic>> reportData = [];
      
      // Batch fetch all fees for these students to optimize
      final studentNames = students.map((s) => s.name).toList();
      final allFeesByStudent = await SupabaseService.getFeesForStudents(studentNames);
      
      // Cache for fee structures
      final feeStructureCache = <String, Map<String, dynamic>>{};

      for (final student in students) {
        final fees = allFeesByStudent[student.name] ?? [];
        
        // 1. Bus Fee Logic
        final busTotalFee = await SupabaseService.getBusFeeByRoute(student.busRoute ?? '');
        final busConcession = student.busFeeConcession;
        final busEffectiveTotal = (busTotalFee - busConcession).clamp(0, double.infinity);
        final busPaidFee = fees
            .where((f) => (f['FEE TYPE'] as String? ?? '').toLowerCase().contains('bus fee'))
            .fold<double>(0, (sum, f) => sum + (double.tryParse((f['AMOUNT'] as dynamic).toString()) ?? 0));
        final busPendingFee = (busEffectiveTotal - busPaidFee).clamp(0, double.infinity);

        // 2. School Fee Logic
        final classNameOnly = student.className.split('-').first;
        if (!feeStructureCache.containsKey(classNameOnly)) {
          feeStructureCache[classNameOnly] = await SupabaseService.getFeeStructureByClass(classNameOnly) ?? {};
        }
        final feeStructure = feeStructureCache[classNameOnly]!;
        final schoolTotalFee = double.tryParse(feeStructure['FEE']?.toString() ?? '0') ?? 0;
        final schoolConcession = student.schoolFeeConcession;
        final schoolEffectiveTotal = (schoolTotalFee - schoolConcession).clamp(0, double.infinity);
        final schoolPaidFee = fees
            .where((f) => (f['FEE TYPE'] as String? ?? '').toLowerCase().contains('school fee'))
            .fold<double>(0, (sum, f) => sum + (double.tryParse((f['AMOUNT'] as dynamic).toString()) ?? 0));
        final schoolPendingFee = (schoolEffectiveTotal - schoolPaidFee).clamp(0, double.infinity);

        // 3. Last Paid Date
        String lastPaidDateStr = 'No Payments';
        if (fees.isNotEmpty) {
          DateTime? latestDate;
          for (final f in fees) {
             final dateStr = f['DATE'] as String?;
             if (dateStr == null) continue;
             DateTime? d = DateFormat('dd-MM-yyyy').tryParse(dateStr);
             d ??= DateFormat('yyyy-MM-dd').tryParse(dateStr);
             if (d != null) {
               if (latestDate == null || d.isAfter(latestDate)) {
                 latestDate = d;
               }
             }
          }
          if (latestDate != null) {
            lastPaidDateStr = DateFormat('dd-MM-yyyy').format(latestDate);
          }
        }
        
        reportData.add({
          'Student Name': student.name,
          'Class': student.className,
          'Route': student.busRoute ?? 'N/A',
          'Bus Total': busTotalFee,
          'Bus Concession': busConcession,
          'Bus Paid': busPaidFee,
          'Bus Pending': busPendingFee,
          'School Total': schoolTotalFee,
          'School Concession': schoolConcession,
          'School Paid': schoolPaidFee,
          'School Pending': schoolPendingFee,
          'Parent Mobile': student.parentMobile ?? 'N/A',
          'Overall Total': busTotalFee + schoolTotalFee,
          'Overall Due': busPendingFee + schoolPendingFee,
          'Last Paid Date': lastPaidDateStr,
        });
      }
      
      setState(() {
        _busDueReportData = reportData;
        _isBusDueLoading = false;
      });
    } catch (e) {
      setState(() => _isBusDueLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading bus due report: $e')),
      );
    }
  }

  Future<void> _loadDueStatementReportData() async {
    setState(() => _isDueStatementLoading = true);
    try {
      final students = await SupabaseService.getAllStudents();
      
      // Fetch all fees - filter in Dart because DATE column is often stored as dd-MM-yyyy string
      final res = await SupabaseService.client.from('FEES').select();
      final List<Map<String, dynamic>> allFeesFromDb = (res as List).cast<Map<String, dynamic>>();
      
      final normalizedSelectedDate = DateTime(_selectedDueStatementDate.year, _selectedDueStatementDate.month, _selectedDueStatementDate.day);
      
      final List<Map<String, dynamic>> allFees = allFeesFromDb.where((f) {
        final dateStr = f['DATE'] as String?;
        if (dateStr == null) return false;
        
        DateTime? feeDate;
        try {
          feeDate = DateFormat('dd-MM-yyyy').parse(dateStr);
        } catch (_) {
          try {
            feeDate = DateFormat('yyyy-MM-dd').parse(dateStr);
          } catch (_) {}
        }
        
        if (feeDate == null) return false;
        final normalizedFeeDate = DateTime(feeDate.year, feeDate.month, feeDate.day);
        return !normalizedFeeDate.isAfter(normalizedSelectedDate);
      }).toList();

      // Pre-fetch all fee structures to avoid multiple calls
      final feeStructuresResponse = await SupabaseService.client.from('FEE STRUCTURE').select();
      final transportResponse = await SupabaseService.client.from('TRANSPORT').select();
      final hostelResponse = await SupabaseService.client.from('HOSTEL').select();
      final booksResponse = await SupabaseService.client.from('BOOKS').select();
      final uniformResponse = await SupabaseService.client.from('UNIFORM').select();

      final feeStructures = (feeStructuresResponse as List).cast<Map<String, dynamic>>();
      final transportFees = (transportResponse as List).cast<Map<String, dynamic>>();
      final hostelFees = (hostelResponse as List).cast<Map<String, dynamic>>();
      final booksFees = (booksResponse as List).cast<Map<String, dynamic>>();
      final uniformFees = (uniformResponse as List).cast<Map<String, dynamic>>();

      // Categories
      double schoolRaw = 0, schoolPaid = 0, schoolConcession = 0;
      double busRaw = 0, busPaid = 0, busConcession = 0;
      double hostelRaw = 0, hostelPaid = 0, hostelConcession = 0;
      double bookRaw = 0, bookPaid = 0; 
      double adminRaw = 0, adminPaid = 0, adminConcession = 0;

      for (final student in students) {
        final classNameOnly = student.className.split('-').first;
        final gender = student.gender ?? 'Male';

        // 1. School Fee
        final fs = feeStructures.firstWhere((f) => f['CLASS'] == classNameOnly, orElse: () => {});
        if (fs.isNotEmpty) {
          final rawFee = double.tryParse(fs['FEE']?.toString() ?? '0') ?? 0;
          schoolRaw += rawFee;
          schoolConcession += student.schoolFeeConcession;
        }

        // 2. Bus Fee
        if (student.busFacility?.toLowerCase() == 'yes' && student.busRoute != null && student.busRoute!.isNotEmpty) {
          final ts = transportFees.firstWhere((t) => t['Route'] == student.busRoute, orElse: () => {});
          if (ts.isNotEmpty) {
            final rawFee = double.tryParse(ts['Fees']?.toString() ?? '0') ?? 0;
            busRaw += rawFee;
            busConcession += student.busFeeConcession;
          }
        }

        // 3. Hostel Fee
        if (student.hostelFacility?.toLowerCase() == 'yes') {
          final hs = hostelFees.firstWhere((h) => h['CLASS'] == classNameOnly, orElse: () => {});
          if (hs.isNotEmpty) {
            final rawFee = double.tryParse(hs['HOSTEL_FEE']?.toString() ?? '0') ?? 0;
            hostelRaw += rawFee;
            hostelConcession += student.hostelFeeConcession;
          }
        }

        // 4. Book Fee
        final bs = booksFees.firstWhere((b) => b['CLASS'] == classNameOnly, orElse: () => {});
        if (bs.isNotEmpty) {
          bookRaw += double.tryParse(bs['BOOKS FEE']?.toString() ?? '0') ?? 0;
        }

        // 5. Administration Fee (Logic: Total = Count*500, Paid = Count(YES)*500, Concession = Count(NO)*500)
        adminRaw += 500;
        if (student.adminFee?.toUpperCase() == 'YES') {
          adminPaid += 500;
        } else {
          adminConcession += 500;
        }

        // Calculate Paid amounts for other student fees
        final studentFees = allFees.where((f) => f['STUDENT NAME'] == student.name);
        for (final fee in studentFees) {
          final type = (fee['FEE TYPE'] as String? ?? '').toLowerCase();
          final amt = double.tryParse(fee['AMOUNT']?.toString() ?? '0') ?? 0;
          
          if (type.contains('school fee')) schoolPaid += amt;
          else if (type.contains('bus fee')) busPaid += amt;
          else if (type.contains('hostel')) hostelPaid += amt;
          else if (type.contains('book')) bookPaid += amt;
          // Note: Administration Fee "Paid" is derived from student's ADMIN_FEE column status
        }
      }

      final reportData = [
        {
          'Category': 'School Fee',
          'Total Fee': schoolRaw,
          'Total Paid': schoolPaid,
          'Concession': schoolConcession,
          'Total Pending': schoolRaw - schoolPaid - schoolConcession
        },
        {
          'Category': 'Administration Fee',
          'Total Fee': adminRaw,
          'Total Paid': adminPaid,
          'Concession': adminConcession,
          'Total Pending': adminRaw - adminPaid - adminConcession
        },
        {
          'Category': 'Bus Fee',
          'Total Fee': busRaw,
          'Total Paid': busPaid,
          'Concession': busConcession,
          'Total Pending': busRaw - busPaid - busConcession
        },
        {
          'Category': 'Hostel Fee',
          'Total Fee': hostelRaw,
          'Total Paid': hostelPaid,
          'Concession': hostelConcession,
          'Total Pending': hostelRaw - hostelPaid - hostelConcession
        },
        {
          'Category': 'Book Fee',
          'Total Fee': bookRaw,
          'Total Paid': bookPaid,
          'Concession': 0.0,
          'Total Pending': bookRaw - bookPaid
        },
        {
          'Category': 'GRAND TOTAL',
          'Total Fee': schoolRaw + adminRaw + busRaw + hostelRaw + bookRaw,
          'Total Paid': schoolPaid + adminPaid + busPaid + hostelPaid + bookPaid,
          'Concession': schoolConcession + adminConcession + busConcession + hostelConcession,
          'Total Pending': (schoolRaw + adminRaw + busRaw + hostelRaw + bookRaw) - 
                          (schoolPaid + adminPaid + busPaid + hostelPaid + bookPaid) - 
                          (schoolConcession + adminConcession + busConcession + hostelConcession)
        },
      ];

      setState(() {
        _dueStatementReportData = reportData;
        _isDueStatementLoading = false;
      });
    } catch (e) {
      setState(() => _isDueStatementLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading due statement: $e')),
      );
    }
  }

  // #endregion

  // #region Excel Export Methods

  Future<void> _downloadFeeExcel() async {
    if (_feeReportData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data to download')),
      );
      return;
    }

    try {
      final excel = excel_pkg.Excel.createExcel();
      final sheet = excel['Sheet1'];

      // Add header with proper columns for single-row-per-student format
      final headers = [
        'Student Name', 'Class', 'Gender',
        'Term1 Fee', 'Term1 Paid', 'Term1 Due',
        'Term2 Fee', 'Term2 Paid', 'Term2 Due',
        'Term3 Fee', 'Term3 Paid', 'Term3 Due',
        'Bus Fee', 'Bus Fee Paid', 'Bus Fee Due',
        'Books Fee', 'Books Fee Paid', 'Books Fee Due',
        'Uniform Fee', 'Uniform Fee Paid', 'Uniform Fee Due',
        'Overall Status'
      ];

      for (int i = 0; i < headers.length; i++) {
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).value = headers[i];
      }

      // Add data rows (one row per student)
      for (int rowIndex = 0; rowIndex < _feeReportData.length; rowIndex++) {
        final data = _feeReportData[rowIndex];
        int colIndex = 0;
        
        // Student info
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex + 1)).value = data['Student Name'];
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex + 1)).value = data['Class'];
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex + 1)).value = data['Gender'];
        
        // Term 1-3 columns
        for (int term = 1; term <= 3; term++) {
          sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex + 1)).value = _formatAmount(data['Term$term Fee'] as double?);
          sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex + 1)).value = _formatAmount(data['Term$term Paid'] as double?);
          sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex + 1)).value = _formatAmount(data['Term$term Due'] as double?);
        }
        
        // Bus Fee
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex + 1)).value = _formatAmount(data['Bus Fee'] as double?);
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex + 1)).value = _formatAmount(data['Bus Fee Paid'] as double?);
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex + 1)).value = _formatAmount(data['Bus Fee Due'] as double?);
        
        // Books Fee
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex + 1)).value = _formatAmount(data['Books Fee'] as double?);
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex + 1)).value = _formatAmount(data['Books Fee Paid'] as double?);
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex + 1)).value = _formatAmount(data['Books Fee Due'] as double?);
        
        // Uniform Fee
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex + 1)).value = _formatAmount(data['Uniform Fee'] as double?);
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex + 1)).value = _formatAmount(data['Uniform Fee Paid'] as double?);
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex + 1)).value = _formatAmount(data['Uniform Fee Due'] as double?);
        
        // Overall Status
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex + 1)).value = data['Overall Status'];
      }

      // Get bytes and download
      final bytes = excel.encode();
      if (bytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error encoding Excel file')),
        );
        return;
      }

      final fileName = 'School_Fee_Report_${DateFormat('yyyy-MM-dd_HHmmss').format(DateTime.now())}.xlsx';
      
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

  Future<void> _downloadGenericExcel(List<Map<String, dynamic>> data, String fileNamePrefix) async {
    if (data.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data to download')),
      );
      return;
    }

    try {
      final excel = excel_pkg.Excel.createExcel();
      final sheet = excel['Sheet1'];

      // Headers from the keys of the first map
      final headers = data.first.keys.toList();
      sheet.appendRow(headers);

      // Data rows
      for (final rowData in data) {
        final row = headers.map((header) => rowData[header]).toList();
        sheet.appendRow(row);
      }

      final bytes = excel.encode();
      if (bytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error encoding Excel file')),
        );
        return;
      }

      final fileName = '${fileNamePrefix}_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.xlsx';
      await _downloadFile(bytes, fileName);

    } catch (e) {
      print('Error downloading generic excel: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error downloading report: $e')),
      );
    }
  }

  // #endregion

  // #region Helper and Build Methods

  void _downloadFileWeb(List<int> bytes, String fileName) {
    // Web download using Blob and download link
    try {
      // Determine MIME type based on file extension
      String mimeType = 'application/octet-stream';
      if (fileName.endsWith('.pdf')) {
        mimeType = 'application/pdf';
      } else if (fileName.endsWith('.xlsx')) {
        mimeType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      }
      
      // Create a Uint8List from the bytes to ensure proper byte handling
      final uint8List = Uint8List.fromList(bytes);
      final blob = html.Blob([uint8List], mimeType);
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

  Future<void> _downloadFile(List<int> bytes, String fileName) async {
    if (kIsWeb) {
      _downloadFileWeb(bytes, fileName);
    } else {
      try {
        final directory = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$fileName');
        await file.writeAsBytes(bytes);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Downloaded: $fileName')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving file: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header with Indigo gradient
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF800000), Color(0xFFB91C1C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Institutional Reports',
                style: GoogleFonts.poppins(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Comprehensive analytics and data exports for school management',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFF800000),
            indicatorWeight: 3.0,
            labelColor: const Color(0xFF800000),
            unselectedLabelColor: const Color(0xFF64748B),
            isScrollable: true,
            labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
            unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 13),
            tabs: const [
              Tab(text: 'Fee Report'),
              Tab(text: 'Diesel Report'),
              Tab(text: 'Transactions Report'),
              Tab(text: 'Staff Leave Report'),
              Tab(text: 'Due Report'),
              Tab(text: 'Daily Report'),
              Tab(text: 'Bus Due Report'),
              Tab(text: 'Due Statement'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildFeeReportTab(),
              _buildDieselReportTab(),
              _buildTransactionsReportTab(),
              _buildStaffLeaveReportTab(),
              DueReportTab(staffList: _staffList),
              _buildDailyReportTab(),
              _buildBusDueReportTab(),
              _buildDueStatementTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeeReportTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),

          Text(
            'Select Fee Type',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildFeeTypeChip('School Fee', const Color(0xFF10B981)),
            ],
          ),
          const SizedBox(height: 24),

          // Class Selection
          if (_selectedFeeType != null) ...[
            Text(
              'Filter by Class',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedFeeClass,
                      hint: const Text('Select Class'),
                      items: _classes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedFeeClass = value;
                          _selectedFeeSection = null;
                          _feeReportData = [];
                        });
                        _loadFeeReportData();
                      },
                      decoration: InputDecoration(
                        labelText: 'Class',
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        prefixIcon: const Icon(Icons.school_outlined, color: Color(0xFF800000)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedFeeSection,
                      hint: const Text('All Sections'),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('All Sections'),
                        ),
                        ...((_selectedFeeClass != null ? (_classData[_selectedFeeClass] ?? []) : <String>[]).map((s) => DropdownMenuItem<String>(value: s, child: Text(s))).toList()),
                      ],
                      onChanged: (_selectedFeeClass == null || (_classData[_selectedFeeClass] ?? []).isEmpty) ? null : (v) {
                        setState(() {
                          _selectedFeeSection = v;
                          _feeReportData = [];
                        });
                        _loadFeeReportData();
                      },
                      decoration: InputDecoration(
                        labelText: 'Section',
                        filled: true,
                        fillColor: (_selectedFeeClass == null || (_classData[_selectedFeeClass] ?? []).isEmpty) ? const Color(0xFFE2E8F0) : const Color(0xFFF1F5F9),
                        prefixIcon: const Icon(Icons.grid_view_outlined, color: Color(0xFF800000)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Report Data Display
            if (_isFeeLoading) ...[
              const Center(child: CircularProgressIndicator()),
            ] else if (_feeReportData.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Report Results (${_feeReportData.length} students)',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _downloadFeeExcel,
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: Text('Export Excel', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Report Table
              _buildFeeReportTable(),
            ] else if (_selectedFeeClass != null) ...[
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
            ]
          ],
        ],
      ),
    );
  }

  Widget _buildDieselReportTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          ListTile(
            title: const Text('Select Date Range'),
            subtitle: Text(
              '${DateFormat.yMMMd().format(_dieselDateRange!.start)} - ${DateFormat.yMMMd().format(_dieselDateRange!.end)}',
            ),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                initialDateRange: _dieselDateRange,
              );
              if (picked != null) {
                setState(() => _dieselDateRange = picked);
                _loadDieselReportData();
              }
            },
          ),
          ElevatedButton.icon(
            onPressed: () => _downloadGenericExcel(_dieselReportData, 'Diesel_Report'),
            icon: const Icon(Icons.download),
            label: const Text('Export to Excel'),
          ),
          Expanded(
            child: _isDieselLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
              children: [
                DataTable(
                  columns: const [
                    DataColumn(label: Text('Date')),
                    DataColumn(label: Text('Route No')),
                    DataColumn(label: Text('Litres')),
                    DataColumn(label: Text('Amount')),
                  ],
                  rows: _dieselReportData
                      .map((row) => DataRow(cells: [
                    DataCell(Text(row['FilledDate']?.toString() ?? '')),
                    DataCell(Text(row['RouteNo']?.toString() ?? '')),
                    DataCell(Text(row['FilledLitres']?.toString() ?? '')),
                    DataCell(Text(row['Amount']?.toString() ?? '')),
                  ]))
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsReportTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          ListTile(
            title: const Text('Select Date Range'),
            subtitle: Text(
              '${DateFormat.yMMMd().format(_transactionsDateRange!.start)} - ${DateFormat.yMMMd().format(_transactionsDateRange!.end)}',
            ),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                initialDateRange: _transactionsDateRange,
              );
              if (picked != null) {
                setState(() => _transactionsDateRange = picked);
                _loadTransactionsReportData();
              }
            },
          ),
          ElevatedButton.icon(
            onPressed: () => _downloadGenericExcel(_transactionsReportData, 'Transactions_Report'),
            icon: const Icon(Icons.download),
            label: const Text('Export to Excel'),
          ),
          Expanded(
            child: _isTransactionsLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
              children: [
                DataTable(
                  columns: const [
                    DataColumn(label: Text('Date')),
                    DataColumn(label: Text('Account')),
                    DataColumn(label: Text('Description')),
                    DataColumn(label: Text('Type')),
                    DataColumn(label: Text('Amount')),
                  ],
                  rows: _transactionsReportData
                      .map((row) => DataRow(cells: [
                    DataCell(Text(row['DATE']?.toString() ?? '')),
                    DataCell(Text(row['ACCOUNT']?.toString() ?? '')),
                    DataCell(Text(row['DESCRIPTION']?.toString() ?? '')),
                    DataCell(Text(row['TYPE']?.toString() ?? '')),
                    DataCell(Text(row['AMOUNT']?.toString() ?? '')),
                  ]))
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffLeaveReportTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          DropdownButtonFormField<Staff>(
            value: _selectedStaff,
            hint: const Text('Select Staff'),
            items: _staffList.map((staff) => DropdownMenuItem(value: staff, child: Text(staff.name))).toList(),
            onChanged: (staff) {
              setState(() => _selectedStaff = staff);
              if (staff != null) _loadStaffLeaveReportData();
            },
          ),
          DropdownButtonFormField<String>(
            value: _selectedLeaveMonth,
            hint: const Text('Select Month'),
            items: List.generate(12, (i) {
              final date = DateTime(DateTime.now().year, DateTime.now().month - i, 1);
              return DateFormat('yyyy-MM').format(date);
            }).map((month) => DropdownMenuItem(value: month, child: Text(month))).toList(),
            onChanged: (month) {
              setState(() => _selectedLeaveMonth = month!);
              if (_selectedStaff != null) _loadStaffLeaveReportData();
            },
          ),
          ElevatedButton.icon(
            onPressed: () => _downloadGenericExcel(_staffLeaveReportData, 'Staff_Leave_Report'),
            icon: const Icon(Icons.download),
            label: const Text('Export to Excel'),
          ),
          Expanded(
            child: _isStaffLeaveLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
              children: [
                DataTable(
                  columns: const [
                    DataColumn(label: Text('Staff Name')),
                    DataColumn(label: Text('Leave Date')),
                    DataColumn(label: Text('Reason')),
                    DataColumn(label: Text('Status')),
                  ],
                  rows: _staffLeaveReportData
                      .map((row) => DataRow(cells: [
                    DataCell(Text(row['LEAVEDATE']?.toString() ?? '')),
                    DataCell(Text(row['STAFF']?.toString() ?? '')),
                    DataCell(Text(row['REASON']?.toString() ?? '')),
                    DataCell(
                      Text(
                        (row['APPROVED'] == 'YES')
                            ? 'Approved'
                            : (row['REJECTED'] == 'YES' ? 'Rejected' : 'Pending'),
                      ),
                    ),
                  ]))
                      .toList(),
                ),
              ],
            ),
          ),
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
          _selectedFeeClass = null;
          _feeReportData = [];
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

  DataCell _buildFeeDataCell(String text, {Color? color}) {
    return DataCell(
      Text(
        text,
        style: GoogleFonts.poppins(fontSize: 10, color: color),
        textAlign: TextAlign.center,
      ),
    );
  }

  DataCell _buildFeeStatusCell(String status) {
    return DataCell(
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: status == 'PAID' ? Colors.green : Colors.orange,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          status,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildFeeReportTable() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: DataTable(
            headingRowColor: MaterialStateProperty.all(const Color(0xFF800000)),
            headingRowHeight: 56,
            dataRowHeight: 80,
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
              DataColumn(
                label: Text(
                  'Gender',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              // Term 1 columns
              DataColumn(
                label: Text(
                  'T1 Fee',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              DataColumn(
                label: Text(
                  'T1 Paid',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              DataColumn(
                label: Text(
                  'T1 Due',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              // Term 2 columns
              DataColumn(
                label: Text(
                  'T2 Fee',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              DataColumn(
                label: Text(
                  'T2 Paid',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              DataColumn(
                label: Text(
                  'T2 Due',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              // Term 3 columns
              DataColumn(
                label: Text(
                  'T3 Fee',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              DataColumn(
                label: Text(
                  'T3 Paid',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              DataColumn(
                label: Text(
                  'T3 Due',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              DataColumn(
                label: Text(
                  'Bus\n(F/P/D)',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              DataColumn(
                label: Text(
                  'Books\n(F/P/D)',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              DataColumn(
                label: Text(
                  'Uniform\n(F/P/D)',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
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
              for (final data in _feeReportData)
                DataRow(
                  color: MaterialStateProperty.all(
                    data['Overall Status'] == 'PAID'
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
                        data['Gender'] ?? '',
                        style: GoogleFonts.poppins(),
                      ),
                    ),
                    // Term 1 data
                    _buildFeeDataCell('Rs.${(data['Term1 Fee'] ?? 0).toStringAsFixed(0)}'),
                    _buildFeeDataCell('Rs.${(data['Term1 Paid'] ?? 0).toStringAsFixed(0)}', color: Colors.green[700]),
                    _buildFeeDataCell(
                      'Rs.${(data['Term1 Due'] ?? 0).toStringAsFixed(0)}',
                      color: (data['Term1 Due'] as double? ?? 0) > 0 ? Colors.red[700] : Colors.green[700],
                    ),
                    // Term 2 data
                    _buildFeeDataCell('Rs.${(data['Term2 Fee'] ?? 0).toStringAsFixed(0)}'),
                    _buildFeeDataCell('Rs.${(data['Term2 Paid'] ?? 0).toStringAsFixed(0)}', color: Colors.green[700]),
                    _buildFeeDataCell(
                      'Rs.${(data['Term2 Due'] ?? 0).toStringAsFixed(0)}',
                      color: (data['Term2 Due'] as double? ?? 0) > 0 ? Colors.red[700] : Colors.green[700],
                    ),
                    // Term 3 data
                    _buildFeeDataCell('Rs.${(data['Term3 Fee'] ?? 0).toStringAsFixed(0)}'),
                    _buildFeeDataCell('Rs.${(data['Term3 Paid'] ?? 0).toStringAsFixed(0)}', color: Colors.green[700]),
                    _buildFeeDataCell(
                      'Rs.${(data['Term3 Due'] ?? 0).toStringAsFixed(0)}',
                      color: (data['Term3 Due'] as double? ?? 0) > 0 ? Colors.red[700] : Colors.green[700],
                    ),
                    _buildFeeDataCell(
                        'Rs.${(data['Bus Fee'] ?? 0).toStringAsFixed(0)}/Rs.${(data['Bus Fee Paid'] ?? 0).toStringAsFixed(0)}/Rs.${(data['Bus Fee Due'] ?? 0).toStringAsFixed(0)}'),
                    _buildFeeDataCell(
                        'Rs.${(data['Books Fee'] ?? 0).toStringAsFixed(0)}/Rs.${(data['Books Fee Paid'] ?? 0).toStringAsFixed(0)}/Rs.${(data['Books Fee Due'] ?? 0).toStringAsFixed(0)}'),
                    _buildFeeDataCell(
                        'Rs.${(data['Uniform Fee'] ?? 0).toStringAsFixed(0)}/Rs.${(data['Uniform Fee Paid'] ?? 0).toStringAsFixed(0)}/Rs.${(data['Uniform Fee Due'] ?? 0).toStringAsFixed(0)}'),
                    _buildFeeStatusCell(data['Overall Status'] ?? ''),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDailyReportTab() {
    double totalCredit = 0;
    double totalDebit = 0;
    for (var t in _dailyReportData) {
      final amt = double.tryParse(t['amount'].toString()) ?? 0.0;
      if (t['type'] == 'credit') totalCredit += amt;
      if (t['type'] == 'debit') totalDebit += amt;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                 Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDailyDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setState(() => _selectedDailyDate = picked);
                        _loadDailyReportData();
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.calendar_today_outlined, color: Color(0xFF800000), size: 24),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Reporting Date',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                            Text(
                              DateFormat('dd MMMM yyyy').format(_selectedDailyDate),
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _downloadDailyExcel,
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: Text('Export Excel', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          if (_isDailyLoading)
            const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
          else if (_dailyReportData.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40.0),
                child: Column(
                  children: [
                    Icon(Icons.receipt_long, size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text('No transactions found for this date', style: GoogleFonts.poppins(color: Colors.grey[500])),
                  ],
                ),
              ),
            )
          else ...[
            // Totals Summary
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryItem('Total Credit', totalCredit, const Color(0xFF10B981)),
                  _buildSummaryItem('Total Debit', totalDebit, const Color(0xFFF43F5E)),
                  _buildSummaryItem('Net Balance', totalCredit - totalDebit, const Color(0xFF800000)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Transactions Table
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 4)],
              ),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFF800000)),
                columns: [
                  DataColumn(label: Text('Description', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Category', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Credit', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Debit', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold))),
                ],
                rows: _dailyReportData.map((t) {
                  final isCredit = t['type'] == 'credit';
                  return DataRow(cells: [
                    DataCell(Text(t['description']?.toString() ?? '', style: const TextStyle(fontSize: 12))),
                    DataCell(Text(t['category']?.toString() ?? '', style: const TextStyle(fontSize: 12))),
                    DataCell(Text(isCredit ? 'Rs.${t['amount']}' : '-', style: TextStyle(color: isCredit ? Colors.green[700] : Colors.black))),
                    DataCell(Text(!isCredit ? 'Rs.${t['amount']}' : '-', style: TextStyle(color: !isCredit ? Colors.red[700] : Colors.black))),
                  ]);
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, double amount, Color color) {
    return Column(
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Rs.${amount.toStringAsFixed(2)}',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Future<void> _downloadDailyExcel() async {
     if (_dailyReportData.isEmpty) return;
     final excel = excel_pkg.Excel.createExcel();
     final sheet = excel['Daily Report'];
     
     sheet.appendRow(['Daily Transaction Report - ${DateFormat('dd-MM-yyyy').format(_selectedDailyDate)}']);
     sheet.appendRow([]);
     sheet.appendRow(['Description', 'Category', 'Subcategory', 'Type', 'Amount']);
     
     for (var t in _dailyReportData) {
       sheet.appendRow([
         t['description'],
         t['category'],
         t['subcategory'],
         t['type'].toString().toUpperCase(),
         t['amount']
       ]);
     }
     
     final bytes = excel.encode();
     if (bytes != null) {
       await _downloadFile(bytes, 'Daily_Report_${DateFormat('yyyyMMdd').format(_selectedDailyDate)}.xlsx');
     }
  }

  Future<void> _downloadBusDueExcel() async {
    if (_busDueReportData.isEmpty) return;
    final excel = excel_pkg.Excel.createExcel();
    final sheet = excel['Bus Due Report'];
    
    sheet.appendRow(['Bus Due Report - Bus No: $_selectedBusNumber']);
    sheet.appendRow([]);
    sheet.appendRow(['Student Name', 'Class', 'Route', 'Last Paid', 'Bus Total', 'Bus Paid', 'Bus Due', 'School Total', 'School Paid', 'School Due', 'Parent Mobile', 'Overall Fee', 'Overall Due']);
    
    for (var data in _busDueReportData) {
      sheet.appendRow([
        data['Student Name'],
        data['Class'],
        data['Route'],
        data['Last Paid Date'],
        data['Bus Total'],
        data['Bus Paid'],
        data['Bus Pending'],
        data['School Total'],
        data['School Paid'],
        data['School Pending'],
        data['Parent Mobile'],
        data['Overall Total'],
        data['Overall Due']
      ]);
    }
    
    final bytes = excel.encode();
    if (bytes != null) {
      await _downloadFile(bytes, 'Bus_Due_Report_${_selectedBusNumber}_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx');
    }
  }

  Widget _buildDueStatementTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Date',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDueStatementDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (picked != null) {
                setState(() {
                  _selectedDueStatementDate = picked;
                  _dueStatementReportData = [];
                });
                _loadDueStatementReportData();
              }
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, color: Color(0xFF800000)),
                  const SizedBox(width: 12),
                  Text(
                    DateFormat('dd MMMM yyyy').format(_selectedDueStatementDate),
                    style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (_isDueStatementLoading)
            const Center(child: CircularProgressIndicator())
          else if (_dueStatementReportData.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Consolidated Due Statement',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _downloadGenericExcel(_dueStatementReportData, 'Due_Statement'),
                  icon: const Icon(Icons.download),
                  label: const Text('Export Excel'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(const Color(0xFFF8FAFC)),
                  columns: [
                    DataColumn(label: Text('Category', style: GoogleFonts.poppins(fontWeight: FontWeight.w600))),
                    DataColumn(label: Text('Total Fee', style: GoogleFonts.poppins(fontWeight: FontWeight.w600))),
                    DataColumn(label: Text('Total Paid', style: GoogleFonts.poppins(fontWeight: FontWeight.w600))),
                    DataColumn(label: Text('Concession', style: GoogleFonts.poppins(fontWeight: FontWeight.w600))),
                    DataColumn(label: Text('Total Pending', style: GoogleFonts.poppins(fontWeight: FontWeight.w600))),
                  ],
                  rows: _dueStatementReportData.map((data) {
                    final isGrandTotal = data['Category'] == 'GRAND TOTAL';
                    return DataRow(
                      cells: [
                        DataCell(Text(
                          data['Category'].toString(),
                          style: GoogleFonts.inter(
                            fontWeight: isGrandTotal ? FontWeight.w700 : FontWeight.w500,
                            color: isGrandTotal ? const Color(0xFF800000) : const Color(0xFF475569),
                          ),
                        )),
                        DataCell(Text(
                          '₹${_formatAmount(data['Total Fee'] as double?)}',
                          style: GoogleFonts.inter(fontWeight: isGrandTotal ? FontWeight.bold : FontWeight.normal),
                        )),
                        DataCell(Text(
                          '₹${_formatAmount(data['Total Paid'] as double?)}',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF10B981),
                            fontWeight: isGrandTotal ? FontWeight.bold : FontWeight.normal,
                          ),
                        )),
                        DataCell(Text(
                          '₹${_formatAmount(data['Concession'] as double?)}',
                          style: GoogleFonts.inter(
                            color: Colors.orange[700],
                            fontWeight: isGrandTotal ? FontWeight.bold : FontWeight.normal,
                          ),
                        )),
                        DataCell(Text(
                          '₹${_formatAmount(data['Total Pending'] as double?)}',
                          style: GoogleFonts.inter(
                            color: const Color(0xFFEF4444),
                            fontWeight: isGrandTotal ? FontWeight.bold : FontWeight.normal,
                          ),
                        )),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ] else
            const Center(child: Text('Click Generate or select a date to view data')),
        ],
      ),
    );
  }

  String _formatAmount(double? amount) {
    if (amount == null) return '0.00';
    return amount.toStringAsFixed(2);
  }

  Widget _buildBusDueReportTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedBusNumber,
                    decoration: InputDecoration(
                      labelText: 'Select Bus Number',
                      labelStyle: GoogleFonts.poppins(fontSize: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.directions_bus, color: Color(0xFF800000)),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                    ),
                    items: _busNumbers.map((bus) => DropdownMenuItem(value: bus, child: Text(bus, style: GoogleFonts.poppins()))).toList(),
                    onChanged: (val) {
                      setState(() => _selectedBusNumber = val);
                      _loadBusDueReportData();
                    },
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _busDueReportData.isEmpty ? null : _downloadBusDueExcel,
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: Text('Export Excel', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (_isBusDueLoading)
            const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
          else if (_selectedBusNumber == null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40.0),
                child: Column(
                  children: [
                    Icon(Icons.directions_bus, size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text('Please select a bus to view the report', style: GoogleFonts.poppins(color: Colors.grey[500])),
                  ],
                ),
              ),
            )
          else if (_busDueReportData.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40.0),
                child: Column(
                  children: [
                    Icon(Icons.person_off, size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text('No students found for this bus', style: GoogleFonts.poppins(color: Colors.grey[500])),
                  ],
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(const Color(0xFF800000)),
                  headingTextStyle: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
                  dataTextStyle: GoogleFonts.inter(fontSize: 13),
                  columns: const [
                    DataColumn(label: Text('Student Name')),
                    DataColumn(label: Text('Class')),
                    DataColumn(label: Text('Route')),
                    DataColumn(label: Text('Last Paid')),
                    DataColumn(label: Text('Bus Total')),
                    DataColumn(label: Text('Bus Paid')),
                    DataColumn(label: Text('Bus Due')),
                    DataColumn(label: Text('School Total')),
                    DataColumn(label: Text('School Paid')),
                    DataColumn(label: Text('School Due')),
                    DataColumn(label: Text('Parent Mobile')),
                    DataColumn(label: Text('Overall Fee')),
                    DataColumn(label: Text('Overall Due')),
                  ],
                  rows: _busDueReportData.map((data) {
                    return DataRow(cells: [
                      DataCell(Text(data['Student Name'] ?? '')),
                      DataCell(Text(data['Class'] ?? '')),
                      DataCell(Text(data['Route'] ?? '')),
                      DataCell(Text(data['Last Paid Date'] ?? 'N/A')),
                      DataCell(Text('Rs.${data['Bus Total']}')),
                      DataCell(Text('Rs.${data['Bus Paid']}', style: const TextStyle(color: Colors.green))),
                      DataCell(Text('Rs.${data['Bus Pending']}', style: const TextStyle(color: Colors.red))),
                      DataCell(Text('Rs.${data['School Total']}')),
                      DataCell(Text('Rs.${data['School Paid']}', style: const TextStyle(color: Colors.green))),
                      DataCell(Text('Rs.${data['School Pending']}', style: const TextStyle(color: Colors.red))),
                      DataCell(Text(data['Parent Mobile'] ?? '')),
                      DataCell(Text('Rs.${data['Overall Total']}', style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text('Rs.${data['Overall Due']}', style: const TextStyle(color: Color(0xFF800000), fontWeight: FontWeight.bold))),
                    ]);
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }
  // #endregion

  Color _getTabColor(int index) {
    switch (index) {
      case 0:
        return const Color(0xFF800000);
      case 1:
        return Colors.orange[700]!;
      case 2:
        return Colors.purple[700]!;
      case 3:
        return const Color(0xFF800000);
      case 4:
        return Colors.red[700]!;
      case 5:
        return const Color(0xFF800000);
      default:
        return const Color(0xFF800000);
    }
  }
}

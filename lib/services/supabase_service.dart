import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:school_management/models/student.dart';
import 'package:school_management/models/performance.dart';
import 'package:school_management/models/staff.dart';

class SupabaseService {
  static const String supabaseUrl = 'https://mggcskkkricnmkjqdqai.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1nZ2Nza2trcmljbm1ranFkcWFpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjMxNjk4MjQsImV4cCI6MjA3ODc0NTgyNH0.Z74XcwusKBcVr82QWU5UxKBRgwyAILwKXiVgyTg5SaQ';

  static final SupabaseService _instance = SupabaseService._internal();

  factory SupabaseService() {
    return _instance;
  }

  SupabaseService._internal();

  static SupabaseClient get client => Supabase.instance.client;

  // Initialize Supabase
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }

  // Fetch all students
  static Future<List<Student>> getAllStudents() async {
    try {
      final response = await client.from('STUDENTS').select();
      final students = (response as List)
          .map((e) => Student.fromJson(e as Map<String, dynamic>))
          .toList();
      return students;
    } catch (e) {
      print('Error fetching all students: $e');
      return [];
    }
  }

  // Fetch all staff
  static Future<List<Staff>> getAllStaff() async {
    try {
      final response = await client.from('STAFF').select();
      final staffList = (response as List)
          .map((e) => Staff.fromJson(e as Map<String, dynamic>))
          .toList();
      return staffList;
    } catch (e) {
      print('Error fetching all staff: $e');
      return [];
    }
  }

  // Fetch students by parent mobile number
  static Future<List<Student>> getStudentsByParentMobile(
      String parentMobile) async {
    try {
      final response = await client
          .from('STUDENTS')
          .select()
          .eq('Parent Mobile', parentMobile);

      final students = (response as List)
          .map((e) => Student.fromJson(e as Map<String, dynamic>))
          .toList();
      return students;
    } catch (e) {
      print('Error fetching students by parent mobile: $e');
      return [];
    }
  }

  // Check if parent mobile exists
  static Future<bool> parentMobileExists(String parentMobile) async {
    try {
      final response = await client
          .from('STUDENTS')
          .select()
          .eq('Parent Mobile', parentMobile)
          .limit(1);

      return (response as List).isNotEmpty;
    } catch (e) {
      print('Error checking parent mobile: $e');
      return false;
    }
  }

  // Fetch unique classes from STUDENTS table
  static Future<List<String>> getUniqueClasses() async {
    try {
      final response = await client.from('STUDENTS').select('Class');
      final classes = <String>{};
      for (var item in response as List) {
        final className = item['Class'] as String?;
        if (className != null && className.isNotEmpty) {
          classes.add(className);
        }
      }
      return classes.toList()..sort();
    } catch (e) {
      print('Error fetching classes: $e');
      return [];
    }
  }

  // Fetch unique classes and sections from STUDENTS table
  static Future<Map<String, List<String>>> getUniqueClassesAndSections() async {
    try {
      final response = await client.from('STUDENTS').select('Class');
      final classSections = <String, Set<String>>{};
      for (var item in response as List) {
        final className = item['Class'] as String?;
        if (className != null && className.contains('-')) {
          final parts = className.split('-');
          final classPart = parts[0];
          final sectionPart = parts[1];
          if (classPart.isNotEmpty && sectionPart.isNotEmpty) {
            classSections.putIfAbsent(classPart, () => <String>{}).add(sectionPart);
          }
        }
      }
      // Convert the Set to a sorted List for consistent ordering
      return classSections.map((key, value) => MapEntry(key, value.toList()..sort()));
    } catch (e) {
      print('Error fetching classes and sections: $e');
      return {};
    }
  }

  // Fetch students by class
  static Future<List<Student>> getStudentsByClass(String className) async {
    try {
      final response = await client
          .from('STUDENTS')
          .select()
          .eq('Class', className);

      final students = (response as List)
          .map((e) => Student.fromJson(e as Map<String, dynamic>))
          .toList();
      return students;
    } catch (e) {
      print('Error fetching students by class: $e');
      return [];
    }
  }

  // Fetch students by class prefix (e.g., "V" to get "V-A", "V-B")
  static Future<List<Student>> getStudentsByClassPrefix(String classPrefix) async {
    try {
      final response = await client
          .from('STUDENTS')
          .select()
          .like('Class', '$classPrefix-%');

      final students = (response as List)
          .map((e) => Student.fromJson(e as Map<String, dynamic>))
          .toList();
      return students;
    } catch (e) {
      print('Error fetching students by class prefix: $e');
      return [];
    }
  }

  // Fetch students by class and parent mobile (for parent login)
  static Future<List<Student>> getStudentsByClassAndParentMobile(
      String className, String parentMobile) async {
    try {
      final response = await client
          .from('STUDENTS')
          .select()
          .eq('Class', className)
          .eq('Parent Mobile', parentMobile);

      final students = (response as List)
          .map((e) => Student.fromJson(e as Map<String, dynamic>))
          .toList();
      return students;
    } catch (e) {
      print('Error fetching students by class and parent mobile: $e');
      return [];
    }
  }

  // Fetch performance data for a specific student
  static Future<List<Performance>> getStudentPerformance(
      String studentName) async {
    try {
      final response = await client
          .from('PERFORMANCE')
          .select()
          .eq('Student Name', studentName);

      final performances = (response as List)
          .map((e) => Performance.fromJson(e as Map<String, dynamic>))
          .toList();
      return performances;
    } catch (e) {
      print('Error fetching student performance: $e');
      return [];
    }
  }

  // Fetch distinct Assessment values for a student
  static Future<List<String>> getAssessmentsForStudent(String studentName) async {
    try {
      final response = await client
          .from('PERFORMANCE')
          .select('Assessment')
          .eq('Student Name', studentName);

      final assessments = <String>{};
      for (var item in response as List) {
        final a = item['Assessment'] as String? ?? '';
        if (a.isNotEmpty) assessments.add(a);
      }
      final list = assessments.toList()..sort();
      return list;
    } catch (e) {
      print('Error fetching assessments: $e');
      return [];
    }
  }

  // Fetch performance records for a student filtered by Assessment
  // Returns full Performance objects; UI can show Subject and Grade
  static Future<List<Performance>> getStudentPerformanceByAssessment(
      String studentName, String assessment) async {
    try {
      final response = await client
          .from('PERFORMANCE')
          .select()
          .eq('Student Name', studentName)
          .eq('Assessment', assessment);

      final performances = (response as List)
          .map((e) => Performance.fromJson(e as Map<String, dynamic>))
          .toList();
      return performances;
    } catch (e) {
      print('Error fetching student performance by assessment: $e');
      return [];
    }
  }

  // Insert a new student into STUDENTS table
  static Future<bool> insertStudent(Map<String, dynamic> studentData) async {
    try {
      await client.from('STUDENTS').insert(studentData);
      return true;
    } catch (e) {
      print('Error inserting student: $e');
      return false;
    }
  }

  // Insert a performance record into PERFORMANCE table
  static Future<bool> insertPerformance(Map<String, dynamic> perfData) async {
    try {
      await client.from('PERFORMANCE').insert(perfData);
      return true;
    } catch (e) {
      print('Error inserting performance: $e');
      return false;
    }
  }


  // Validate admin credentials against CRED table
  static Future<bool> validateAdminCredentials(String username, String password) async {
    try {
      final response = await client
          .from('CRED')
          .select()
          .eq('USERNAME', username)
          .eq('PASSWORD', password)
          .limit(1);

      return (response as List).isNotEmpty;
    } catch (e) {
      print('Error validating admin credentials: $e');
      return false;
    }
  }

  // Insert a staff record into STAFF table
  static Future<bool> insertStaff(Map<String, dynamic> staffData) async {
    try {
      await client.from('STAFF').insert(staffData);
      return true;
    } catch (e) {
      print('Error inserting staff: $e');
      return false;
    }
  }

  // Insert a bus/transport record into TRANSPORT table
  static Future<bool> insertTransport(Map<String, dynamic> transportData) async {
    try {
      await client.from('TRANSPORT').insert(transportData);
      return true;
    } catch (e) {
      print('Error inserting transport: $e');
      return false;
    }
  }

  // Insert a fee record into FEES table
  // Expected keys: 'STUDENT NAME','TERM MONTH','TERM YEAR','FEE TYPE','AMOUNT','TERM NO'
  static Future<bool> insertFee(Map<String, dynamic> feeData) async {
    try {
      await client.from('FEES').insert(feeData);
      return true;
    } catch (e) {
      print('Error inserting fee: $e');
      return false;
    }
  }

  // Fetch fees for a specific student
  static Future<List<Map<String, dynamic>>> getFeesByStudent(String studentName) async {
    try {
      final response = await client
          .from('FEES')
          .select()
          .eq('STUDENT NAME', studentName);
      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error fetching fees for student: $e');
      return [];
    }
  }

  // Fetch fees for a list of students (optimized for reports)
  static Future<Map<String, List<Map<String, dynamic>>>> getFeesForStudents(List<String> studentNames) async {
    try {
      final response = await client
          .from('FEES')
          .select()
          .in_('STUDENT NAME', studentNames);
      
      final feesByStudent = <String, List<Map<String, dynamic>>>{};
      for (final fee in response as List) {
        final studentName = fee['STUDENT NAME'] as String;
        feesByStudent.putIfAbsent(studentName, () => []).add(fee as Map<String, dynamic>);
      }
      return feesByStudent;
    } catch (e) {
      print('Error fetching fees for students: $e');
      return {};
    }
  }

  // Fetch fees for all students in a class
  // Since FEES table stores student names, we fetch students by class then their fees
  static Future<Map<String, List<Map<String, dynamic>>>> getFeesByClass(String className) async {
    try {
      final students = await getStudentsByClass(className);
      final result = <String, List<Map<String, dynamic>>>{};
      for (final s in students) {
        final fees = await getFeesByStudent(s.name);
        result[s.name] = fees;
      }
      return result;
    } catch (e) {
      print('Error fetching fees by class: $e');
      return {};
    }
  }

  // Fetch fee structure for a class (CLASS and FEE columns)
  static Future<Map<String, dynamic>?> getFeeStructureByClass(String className) async {
    try {
      final response = await client
          .from('FEE STRUCTURE')
          .select()
          .eq('CLASS', className)
          .limit(1);
      if ((response as List).isNotEmpty) {
        return response[0] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Error fetching fee structure: $e');
      return null;
    }
  }

  // Calculate term fee amounts: Term 1 = 40%, Term 2 = 40%, Term 3 = 20%
  static Map<int, double> calculateTermFees(double totalFee, double concession) {
    final effectiveFee = (totalFee - concession).clamp(0, double.infinity);
    return {
      1: effectiveFee * 0.40,  // Term 1: 40%
      2: effectiveFee * 0.40,  // Term 2: 40%
      3: effectiveFee * 0.20,  // Term 3: 20%
    };
  }

  // Get which term corresponds to a given TERM MONTH
  static int? getTermNumberFromMonth(String termMonth) {
    switch (termMonth.toLowerCase()) {
      case 'june - september':
        return 1;
      case 'november - february':
        return 2;
      case 'march - june':
        return 3;
      default:
        return null;
    }
  }

  // Get term month string from term number
  static String getTermMonthFromNumber(int termNumber) {
    switch (termNumber) {
      case 1:
        return 'June - September';
      case 2:
        return 'November - February';
      case 3:
        return 'March - June';
      default:
        return '';
    }
  }

  // Calculate due amount for a student based on FEE TYPE and TERM NO
  // Logic: fetch student's existing FEES for the given FEE TYPE and TERM NO
  // Return (total term fee - already paid)
  static Future<Map<String, dynamic>> calculateStudentDue(
      String studentName,
      String feeType,
      int termNumber,
      double totalTermFee) async {
    try {
      final allFees = await getFeesByStudent(studentName);
      double paidAmount = 0;
      for (final fee in allFees) {
        final feeTypeDb = fee['FEE TYPE'] as String? ?? '';
        final termNoDb = fee['TERM NO'] as String? ?? '';
        
        // Check if fee type matches and term number is in TERM NO string
        if (feeTypeDb.contains(feeType) && termNoDb.contains('Term $termNumber')) {
          final amt = double.tryParse((fee['AMOUNT'] as dynamic).toString()) ?? 0;
          paidAmount += amt;
        }
      }
      final dueAmount = (totalTermFee - paidAmount).clamp(0, double.infinity);
      return {'paid': paidAmount, 'due': dueAmount, 'total': totalTermFee};
    } catch (e) {
      print('Error calculating due: $e');
      return {'paid': 0, 'due': totalTermFee, 'total': totalTermFee};
    }
  }

  // Calculate due amount for a student based on TERM MONTH/TERM YEAR (legacy support)
  // Logic: fetch student's existing FEES for the given TERM MONTH/TERM YEAR
  // Return (total term fee - already paid)
  static Future<Map<String, dynamic>> calculateStudentDueByMonth(
      String studentName,
      String termMonth,
      String termYear,
      double totalTermFee) async {
    try {
      final allFees = await getFeesByStudent(studentName);
      double paidAmount = 0;
      for (final fee in allFees) {
        final feeTermMonth = fee['TERM MONTH'] as String? ?? '';
        final feeTermYear = fee['TERM YEAR'] as String? ?? '';
        if (feeTermMonth == termMonth && feeTermYear == termYear) {
          final amt = double.tryParse((fee['AMOUNT'] as dynamic).toString()) ?? 0;
          paidAmount += amt;
        }
      }
      final dueAmount = (totalTermFee - paidAmount).clamp(0, double.infinity);
      return {'paid': paidAmount, 'due': dueAmount, 'total': totalTermFee};
    } catch (e) {
      print('Error calculating due: $e');
      return {'paid': 0, 'due': totalTermFee, 'total': totalTermFee};
    }
  }

  // Fetch bus fee from TRANSPORT table by route name
  static Future<double> getBusFeeByRoute(String routeName) async {
    try {
      final response = await client
          .from('TRANSPORT')
          .select('Fees')
          .eq('Route', routeName)
          .limit(1);
      
      if ((response as List).isNotEmpty) {
        final fee = double.tryParse((response[0]['Fees'] as dynamic).toString()) ?? 0;
        return fee;
      }
      return 0;
    } catch (e) {
      print('Error fetching bus fee: $e');
      return 0;
    }
  }

  // Fetch all unique routes from TRANSPORT table
  static Future<List<String>> getUniqueRoutes() async {
    try {
      final response = await client.from('TRANSPORT').select('Route');
      final routes = <String>{};
      for (var item in response as List) {
        final routeName = item['Route'] as String?;
        if (routeName != null && routeName.isNotEmpty) {
          routes.add(routeName);
        }
      }
      return routes.toList()..sort();
    } catch (e) {
      print('Error fetching routes: $e');
      return [];
    }
  }

  // Calculate due amount for a student's bus fee based on TERM YEAR
  // Logic: fetch student's existing BUS FEE for the given TERM YEAR
  // Return (bus fee - already paid)
  static Future<Map<String, dynamic>> calculateBusFeesDue(
      String studentName,
      String termYear,
      double totalBusFee) async {
    try {
      final allFees = await getFeesByStudent(studentName);
      double paidAmount = 0;
      for (final fee in allFees) {
        final feeTypeDb = fee['FEE TYPE'] as String? ?? '';
        final feeTermYear = fee['TERM YEAR'] as String? ?? '';
        
        // Check if fee type contains 'Bus' and year matches
        if (feeTypeDb.contains('Bus') && feeTermYear == termYear) {
          final amt = double.tryParse((fee['AMOUNT'] as dynamic).toString()) ?? 0;
          paidAmount += amt;
        }
      }
      final dueAmount = (totalBusFee - paidAmount).clamp(0, double.infinity);
      return {'paid': paidAmount, 'due': dueAmount, 'total': totalBusFee};
    } catch (e) {
      print('Error calculating bus fee due: $e');
      return {'paid': 0, 'due': totalBusFee, 'total': totalBusFee};
    }
  }

  // Get Bus Fee due for a student based on FEE TYPE = 'Bus Fee' and current TERM YEAR
  // Returns: {paid: <amount_paid>, due: <amount_due>, total: <total_fee>}
  static Future<Map<String, dynamic>> getBusFeeDueForCurrentYear(String studentName) async {
    try {
      final currentYear = DateTime.now().year.toString();
      final allFees = await getFeesByStudent(studentName);
      
      double paidAmount = 0;
      double totalBusFeeAmount = 0;
      
      for (final fee in allFees) {
        final feeType = (fee['FEE TYPE'] as String? ?? '').trim();
        final feeTermYear = (fee['TERM YEAR'] as String? ?? '').trim();
        
        // Check if FEE TYPE is exactly 'Bus Fee' and TERM YEAR matches current year
        if (feeType == 'Bus Fee' && feeTermYear == currentYear) {
          final amt = double.tryParse((fee['AMOUNT'] as dynamic).toString()) ?? 0;
          paidAmount += amt;
          // Assuming first entry has the total, or we accumulate if it's partial payments
          // In this case, each record is a payment record
        }
      }
      
      // If no records found, total bus fee is 0 (student hasn't been assigned a route)
      // Otherwise, we need to look up the route to get the actual fee
      // For now, we'll return paid and 0 total if no records exist
      final dueAmount = (totalBusFeeAmount - paidAmount).clamp(0, double.infinity);
      
      return {
        'paid': paidAmount,
        'due': dueAmount,
        'total': totalBusFeeAmount,
        'year': currentYear,
        'hasRecords': paidAmount > 0
      };
    } catch (e) {
      print('Error getting bus fee due for current year: $e');
      return {'paid': 0, 'due': 0, 'total': 0, 'year': DateTime.now().year.toString(), 'hasRecords': false};
    }
  }

  // Update student concession
  static Future<bool> updateStudentConcession(
    String studentName,
    double schoolFeeConcession,
    double tuitionFeeConcession,
  ) async {
    try {
      await client.from('STUDENTS').update({
        'School Fee Concession': schoolFeeConcession,
        'Tuition Fee Concession': tuitionFeeConcession,
      }).eq('Name', studentName);
      return true;
    } catch (e) {
      print('Error updating student concession: $e');
      return false;
    }
  }

  // Fetch student's bus route from STUDENTS table
  static Future<String?> getStudentRoute(String studentName) async {
    try {
      final response = await client
          .from('STUDENTS')
          .select('Route')
          .eq('Name', studentName)
          .limit(1);
      
      if ((response as List).isNotEmpty) {
        final route = response[0]['Route'] as String?;
        return route?.isEmpty == true ? null : route;
      }
      return null;
    } catch (e) {
      print('Error fetching student route: $e');
      return null;
    }
  }

  // Get bus fee for a student's route
  static Future<double> getStudentBusFee(String studentName) async {
    try {
      final route = await getStudentRoute(studentName);
      if (route == null || route.isEmpty) {
        return 0;
      }
      return await getBusFeeByRoute(route);
    } catch (e) {
      print('Error getting student bus fee: $e');
      return 0;
    }
  }

  // Get total bus fee paid by a student
  static Future<double> getBusFeePaid(String studentName) async {
    try {
      final fees = await getFeesByStudent(studentName);
      final busFeePayments = fees.where((f) => (f['FEE TYPE'] as String? ?? '').toLowerCase().contains('bus fee'));
      
      final totalPaid = busFeePayments.fold<double>(
        0, (sum, f) => sum + (double.tryParse((f['AMOUNT'] as dynamic).toString()) ?? 0));
      return totalPaid;
    } catch (e) {
      print('Error getting bus fee paid: $e');
      return 0;
    }
  }

  // Fetch books fee by class from BOOKS table
  static Future<double> getBooksFeeByClass(String className) async {
    try {
      final response = await client
          .from('BOOKS')
          .select('"BOOKS FEE"')
          .eq('CLASS', className)
          .limit(1);
      
      if ((response as List).isNotEmpty) {
        final fee = double.tryParse((response[0]['BOOKS FEE'] as dynamic).toString()) ?? 0;
        return fee;
      }
      return 0;
    } catch (e) {
      print('Error fetching books fee: $e');
      return 0;
    }
  }

  // Wrapper for getBusFeeByRoute (called as getBusFee in fees_tab)
  static Future<double> getBusFee(String routeName) async {
    return await getBusFeeByRoute(routeName);
  }

  // Wrapper for getFeeStructureByClass (called as getSchoolFeeStructure in fees_tab)
  static Future<Map<String, dynamic>> getSchoolFeeStructure(String className) async {
    try {
      final response = await client
          .from('FEE STRUCTURE')
          .select()
          .eq('CLASS', className)
          .limit(1);
      
      if ((response as List).isNotEmpty) {
        final feeData = response[0] as Map<String, dynamic>;
        final fee = double.tryParse((feeData['FEE'] as dynamic).toString()) ?? 0;
        return {'fee': fee, ...feeData};
      }
      return {'fee': 0};
    } catch (e) {
      print('Error fetching school fee structure: $e');
      return {'fee': 0};
    }
  }

  // Fetch uniform fee by class and gender from UNIFORM table
  static Future<double> getUniformFeeByClassAndGender(String className, String gender) async {
    try {
      final response = await client
          .from('UNIFORM')
          .select('"UNIFORM FEE"')
          .eq('CLASS', className)
          .eq('GENDER', gender)
          .limit(1);
      
      if ((response as List).isNotEmpty) {
        final fee = double.tryParse((response[0]['UNIFORM FEE'] as dynamic).toString()) ?? 0;
        return fee;
      }
      return 0;
    } catch (e) {
      print('Error fetching uniform fee: $e');
      return 0;
    }
  }

  // Fetch hostel fee by class from HOSTEL table
  static Future<double> getHostelFeeByClass(String className) async {
    try {
      final response = await client
          .from('HOSTEL')
          .select('"HOSTEL FEE"')
          .eq('CLASS', className)
          .limit(1);
      
      if ((response as List).isNotEmpty) {
        final fee = double.tryParse((response[0]['HOSTEL FEE'] as dynamic).toString()) ?? 0;
        return fee;
      }
      return 0;
    } catch (e) {
      print('Error fetching hostel fee: $e');
      return 0;
    }
  }

  // Update student books fee paid status
  static Future<bool> updateStudentBooksFeeStatus(String studentName, String status) async {
    try {
      await client.from('STUDENTS').update({
        'BOOKS FEE': status,
      }).eq('Name', studentName);
      return true;
    } catch (e) {
      print('Error updating books fee status: $e');
      return false;
    }
  }

  // Update student uniform fee paid status
  static Future<bool> updateStudentUniformFeeStatus(String studentName, String status) async {
    try {
      await client.from('STUDENTS').update({
        'UNIFORM FEE': status,
      }).eq('Name', studentName);
      return true;
    } catch (e) {
      print('Error updating uniform fee status: $e');
      return false;
    }
  }

  // Check student books fee paid status
  static Future<String> checkStudentBooksFeeStatus(String studentName) async {
    try {
      final response = await client
          .from('STUDENTS')
          .select('BOOKS FEE')
          .eq('Name', studentName)
          .limit(1);
      
      if ((response as List).isNotEmpty) {
        final status = response[0]['BOOKS FEE']?.toString() ?? 'UNPAID';
        return status;
      }
      return 'UNPAID';
    } catch (e) {
      print('Error checking books fee status: $e');
      return 'UNPAID';
    }
  }

  // Check student uniform fee paid status
  static Future<String> checkStudentUniformFeeStatus(String studentName) async {
    try {
      final response = await client
          .from('STUDENTS')
          .select('UNIFORM FEE')
          .eq('Name', studentName)
          .limit(1);
      
      if ((response as List).isNotEmpty) {
        final status = response[0]['UNIFORM FEE']?.toString() ?? 'UNPAID';
        return status;
      }
      return 'UNPAID';
    } catch (e) {
      print('Error checking uniform fee status: $e');
      return 'UNPAID';
    }
  }

  // Get all bus routes from TRANSPORT table
  static Future<List<String>> getBusRoutes() async {
    try {
      final response = await client
          .from('TRANSPORT')
          .select('Route')
          .neq('Route', null);
      
      final routes = <String>{};
      for (var item in response as List) {
        final route = item['Route']?.toString();
        if (route != null && route.isNotEmpty) {
          routes.add(route);
        }
      }
      return routes.toList();
    } catch (e) {
      print('Error fetching bus routes: $e');
      return [];
    }
  }

  // Get hostel fees by class from HOSTEL table
  static Future<Map<String, double>> getHostelFees() async {
    try {
      final response = await client
          .from('HOSTEL')
          .select('Class, Fee');
      
      final fees = <String, double>{};
      for (var item in response as List) {
        final className = item['Class']?.toString();
        final fee = item['Fee'];
        print('DEBUG: Hostel - Class: $className, Fee: $fee');
        if (className != null && fee != null) {
          fees[className] = (fee is int) ? fee.toDouble() : double.parse(fee.toString());
        }
      }
      print('DEBUG: Final hostel fees map: $fees');
      return fees;
    } catch (e) {
      print('Error fetching hostel fees: $e');
      return {};
    }
  }

  // Get unique classes from FEE_STRUCTURE table
  static Future<List<String>> getClassesFromFeeStructure() async {
    try {
      final response = await client
          .from('FEE STRUCTURE')
          .select('CLASS')
          .neq('CLASS', null);
      
      final classes = <String>{};
      for (var item in response as List) {
        final className = item['CLASS']?.toString();
        if (className != null && className.isNotEmpty) {
          classes.add(className);
        }
      }
      return classes.toList();
    } catch (e) {
      print('Error fetching classes from fee structure: $e');
      return [];
    }
  }

  // Get all transport data grouped by bus number
  static Future<Map<String, List<String>>> getAllTransportData() async {
    try {
      final response = await client
          .from('TRANSPORT')
          .select('BusNumber, Route')
          .neq('BusNumber', null);
      
      final busRoutes = <String, Set<String>>{};
      for (var item in response as List) {
        final busNumber = item['BusNumber']?.toString();
        final route = item['Route']?.toString();
        if (busNumber != null && busNumber.isNotEmpty && route != null && route.isNotEmpty) {
          if (!busRoutes.containsKey(busNumber)) {
            busRoutes[busNumber] = {};
          }
          busRoutes[busNumber]!.add(route);
        }
      }
      
      
      // Convert Set to List for each bus
      final result = <String, List<String>>{};
      busRoutes.forEach((bus, routes) {
        result[bus] = routes.toList();
      });
      
      return result;
    } catch (e) {
      print('Error fetching transport data: $e');
      return {};
    }
  }

  // Get bus numbers for a specific route
  static Future<List<String>> getBusNumbersByRoute(String route) async {
    try {
      final response = await client
          .from('TRANSPORT')
          .select('BusNumber')
          .eq('Route', route)
          .neq('BusNumber', null);
      
      final busNumbers = <String>{};
      for (var item in response as List) {
        final busNumber = item['BusNumber']?.toString();
        if (busNumber != null && busNumber.isNotEmpty) {
          busNumbers.add(busNumber);
        }
      }
      return busNumbers.toList();
    } catch (e) {
      print('Error fetching bus numbers for route: $e');
      return [];
    }
  }

  // Get all transport data grouped by bus registration with BusNumber as Route No
  static Future<Map<String, Map<String, dynamic>>> getAllTransportDataWithBusReg() async {
    try {
      final response = await client
          .from('TRANSPORT')
          .select('BusReg, BusNumber, Route')
          .neq('BusReg', null)
          .neq('BusNumber', null);
      
      final busData = <String, Map<String, dynamic>>{};
      for (var item in response as List) {
        final busReg = item['BusReg']?.toString();
        final busNumber = item['BusNumber']?.toString();
        final route = item['Route']?.toString();

        if (busReg != null && busReg.isNotEmpty && busNumber != null && busNumber.isNotEmpty) {
          if (!busData.containsKey(busReg)) {
            busData[busReg] = {
              'busNumber': busNumber,
              'routes': <String>{},
            };
          }
          if (route != null && route.isNotEmpty) {
            (busData[busReg]!['routes'] as Set<String>).add(route);
          }
        }
      }
      
      // Convert Set to List for each bus
      final result = <String, Map<String, dynamic>>{};
      busData.forEach((busReg, data) {
        result[busReg] = {
          'busNumber': data['busNumber'],
          'routes': (data['routes'] as Set<String>).toList(),
        };
      });
      
      return result;
    } catch (e) {
      print('Error fetching transport data with bus registration: $e');
      return {};
    }
  }

  // Get transport details with BusNumber and BusReg for diesel dropdown
  static Future<List<Map<String, dynamic>>> getTransportDetails() async {
    try {
      final response = await client.from('TRANSPORT').select();
      return (response as List).map((e) => e as Map<String, dynamic>).toList();
    } catch (e) {
      print('Error fetching transport details: $e');
      return [];
    }
  }

  // Get total diesel filled for a specific route number
  static Future<double> getDieselFilledForRoute(String routeNo) async {
    try {
      final response = await client
          .from('DIESEL')
          .select('FilledLitres')
          .eq('RouteNo', routeNo);

      double totalLitres = 0;
      for (var item in response as List) {
        final filledLitres = item['FilledLitres'];
        if (filledLitres != null) {
          totalLitres += double.tryParse(filledLitres.toString()) ?? 0.0;
        }
      }
      return totalLitres;
    } catch (e) {
      print('Error fetching diesel filled for route: $e');
      return 0;
    }
  }

  // Get BusReg for a specific route number
  static Future<String?> getTransportDataByRoute(String routeNo) async {
    try {
      final response = await client
          .from('TRANSPORT')
          .select('BusReg')
          .eq('BusNumber', routeNo)
          .limit(1);

      if ((response as List).isNotEmpty) {
        return response[0]['BusReg'] as String?;
      }
      return null;
    } catch (e) {
      print('Error fetching transport data by route: $e');
      return null;
    }
  }

  // Insert diesel data into DIESEL table
  static Future<bool> insertDieselData(Map<String, dynamic> dieselData) async {
    try {
      await client.from('DIESEL').insert(dieselData);
      return true;
    } catch (e) {
      print('Error inserting diesel data: $e');
      rethrow;
    }
  }

  // Get diesel data by date
  static Future<List<Map<String, dynamic>>> getDieselDataByDate(
      DateTime date) async {
    try {
      final dateStr = date.toIso8601String().split('T')[0];
      final response = await client
          .from('DIESEL')
          .select()
          .eq('FilledDate', dateStr)
          .order('FilledDate', ascending: false);

      return (response as List)
          .map((e) => e as Map<String, dynamic>)
          .toList();
    } catch (e) {
      print('Error fetching diesel data by date: $e');
      return [];
    }
  }

  // Get diesel data for a specific route number on a specific date
  static Future<Map<String, dynamic>?> getDieselDataForRouteByDate(
      String routeNo, DateTime date) async {
    try {
      final dateStr = date.toIso8601String().split('T')[0];
      final response = await client
          .from('DIESEL')
          .select('FilledLitres, FilledDate')
          .eq('RouteNo', routeNo)
          .eq('FilledDate', dateStr);

      if ((response as List).isEmpty) {
        return null;
      }

      double totalLitres = 0;
      for (var item in response as List) {
        final filledLitres = item['FilledLitres'];
        if (filledLitres != null) {
          totalLitres += double.tryParse(filledLitres.toString()) ?? 0.0;
        }
      }

      return {
        'FilledLitres': totalLitres,
        'FilledDate': dateStr,
      };
    } catch (e) {
      print('Error fetching diesel data for route by date: $e');
      return null;
    }
  }

  // Staff Authentication - Verify staff credentials from CRED table
  static Future<Map<String, dynamic>?> staffLogin(String username, String password) async {
    try {
      final response = await client
          .from('CRED')
          .select()
          .eq('USERNAME', username)
          .eq('PASSWORD', password)
          .eq('ROLE', 'STAFF')
          .limit(1);

      if ((response as List).isNotEmpty) {
        return response[0] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Error during staff login: $e');
      return null;
    }
  }

  // Get staff details by mobile number
  static Future<Map<String, dynamic>?> getStaffByMobile(String mobile) async {
    try {
      final response = await client
          .from('STAFF')
          .select()
          .eq('Mobile', mobile)
          .limit(1);

      if ((response as List).isNotEmpty) {
        return response[0] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Error fetching staff details: $e');
      return null;
    }
  }

  // Get all leaves for a staff for a specific month
  static Future<List<Map<String, dynamic>>> getLeavesForStaffForMonth(String staffName, String monthYear) async {
    try {
      final response = await client
          .from('STAFFLEAVE')
          .select()
          .eq('STAFF', staffName)
          .order('LEAVEDATE', ascending: false);

      final leaves = (response as List).cast<Map<String, dynamic>>();
      
      // Filter by month
      return leaves.where((leave) {
        final leaveDate = leave['LEAVEDATE']?.toString() ?? '';
        final parts = leaveDate.split('-');
        if (parts.length >= 2) {
          final leaveMonth = '${parts[2]}-${parts[1]}'; // YYYY-MM format
          return leaveMonth == monthYear;
        }
        return false;
      }).toList();
    } catch (e) {
      print('Error fetching leaves for month: $e');
      return [];
    }
  }

  // Get approved leaves for a staff for a specific month
  static Future<List<Map<String, dynamic>>> getApprovedLeavesForMonth(String staffName, String monthYear) async {
    try {
      final response = await client
          .from('STAFFLEAVE')
          .select()
          .eq('STAFF', staffName)
          .eq('APPROVED', 'YES')
          .order('LEAVEDATE', ascending: false);

      final leaves = (response as List).cast<Map<String, dynamic>>();
      
      // Filter by month
      return leaves.where((leave) {
        final leaveDate = leave['LEAVEDATE']?.toString() ?? '';
        final parts = leaveDate.split('-');
        if (parts.length >= 2) {
          final leaveMonth = '${parts[2]}-${parts[1]}'; // YYYY-MM format
          return leaveMonth == monthYear;
        }
        return false;
      }).toList();
    } catch (e) {
      print('Error fetching approved leaves: $e');
      return [];
    }
  }

  // Apply for leave - Insert into STAFFLEAVE table
  static Future<bool> applyForLeave(Map<String, dynamic> leaveData) async {
    try {
      // Add default values for LEAVEAPPLIED and APPROVED
      final dataToInsert = {
        ...leaveData,
        'LEAVEAPPLIED': 'YES',
        'APPROVED': 'NO',
      };
      await client.from('STAFFLEAVE').insert(dataToInsert);
      return true;
    } catch (e) {
      print('Error applying for leave: $e');
      return false;
    }
  }

  // Get pending leave requests (unapproved) for admin
  static Future<List<Map<String, dynamic>>> getPendingLeaveRequests() async {
    try {
      final response = await client
          .from('STAFFLEAVE')
          .select()
          .eq('LEAVEAPPLIED', 'YES')
          .eq('APPROVED', 'NO')
          .neq('REJECTED', 'YES')
          .order('LEAVEDATE', ascending: false);

      return (response as List).map((e) => e as Map<String, dynamic>).toList();
    } catch (e) {
      print('Error fetching pending leave requests: $e');
      return [];
    }
  }

  // Approve leave request - Update APPROVED to YES
  static Future<bool> approveLeave(int id) async {
    try {
      await client
          .from('STAFFLEAVE')
          .update({'APPROVED': 'YES'})
          .eq('id', id);
      return true;
    } catch (e) {
      print('Error approving leave: $e');
      return false;
    }
  }

  // Reject leave request - Update APPROVED to NO and REJECTED to YES
  static Future<bool> rejectLeave(int id) async {
    try {
      await client
          .from('STAFFLEAVE')
          .update({'APPROVED': 'NO', 'REJECTED': 'YES'})
          .eq('id', id);
      return true;
    } catch (e) {
      print('Error rejecting leave: $e');
      return false;
    }
  }

  // Get completed leaves with optional filters
  static Future<List<Map<String, dynamic>>> getCompletedLeaves({
    required String monthYear,
    String? staffName,
    String status = 'All',
  }) async {
    try {
      var query = client.from('STAFFLEAVE').select().or('APPROVED.eq.YES,REJECTED.eq.YES');

      if (staffName != null && staffName.isNotEmpty) {
        query = query.eq('STAFF', staffName);
      }

      if (status != 'All') {
        if (status == 'Approved') {
          query = query.eq('APPROVED', 'YES');
        } else if (status == 'Rejected') {
          query = query.eq('REJECTED', 'YES');
        }
      }

      final response = await query.order('LEAVEDATE', ascending: false);

      final leaves = (response as List).cast<Map<String, dynamic>>();

      // Filter by month
      return leaves.where((leave) {
        final leaveDate = leave['LEAVEDATE']?.toString() ?? '';
        final parts = leaveDate.split('-');
        if (parts.length >= 2) {
          final leaveMonth = '${parts[2]}-${parts[1]}'; // YYYY-MM format
          return leaveMonth == monthYear;
        }
        return false;
      }).toList();
    } catch (e) {
      print('Error fetching completed leaves: $e');
      return [];
    }
  }

  // Get completed leaves for a specific month
  @Deprecated('Use getCompletedLeaves instead')
  static Future<List<Map<String, dynamic>>> getCompletedLeavesForMonth(String monthYear) async {
    try {
      final response = await client
          .from('STAFFLEAVE')
          .select()
          .or('APPROVED.eq.YES,REJECTED.eq.YES')
          .order('LEAVEDATE', ascending: false);

      final leaves = (response as List).cast<Map<String, dynamic>>();
      
      // Filter by month
      return leaves.where((leave) {
        final leaveDate = leave['LEAVEDATE']?.toString() ?? '';
        final parts = leaveDate.split('-');
        if (parts.length >= 2) {
          final leaveMonth = '${parts[2]}-${parts[1]}'; // YYYY-MM format
          return leaveMonth == monthYear;
        }
        return false;
      }).toList();
    } catch (e) {
      print('Error fetching completed leaves for month: $e');
      return [];
    }
  }

  // Calculate leave count for a staff member in a given month
  static Future<int> calculateLeaveCount(String staffName, String monthYear) async {
    try {
      // monthYear format: "MM-YYYY"
      final response = await client
          .from('STAFFLEAVE')
          .select()
          .eq('STAFF', staffName)
          .eq('APPROVED', 'YES');

      if (response.isEmpty) {
        return 0;
      }

      // Filter by month
      int leaveCount = 0;
      for (var leave in response) {
        String leaveDate = leave['LEAVEDATE'] ?? '';
        // leaveDate format: "dd-mm-yyyy"
        if (leaveDate.isNotEmpty) {
          final parts = leaveDate.split('-');
          if (parts.length == 3) {
            final leaveDateMonth = parts[1]; // mm
            final leaveDateYear = parts[2]; // yyyy
            final compareDate = '$leaveDateMonth-$leaveDateYear';
            if (compareDate == monthYear) {
              leaveCount++;
            }
          }
        }
      }
      return leaveCount;
    } catch (e) {
      print('Error calculating leave count: $e');
      return 0;
    }
  }

  // Get salary for a staff member
  static Future<double> getStaffSalary(String staffName) async {
    try {
      final response = await client
          .from('STAFF')
          .select('Salary')
          .eq('Name', staffName)
          .single();
      
      final salaryValue = response['Salary'];
      if (salaryValue == null) return 0.0;
      
      // Handle both numeric and string types
      if (salaryValue is num) {
        return salaryValue.toDouble();
      } else if (salaryValue is String) {
        return double.tryParse(salaryValue) ?? 0.0;
      }
      return 0.0;
    } catch (e) {
      print('Error fetching staff salary: $e');
      return 0.0;
    }
  }

  // Generate pay slip for a staff member
  static Future<Map<String, dynamic>> generatePaySlip({
    required String staffName,
    required int workingDays,
    required String monthYear, // "MM-YYYY"
  }) async {
    try {
      // Calculate leave count
      int leaveCount = await calculateLeaveCount(staffName, monthYear);
      
      // Get salary
      double salary = await getStaffSalary(staffName);

      // Calculate: workingDays - leaveCount + 1
          int payableDays = leaveCount > 0
              ? (workingDays - leaveCount + 1)
              : (workingDays - leaveCount);
          if (payableDays < 0) payableDays = 0;
      // Calculate monthly salary: (salary / workingDays) * payableDays
      double dailyRate = workingDays > 0 ? salary / workingDays : 0;
      double monthlySalary = dailyRate * payableDays;

      // Convert all values to strings since PAYSLIP table uses TEXT columns
      return {
        'STAFF': staffName,
        'MONTH': monthYear,
        'WORKING_DAYS': workingDays.toString(),
        'LEAVE_COUNT': leaveCount.toString(),
        'PAYABLE_DAYS': payableDays.toString(),
        'SALARY': salary.toStringAsFixed(2),
        'DAILY_RATE': dailyRate.toStringAsFixed(2),
        'MONTHLY_SALARY': monthlySalary.toStringAsFixed(2),
        'DATE_GENERATED': DateTime.now().toString(),
      };
    } catch (e) {
      print('Error generating pay slip: $e');
      return {};
    }
  }

  // Get all staff for pay slip generation
  static Future<List<Map<String, dynamic>>> getAllStaffForPaySlips() async {
    try {
      final response = await client.from('STAFF').select('Name, Salary');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching staff for pay slips: $e');
      return [];
    }
  }

  // Save pay slip to database
  static Future<bool> savePaySlip(Map<String, dynamic> paySlipData) async {
    try {
      final dataToInsert = Map<String, dynamic>.from(paySlipData);
      if (dataToInsert['DATE_GENERATED'] is String) {
        dataToInsert.remove('DATE_GENERATED');
      }

      final staffName = dataToInsert['STAFF'] as String;
      final month = dataToInsert['MONTH'] as String;

      final existingPaySlip = await getPaySlipByStaffAndMonth(staffName, month);

      if (existingPaySlip != null) {
        await client
            .from('PAYSLIP')
            .update(dataToInsert)
            .eq('STAFF', staffName)
            .eq('MONTH', month);
      } else {
        await client.from('PAYSLIP').insert(dataToInsert);
      }
      return true;
    } catch (e) {
      print('Error saving pay slip: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getPaySlipByStaffAndMonth(
      String staffName, String month) async {
    try {
      final response = await client
          .from('PAYSLIP')
          .select()
          .eq('STAFF', staffName)
          .eq('MONTH', month)
          .limit(1);

      if (response.isNotEmpty) {
        return response.first as Map<String, dynamic>;
      } else {
        return null;
      }
    } catch (e) {
      print('Error fetching pay slip by staff and month: $e');
      return null;
    }
  }

  // Get pay slips for a specific month
  static Future<List<Map<String, dynamic>>> getPaySlipsForMonth(String monthYear) async {
    try {
      final response = await client
          .from('PAYSLIP')
          .select()
          .eq('MONTH', monthYear)
          .order('STAFF', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching pay slips: $e');
      return [];
    }
  }

  // Get pay slips for a specific staff member
  static Future<List<Map<String, dynamic>>> getPaySlipsForStaff(String staffName) async {
    try {
      final response = await client
          .from('PAYSLIP')
          .select()
          .eq('STAFF', staffName)
          .order('MONTH', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching staff pay slips: $e');
      return [];
    }
  }

  // Get single pay slip by ID
  static Future<Map<String, dynamic>?> getPaySlipById(int id) async {
    try {
      final response = await client
          .from('PAYSLIP')
          .select()
          .eq('id', id)
          .single();
      return response;
    } catch (e) {
      print('Error fetching pay slip: $e');
      return null;
    }
  }

  // Get all accounts from ACCOUNTS table
  static Future<List<String>> getAccounts() async {
    try {
      final response = await client.from('ACCOUNTS').select('ACCOUNT');
      final accounts = <String>{};
      for (var item in response as List) {
        final accountName = item['ACCOUNT'] as String?;
        if (accountName != null && accountName.isNotEmpty) {
          accounts.add(accountName);
        }
      }
      return accounts.toList()..sort();
    } catch (e) {
      print('Error fetching accounts: $e');
      return [];
    }
  }

  // Get transactions with optional filters
  static Future<List<Map<String, dynamic>>> getTransactions({
    String? account,
    DateTime? date,
  }) async {
    try {
      var query = client.from('TRANSACTIONS').select();

      // Fetch all transactions
      final response = await query.order('DATE', ascending: false);
      final transactions = (response as List).map((e) => e as Map<String, dynamic>).toList();

      final dateFormat = DateFormat('dd-MM-yyyy');
      final isoFormat = DateFormat('yyyy-MM-dd');

      // Sanitize dates first
      for (var transaction in transactions) {
        if (transaction['DATE'] is String) {
          final dateString = transaction['DATE'] as String;
          var parsedDate = dateFormat.tryParse(dateString);
          parsedDate ??= isoFormat.tryParse(dateString);

          if (parsedDate != null) {
            transaction['DATE'] = dateFormat.format(parsedDate);
          }
        }
      }

      // Now filter
      return transactions.where((t) {
        bool accountMatch = true;
        if (account != null && account.isNotEmpty) {
          accountMatch = t['ACCOUNT'] == account;
        }

        bool dateMatch = true;
        if (date != null) {
          final dateString = t['DATE'] as String?;
          if (dateString == null) {
            dateMatch = false;
          } else {
            dateMatch = dateString == dateFormat.format(date);
          }
        }
        
        return accountMatch && dateMatch;
      }).toList();

    } catch (e) {
      print('Error fetching transactions: $e');
      return [];
    }
  }

  // Add a new transaction
  static Future<bool> addTransaction(Map<String, dynamic> transactionData) async {
    try {
      // Ensure the date is correctly formatted before insertion.
      final dataToInsert = Map<String, dynamic>.from(transactionData);
      if (dataToInsert.containsKey('DATE')) {
        final dateValue = dataToInsert['DATE'];
        if (dateValue is DateTime) {
          dataToInsert['DATE'] = DateFormat('dd-MM-yyyy').format(dateValue);
        } else if (dateValue is String && dateValue.isNotEmpty) {
            var parsedDate = DateFormat('dd-MM-yyyy').tryParse(dateValue);
            parsedDate ??= DateFormat('yyyy-MM-dd').tryParse(dateValue);
            
            if (parsedDate != null) {
              dataToInsert['DATE'] = DateFormat('dd-MM-yyyy').format(parsedDate);
            } else {
              print('Warning: Unrecognized date format string in addTransaction: "$dateValue". Inserting as is.');
            }
        }
      }

      await client.from('TRANSACTIONS').insert(dataToInsert);
      return true;
    } catch (e) {
      print('Error adding transaction: $e');
      return false;
    }
  }

  // Get transactions from FEES and DIESEL tables by date
  static Future<List<Map<String, dynamic>>> getTransactionsByDate(DateTime date) async {
    final formattedDate = DateFormat('dd-MM-yyyy').format(date);
    final isoDate = DateFormat('yyyy-MM-dd').format(date);
    final transactions = <Map<String, dynamic>>[];

    try {
      // Fetch from FEES table
      final feesResponse = await client
          .from('FEES')
          .select('"STUDENT NAME", AMOUNT')
          .eq('DATE', formattedDate);

      for (final fee in feesResponse) {
        transactions.add({
          'description': 'Fee from ${fee['STUDENT NAME']}',
          'amount': double.tryParse(fee['AMOUNT'].toString()) ?? 0.0,
          'type': 'credit',
        });
      }

      // Fetch from DIESEL table
      final dieselResponse = await client
          .from('DIESEL')
          .select('RouteNo, Amount')
          .eq('FilledDate', isoDate);

      for (final diesel in dieselResponse) {
        transactions.add({
          'description': 'Diesel for Route ${diesel['RouteNo']}',
          'amount': double.tryParse(diesel['Amount'].toString()) ?? 0.0,
          'type': 'debit',
        });
      }

      // Fetch from TRANSACTIONS table
      final generalTransactionsResponse = await client
          .from('TRANSACTIONS')
          .select('ACCOUNT, AMOUNT, TYPE, DATE');

      // Client-side filtering to handle multiple date formats ('dd-MM-yyyy' and 'yyyy-MM-dd')
      final filteredGeneralTransactions = generalTransactionsResponse.where((t) {
        final dateString = t['DATE'] as String?;
        if (dateString == null) return false;

        try {
          // Try parsing as 'dd-MM-yyyy'
          final parsedDate1 = DateFormat('dd-MM-yyyy').parse(dateString);
          if (parsedDate1.year == date.year && parsedDate1.month == date.month && parsedDate1.day == date.day) return true;
        } catch (_) {}

        try {
          // Try parsing as 'yyyy-MM-dd'
          final parsedDate2 = DateFormat('yyyy-MM-dd').parse(dateString);
          if (parsedDate2.year == date.year && parsedDate2.month == date.month && parsedDate2.day == date.day) return true;
        } catch (_) {}

        return false;
      }).toList();

      for (final transaction in filteredGeneralTransactions) {
        final type = (transaction['TYPE'] as String? ?? '').toLowerCase();
        if (type == 'credit' || type == 'debit') {
          transactions.add({
            'description': transaction['ACCOUNT'] ?? 'N/A',
            'amount': double.tryParse(transaction['AMOUNT'].toString()) ?? 0.0,
            'type': type,
          });
        }
      }

      return transactions;
    } catch (e) {
      print('Error fetching transactions by date: $e');
      return [];
    }
  }

  // Save closing balance to CB table
  static Future<bool> saveClosingBalance(DateTime date, double amount) async {
    final formattedDate = DateFormat('dd-MM-yyyy').format(date);
    try {
      // Check if a record for the date already exists
      final existing = await client.from('CB').select().eq('DATE', formattedDate).limit(1);

      if (existing.isNotEmpty) {
        // Update existing record
        await client.from('CB').update({'AMOUNT': amount}).eq('DATE', formattedDate);
      } else {
        // Insert new record
        await client.from('CB').insert({'DATE': formattedDate, 'AMOUNT': amount});
      }
      return true;
    } catch (e) {
      print('Error saving closing balance: $e');
      return false;
    }
  }

  // Get closing balance for a specific date from CB table
  static Future<double> getClosingBalanceForDate(DateTime date) async {
    final formattedDate = DateFormat('dd-MM-yyyy').format(date);
    try {
      final response = await client
          .from('CB')
          .select('AMOUNT')
          .eq('DATE', formattedDate)
          .limit(1);

      if (response.isNotEmpty) {
        return double.tryParse(response.first['AMOUNT'].toString()) ?? 0.0;
      }
      return 0.0;
    } catch (e) {
      print('Error fetching closing balance for date: $e');
      return 0.0;
    }
  }

  // Get diesel data for report within a date range
  static Future<List<Map<String, dynamic>>> getDieselDataForReport(DateTime startDate, DateTime endDate) async {
    final formattedStartDate = DateFormat('yyyy-MM-dd').format(startDate);
    final formattedEndDate = DateFormat('yyyy-MM-dd').format(endDate);
    try {
      final response = await client
          .from('DIESEL')
          .select('FilledDate, RouteNo, FilledLitres, Amount')
          .gte('FilledDate', formattedStartDate)
          .lte('FilledDate', formattedEndDate)
          .order('FilledDate', ascending: false);
      print(response);
      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error fetching diesel report data: $e');
      return [];
    }
  }

  // Get transactions for report within a date range
  static Future<List<Map<String, dynamic>>> getTransactionsForReport(DateTime startDate, DateTime endDate) async {
    try {
      // Fetch all records and filter in Dart, as the DATE column is text.
      // This is reliable for mixed or inconsistent text date formats.
      final response = await client
          .from('TRANSACTIONS')
          .select('DATE, ACCOUNT, COMMENT, TYPE, AMOUNT')
          .order('DATE', ascending: false);

      final transactions = (response as List).cast<Map<String, dynamic>>();
      final dateFormat = DateFormat('dd-MM-yyyy');

      // Normalize start and end dates to ignore time component
      final normalizedStartDate = DateTime(startDate.year, startDate.month, startDate.day);
      final normalizedEndDate = DateTime(endDate.year, endDate.month, endDate.day);

      return transactions.where((t) {
        if (t['DATE'] is! String) {
          return false;
        }
        final dateString = t['DATE'] as String;
        var dateFormat = DateFormat('dd-MM-yyyy');
        var transactionDate = dateFormat.tryParse(dateString);
        
        if (transactionDate == null) {
          dateFormat = DateFormat('yyyy-MM-dd');
          transactionDate = dateFormat.tryParse(dateString);
        }

        if (transactionDate == null) {
          return false;
        }
        return !transactionDate.isBefore(normalizedStartDate) && !transactionDate.isAfter(normalizedEndDate);
      }).toList();
    } catch (e) {
      print('Error fetching transactions report data: $e');
      return [];
    }
  }

  // Get staff leave data for report with filters
  static Future<List<Map<String, dynamic>>> getStaffLeaveForReport({
    required String staffName,
    required String monthYear, // Format: "yyyy-MM"
  }) async {
    try {
      // The monthYear is in "yyyy-MM" format. We need to convert it to "-MM-yyyy"
      // to match the LEAVEDATE format "dd-MM-yyyy".
      final parts = monthYear.split('-');
      final year = parts[0];
      final month = parts[1];
      final pattern = '%-$month-$year';

      final response = await client
          .from('STAFFLEAVE')
          .select('STAFF, LEAVEDATE, REASON, APPROVED, REJECTED')
          .eq('STAFF', staffName)
          .like('LEAVEDATE', pattern)
          .order('LEAVEDATE', ascending: false);
      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error fetching staff leave report data: $e');
      return [];
    }
  
  }

  // Send SMS via a gateway
  static Future<bool> sendSms(String mobileNumber, String message) async {
    // IMPORTANT: Replace this with your actual SMS gateway API URL and parameters.
    // This is a placeholder example.
    const String smsGatewayUrl = "YOUR_SMS_GATEWAY_URL_HERE";
    final Uri uri = Uri.parse(smsGatewayUrl).replace(queryParameters: {
      'apikey': 'YOUR_API_KEY', // Replace with your API key
      'sender': 'NALANDA', // Replace with your Sender ID
      'numbers': mobileNumber,
      'message': message,
    });

    try {
      // final response = await http.get(uri);
      // return response.statusCode == 200;
      print('SMS to $mobileNumber: "$message"'); // For testing without a real gateway
      return true; // Assume success for now
    } catch (e) {
      print('Error sending SMS: $e');
      return false;
    }
  }
}

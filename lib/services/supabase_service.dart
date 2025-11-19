import 'package:supabase_flutter/supabase_flutter.dart';
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
}




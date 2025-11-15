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
}

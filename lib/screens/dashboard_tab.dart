import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:school_management/services/supabase_service.dart';
import 'package:school_management/models/student.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  late Future<List<Student>> _allStudentsFuture;
  late Future<Map<String, int>> _classCountsFuture;
  late Future<Map<String, int>> _genderCountsFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _allStudentsFuture = SupabaseService.getAllStudents();
    _genderCountsFuture = _allStudentsFuture.then((students) {
      int boys = 0;
      int girls = 0;
      for (var s in students) {
        if (s.gender?.toUpperCase() == 'M' || s.gender?.toUpperCase() == 'MALE') {
          boys++;
        } else if (s.gender?.toUpperCase() == 'F' || s.gender?.toUpperCase() == 'FEMALE') {
          girls++;
        }
      }
      return {'Boys': boys, 'Girls': girls};
    });
    
    _classCountsFuture = _allStudentsFuture.then((students) {
      final Map<String, int> counts = {};
      for (var student in students) {
        String className = student.className;
        counts[className] = (counts[className] ?? 0) + 1;
      }
      return counts;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: FutureBuilder<List<dynamic>>(
        future: Future.wait([_allStudentsFuture, _genderCountsFuture, _classCountsFuture]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF800000)));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final List<Student> students = snapshot.data![0] as List<Student>;
          final Map<String, int> genderCounts = snapshot.data![1] as Map<String, int>;
          final Map<String, int> classCounts = snapshot.data![2] as Map<String, int>;

          // Sort classes
          final sortedClasses = SupabaseService.sortClassList(classCounts.keys.toList());
          final sortedClassCounts = {
            for (var c in sortedClasses) c: classCounts[c]!
          };

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 32),
                _buildSummaryCards(students.length, genderCounts),
                const SizedBox(height: 32),
                _buildClassStrengthTable(sortedClassCounts),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'School Dashboard',
          style: GoogleFonts.poppins(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
        Text(
          'Overview of school statistics and strength',
          style: GoogleFonts.inter(
            fontSize: 16,
            color: const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCards(int total, Map<String, int> gender) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double width = (constraints.maxWidth - 48) / 3;
        if (width < 200) width = constraints.maxWidth;

        return Wrap(
          spacing: 24,
          runSpacing: 24,
          children: [
            _buildStatCard(
              'Total Students',
              total.toString(),
              Icons.people_alt_rounded,
              const Color(0xFF800000),
              width,
            ),
            _buildStatCard(
              'Boys',
              gender['Boys'].toString(),
              Icons.male_rounded,
              const Color(0xFF3B82F6),
              width,
            ),
            _buildStatCard(
              'Girls',
              gender['Girls'].toString(),
              Icons.female_rounded,
              const Color(0xFFEC4899),
              width,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassStrengthTable(Map<String, int> classCounts) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded, color: Color(0xFF800000)),
              const SizedBox(width: 12),
              Text(
                'Class-wise Strength',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(const Color(0xFFF8FAFC)),
              columns: [
                DataColumn(
                  label: Text(
                    'Class & Section',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Strength',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
              rows: classCounts.entries.map((entry) {
                return DataRow(cells: [
                  DataCell(Text(entry.key, style: GoogleFonts.inter(fontWeight: FontWeight.w500))),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF800000).withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        entry.value.toString(),
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF800000),
                        ),
                      ),
                    ),
                  ),
                ]);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

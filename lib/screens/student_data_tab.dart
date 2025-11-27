import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:school_management/models/student.dart';
import 'package:school_management/screens/fees_tab.dart';
import 'package:school_management/screens/home_tabs_screen.dart';
import 'package:school_management/services/supabase_service.dart';

class StudentDataTab extends StatefulWidget {
  const StudentDataTab({super.key});

  @override
  State<StudentDataTab> createState() => _StudentDataTabState();
}

class _StudentDataTabState extends State<StudentDataTab> {
  bool _showFullDataView = false;
  late Future<Map<String, int>> _classCountsFuture;
  late Future<List<Student>> _allStudentsFuture;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  void _loadStatistics() {
    _allStudentsFuture = SupabaseService.getAllStudents();
    _classCountsFuture = _allStudentsFuture.then((students) {
      final Map<String, int> classCounts = {};
      for (var student in students) {
        final className = student.className.split('-').first; // Group by class, ignore section
        classCounts[className] = (classCounts[className] ?? 0) + 1;
      }
      // Sort the map by class name
      return Map.fromEntries(
          classCounts.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showFullDataView) {
      // Show the original student data screen with class/section filters
      return const StudentDataWidget();
    } else {
      // Show the new statistics view
      return _buildStatisticsView();
    }
  }

  Widget _buildStatisticsView() {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue[50]!, Colors.cyan[100]!],
          ),
        ),
        child: FutureBuilder<List<dynamic>>(
          future: Future.wait([_allStudentsFuture, _classCountsFuture]),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            final allStudents = snapshot.data![0] as List<Student>;
            final classCounts = snapshot.data![1] as Map<String, int>;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Student Statistics',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.indigo[900],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Summary Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Total Students',
                          allStudents.length.toString(),
                          Icons.people,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          'Total Classes',
                          classCounts.keys.length.toString(),
                          Icons.school,
                          Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Class Strength Table
                  Text(
                    'Class Strength',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.indigo[800],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Class')),
                        DataColumn(label: Text('Number of Students'), numeric: true),
                      ],
                      rows: classCounts.entries.map((entry) {
                        return DataRow(cells: [
                          DataCell(Text(entry.key)),
                          DataCell(Text(entry.value.toString())),
                        ]);
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Button to switch to full data view
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => setState(() => _showFullDataView = true),
                      icon: const Icon(Icons.grid_view_rounded),
                      label: const Text('Show Full Student Data'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(title, style: GoogleFonts.poppins(color: Colors.grey[600])),
            Text(value, style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:school_management/services/supabase_service.dart';
import 'package:school_management/models/student.dart';
import 'package:school_management/screens/student_detail_screen.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class StudentDataTab extends StatefulWidget {
  const StudentDataTab({super.key});

  @override
  State<StudentDataTab> createState() => _StudentDataTabState();
}

class _StudentDataTabState extends State<StudentDataTab> {
  late Future<Map<String, List<String>>> _classDataFuture;
  Map<String, List<String>> _classData = {};
  String? _selectedClass;
  String? _selectedSection;
  List<Student> _allFilteredStudents = [];
  List<Student> _displayStudents = [];
  bool _isLoading = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _classDataFuture = SupabaseService.getUniqueClassesAndSections();
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);
    try {
      List<Student> students = [];
      if (_selectedClass != null) {
        String queryClass = (_selectedClass == 'NURSERY' || _selectedClass == 'S BATCH') 
            ? _selectedClass! 
            : (_selectedSection != null ? '$_selectedClass-$_selectedSection' : _selectedClass!);
        
        if (_selectedSection != null || (_classData[_selectedClass] ?? []).isEmpty) {
           students = await SupabaseService.getStudentsByClass(queryClass);
        } else {
           // If class selected but no section yet, maybe fetch all students of that class prefix?
           // The user said "directly show class and section filter", so usually they select both.
           // But if they haven't selected section, we'll wait or fetch prefix.
           students = await SupabaseService.getStudentsByClassPrefix(_selectedClass!);
        }
      } else {
        // No filter, maybe don't load everything automatically to avoid lag, 
        // or load everything? User mentioned export without filters exports all.
        // Let's not load anything until filtered for performance, unless they search.
      }
      
      setState(() {
        _allFilteredStudents = students;
        _displayStudents = students;
        _searchController.clear();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading students: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onSearch(String query) {
    setState(() {
      if (query.isEmpty) {
        _displayStudents = _allFilteredStudents;
      } else {
        _displayStudents = _allFilteredStudents
            .where((s) => s.name.toLowerCase().contains(query.toLowerCase()) || 
                          (s.rollNo?.toLowerCase().contains(query.toLowerCase()) ?? false))
            .toList();
      }
    });
  }

  Future<void> _exportToExcel() async {
    setState(() => _isLoading = true);
    try {
      List<Student> studentsToExport = [];
      if (_selectedClass == null && _searchController.text.isEmpty) {
        // Export complete student data
        studentsToExport = await SupabaseService.getAllStudents();
      } else {
        // Export filtered data
        studentsToExport = _displayStudents;
      }

      if (studentsToExport.isEmpty) {
        throw 'No data to export';
      }

      var excel = excel_pkg.Excel.createExcel();
      var sheet = excel.sheets[excel.getDefaultSheet()]!;

      // Headers
      List<String> headers = ['Name', 'Admsn No', 'AADHAR', 'APAAR', 'Class', 'Father Name', 'Mother Name', 'Parent Mobile', 'Gender', 'Address', 'DOJ', 'Bus Facility', 'Route', 'BusNo', 'Hostel Facility', 'Hostel Type'];
      sheet.appendRow(headers);

      for (var s in studentsToExport) {
        sheet.appendRow([
          s.name,
          s.rollNo ?? '',
          s.aadhar ?? '',
          s.apaar ?? '',
          s.className,
          s.fatherName,
          s.motherName,
          s.parentMobile,
          s.gender ?? '',
          s.address ?? '',
          s.doj ?? '',
          s.busFacility ?? 'No',
          s.busRoute ?? '',
          s.busNo ?? '',
          s.hostelFacility ?? 'No',
          s.hostelType ?? '',
        ]);
      }

      var fileBytes = excel.save();
      if (fileBytes != null) {
        String fileName = "Student_Data_${DateTime.now().millisecondsSinceEpoch}.xlsx";
        if (kIsWeb) {
          final blob = html.Blob([fileBytes]);
          final url = html.Url.createObjectUrlFromBlob(blob);
          final anchor = html.AnchorElement(href: url)
            ..setAttribute("download", fileName)
            ..click();
          html.Url.revokeObjectUrl(url);
        } else {
          final directory = await getApplicationDocumentsDirectory();
          final file = File('${directory.path}/$fileName');
          await file.writeAsBytes(fileBytes);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('File saved to ${file.path}')));
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          _buildFilterHeader(),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF800000)))
              : _buildStudentList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF800000), Color(0xFFB91C1C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Student Records',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          FutureBuilder<Map<String, List<String>>>(
            future: _classDataFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              _classData = snapshot.data!;
              final classes = _classData.keys.toList();
              final sections = _selectedClass != null ? (_classData[_selectedClass] ?? []) : [];

              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdown(
                          value: _selectedClass,
                          hint: 'Select Class',
                          items: classes,
                          onChanged: (v) {
                            setState(() {
                              _selectedClass = v;
                              _selectedSection = null;
                            });
                            _loadStudents();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDropdown(
                          value: _selectedSection,
                          hint: 'Select Section',
                          items: sections.cast<String>(),
                          onChanged: (_selectedClass == null || sections.isEmpty) ? null : (v) {
                            setState(() => _selectedSection = v);
                            _loadStudents();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearch,
                          decoration: InputDecoration(
                            hintText: 'Search by name or admsn no...',
                            hintStyle: const TextStyle(color: Colors.white70),
                            prefixIcon: const Icon(Icons.search, color: Colors.white70),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.1),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _exportToExcel,
                        icon: const Icon(Icons.download_rounded),
                        label: const Text('Export'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF800000),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String hint,
    required List<String> items,
    required ValueChanged<String?>? onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: onChanged,
          dropdownColor: const Color(0xFF800000),
          iconEnabledColor: Colors.white,
          style: const TextStyle(color: Colors.white),
          isExpanded: true,
        ),
      ),
    );
  }

  Widget _buildStudentList() {
    if (_displayStudents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search_rounded, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              _selectedClass == null ? 'Select a class to view students' : 'No students found matching your criteria',
              style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _displayStudents.length,
      itemBuilder: (context, index) {
        final student = _displayStudents[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: student.photoUrl != null && student.photoUrl!.isNotEmpty
                ? CircleAvatar(radius: 28, backgroundImage: NetworkImage(student.photoUrl!))
                : CircleAvatar(
                    radius: 28,
                    backgroundColor: const Color(0xFF800000).withOpacity(0.1),
                    child: const Icon(Icons.person, color: Color(0xFF800000)),
                  ),
            title: Text(
              student.name,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('Admsn No: ${student.rollNo ?? 'N/A'} • Class: ${student.className}'),
                Text('Father: ${student.fatherName}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              ],
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => StudentDetailScreen(student: student)),
              );
            },
          ),
        );
      },
    );
  }
}
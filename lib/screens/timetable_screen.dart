import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:school_management/services/supabase_service.dart';

class TimeTableScreen extends StatefulWidget {
  final String? staffName;
  const TimeTableScreen({super.key, this.staffName});

  @override
  State<TimeTableScreen> createState() => _TimeTableScreenState();
}

class _TimeTableScreenState extends State<TimeTableScreen> {
  final TextEditingController _assessmentController = TextEditingController();
  final List<TimeTableRow> _rows = [];
  bool _isLoading = false;
  List<String> _availableClasses = [];
  String? _selectedClass;
  List<String> _savedAssessments = [];
  String? _selectedAssessment;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    // Start with 6 empty rows as shown in the template image
    for (int i = 0; i < 6; i++) {
      _rows.add(TimeTableRow());
    }
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadClasses(),
      _loadSavedAssessments(),
    ]);
    setState(() => _isLoading = false);
  }

  Future<void> _loadClasses() async {
    try {
      if (widget.staffName != null) {
        _availableClasses = await SupabaseService.getClassesForStaff(widget.staffName!);
      } else {
        _availableClasses = await SupabaseService.getUniqueClasses();
      }
      _availableClasses.sort();
    } catch (e) {
      print('Error loading classes: $e');
    }
  }

  Future<void> _loadSavedAssessments() async {
    try {
      String? classPart = _selectedClass?.split('-')[0];
      final assessments = await SupabaseService.getUniqueAssessments(className: classPart);
      setState(() {
        _savedAssessments = assessments;
      });
    } catch (e) {
      print('Error loading assessments: $e');
    }
  }

  Future<void> _fetchTimeTable(String? assessmentName) async {
    if (assessmentName == null) return;
    
    setState(() => _isLoading = true);
    try {
      String? classPart = _selectedClass?.split('-')[0];
      final data = await SupabaseService.getTimeTableByAssessment(assessmentName, className: classPart);
      
      // If no data found for the selected class, we should still show the assessment name
      // but clear the rows effectively.
      if (data.isEmpty) {
        setState(() {
          _selectedAssessment = assessmentName;
          _assessmentController.text = assessmentName;
          _rows.clear();
          for (int i = 0; i < 6; i++) {
            _rows.add(TimeTableRow());
            if (classPart != null) _rows.last.classController.text = classPart;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No timetable found for "$assessmentName" in class "$classPart"')),
        );
      } else {
        setState(() {
          _selectedAssessment = assessmentName;
          _assessmentController.text = assessmentName;
          _rows.clear();
          for (var item in data) {
            final row = TimeTableRow();
            row.classController.text = item['class_name'] ?? '';
            row.dateController.text = item['exam_date'] ?? '';
            row.timeController.text = item['exam_time'] ?? '';
            row.subjectController.text = item['subject'] ?? '';
            _rows.add(row);
          }
          // Ensure at least 6 rows
          while (_rows.length < 6) {
            _rows.add(TimeTableRow());
          }
        });
      }
    } catch (e) {
      print('Error fetching timetable: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onClassSelected(String? className) {
    if (className == null) return;
    setState(() {
      _selectedClass = className;
      // Parse class part: "II-A" -> "II"
      String classPart = className.split('-')[0];
      for (var row in _rows) {
        row.classController.text = classPart;
      }
      
      // Reset assessment selection as it might not be valid for the new class
      _selectedAssessment = null;
      _assessmentController.clear();
    });
    // Refresh assessments list for the newly selected class
    _loadSavedAssessments();
  }

  void _addRow() {
    setState(() {
      final newRow = TimeTableRow();
      if (_selectedClass != null) {
        newRow.classController.text = _selectedClass!.split('-')[0];
      }
      _rows.add(newRow);
    });
  }

  Future<void> _deleteTimeTable(String assessmentName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete TimeTable'),
        content: Text('Are you sure you want to delete the timetable for "$assessmentName"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    String? classPart = _selectedClass?.split('-')[0];
    final success = await SupabaseService.deleteTimeTable(assessmentName, className: classPart);
    setState(() => _isLoading = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('TimeTable deleted successfully')),
      );
      setState(() {
        _selectedAssessment = null;
        _assessmentController.clear();
        _rows.clear();
        for (int i = 0; i < 6; i++) {
          _rows.add(TimeTableRow());
        }
      });
      _loadSavedAssessments();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete TimeTable')),
      );
    }
  }

  Future<void> _saveTimeTable() async {
    if (_assessmentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter Assessment Name')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final List<Map<String, dynamic>> data = [];
    for (var row in _rows) {
      if (row.classController.text.isNotEmpty ||
          row.subjectController.text.isNotEmpty) {
        data.add({
          'assessment_name': _assessmentController.text.trim(),
          'class_name': row.classController.text.trim(),
          'exam_date': row.dateController.text.trim(),
          'exam_time': row.timeController.text.trim(),
          'subject': row.subjectController.text.trim(),
        });
      }
    }

    if (data.isEmpty) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter at least one row of data')),
      );
      return;
    }

    final success = await SupabaseService.saveTimeTable(data);
    setState(() => _isLoading = false);

    if (success) {
      _loadSavedAssessments();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('TimeTable saved successfully!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save TimeTable')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'EXAM TIMETABLE',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            )
          else
            IconButton(
              onPressed: _saveTimeTable,
              icon: const Icon(Icons.save),
              tooltip: 'Save TimeTable',
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green[50]!, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // View Saved Timetables section
              if (_savedAssessments.isNotEmpty)
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  color: Colors.green[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.history, color: Colors.green),
                            const SizedBox(width: 8),
                            Text(
                              'VIEW SAVED TIMETABLE',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.green[800],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedAssessment,
                                decoration: InputDecoration(
                                  hintText: 'Select assessment to view',
                                  isDense: true,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                items: _savedAssessments.map((String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value, style: GoogleFonts.poppins(fontSize: 13)),
                                  );
                                }).toList(),
                                onChanged: _fetchTimeTable,
                              ),
                            ),
                            if (_selectedAssessment != null) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: () => _deleteTimeTable(_selectedAssessment!),
                                icon: const Icon(Icons.delete_forever, color: Colors.red),
                                tooltip: 'Delete this timetable',
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              
              // Header section
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        'NALANDA ENGLISH MEDIUM SCHOOL',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[900],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'EXAM TIMETABLE',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      const Divider(height: 24),
                      Row(
                        children: [
                          Text(
                            'ASSESSMENT NAME - ',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _assessmentController,
                              decoration: const InputDecoration(
                                hintText: 'Enter assessment name (e.g. Unit Test 1)',
                                isDense: true,
                                border: UnderlineInputBorder(),
                              ),
                              style: GoogleFonts.poppins(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text(
                            'SELECT CLASS - ',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButton<String>(
                                value: _selectedClass,
                                isExpanded: true,
                                underline: const SizedBox(),
                                hint: Text('Select Class', style: GoogleFonts.poppins(fontSize: 14)),
                                items: _availableClasses.map((String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value, style: GoogleFonts.poppins(fontSize: 14)),
                                  );
                                }).toList(),
                                onChanged: _onClassSelected,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Editable Table
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    // Table Header
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.green[700],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          _buildHeaderCell('CLASS', 1),
                          _buildHeaderCell('DATE', 2),
                          _buildHeaderCell('TIME', 2),
                          _buildHeaderCell('SUBJECT', 2),
                        ],
                      ),
                    ),
                    
                    // Table Rows
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _rows.length,
                      itemBuilder: (context, index) {
                        return _buildDataRow(_rows[index]);
                      },
                    ),
                    
                    // Add Row Button
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: TextButton.icon(
                        onPressed: _addRow,
                        icon: const Icon(Icons.add, color: Colors.green),
                        label: const Text('Add Row', style: TextStyle(color: Colors.green)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saveTimeTable,
        label: Text(_selectedAssessment == null ? 'SAVE DATA' : 'UPDATE TIMETABLE'),
        icon: const Icon(Icons.cloud_upload),
        backgroundColor: _selectedAssessment == null ? Colors.green[800] : Colors.blue[800],
      ),
    );
  }

  Widget _buildHeaderCell(String label, int flex) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildDataRow(TimeTableRow row) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          _buildEditableCell(row.classController, 1),
          _buildEditableCell(row.dateController, 2),
          _buildEditableCell(row.timeController, 2),
          _buildEditableCell(row.subjectController, 2),
        ],
      ),
    );
  }

  Widget _buildEditableCell(TextEditingController controller, int flex) {
    return Expanded(
      flex: flex,
      child: Container(
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: Colors.grey[300]!)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: TextField(
          controller: controller,
          textAlign: TextAlign.center,
          decoration: const InputDecoration(
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 12),
          ),
          style: GoogleFonts.poppins(fontSize: 12),
        ),
      ),
    );
  }
}

class TimeTableRow {
  final TextEditingController classController = TextEditingController();
  final TextEditingController dateController = TextEditingController();
  final TextEditingController timeController = TextEditingController();
  final TextEditingController subjectController = TextEditingController();
}

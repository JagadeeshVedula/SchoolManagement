import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:school_management/services/supabase_service.dart';

class HomeworkScreen extends StatefulWidget {
  final String staffName;

  const HomeworkScreen({super.key, required this.staffName});

  @override
  State<HomeworkScreen> createState() => _HomeworkScreenState();
}

class _HomeworkScreenState extends State<HomeworkScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;
  List<String> _classes = [];
  String? _selectedClass;
  DateTime _selectedDate = DateTime.now();
  
  // Subject Controllers
  final TextEditingController _teluguController = TextEditingController();
  final TextEditingController _englishController = TextEditingController();
  final TextEditingController _hindiController = TextEditingController();
  final TextEditingController _mathsController = TextEditingController();
  final TextEditingController _scienceController = TextEditingController();
  final TextEditingController _socialController = TextEditingController();
  final TextEditingController _othersController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  @override
  void dispose() {
    _teluguController.dispose();
    _englishController.dispose();
    _hindiController.dispose();
    _mathsController.dispose();
    _scienceController.dispose();
    _socialController.dispose();
    _othersController.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isLoading = true);
    try {
      final classes = await SupabaseService.getClassesForStaff(widget.staffName);
      setState(() {
        _classes = classes;
        if (_classes.isNotEmpty) {
          _selectedClass = _classes.first;
        }
      });
      if (_selectedClass != null) {
        await _fetchHomework();
      }
    } catch (e) {
      print('Error fetching initial data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchHomework() async {
    if (_selectedClass == null) return;
    
    setState(() => _isLoading = true);
    _clearControllers();
    
    try {
      final dateStr = DateFormat('dd-MM-yyyy').format(_selectedDate);
      final homework = await SupabaseService.getHomework(_selectedClass!, dateStr);
      
      if (homework != null && mounted) {
        setState(() {
          _teluguController.text = homework['TELUGU'] ?? '';
          _englishController.text = homework['ENGLISH'] ?? '';
          _hindiController.text = homework['HINDI'] ?? '';
          _mathsController.text = homework['MATHS'] ?? '';
          _scienceController.text = homework['SCIENCE'] ?? '';
          _socialController.text = homework['SOCIAL'] ?? '';
          _othersController.text = homework['OTHERS'] ?? '';
        });
      }
    } catch (e) {
      print('Error fetching homework: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _clearControllers() {
    _teluguController.clear();
    _englishController.clear();
    _hindiController.clear();
    _mathsController.clear();
    _scienceController.clear();
    _socialController.clear();
    _othersController.clear();
  }

  Future<void> _saveHomework() async {
    if (_selectedClass == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a class')),
      );
      return;
    }

    setState(() => _isSaving = true);
    
    try {
      final dateStr = DateFormat('dd-MM-yyyy').format(_selectedDate);
      final Map<String, dynamic> homeworkData = {
        'CLASS': _selectedClass,
        'DATE': dateStr,
        'TELUGU': _teluguController.text.trim(),
        'ENGLISH': _englishController.text.trim(),
        'HINDI': _hindiController.text.trim(),
        'MATHS': _mathsController.text.trim(),
        'SCIENCE': _scienceController.text.trim(),
        'SOCIAL': _socialController.text.trim(),
        'OTHERS': _othersController.text.trim(),
      };

      final success = await SupabaseService.saveHomework(homeworkData);
      
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Homework saved successfully!'), backgroundColor: Colors.green),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save homework'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      print('Error saving homework: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue[800]!,
              onPrimary: Colors.white,
              onSurface: Colors.blue[900]!,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _fetchHomework();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Home Work',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue[800],
        elevation: 2,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue[50]!, Colors.cyan[50]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: _isLoading && _classes.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _classes.isEmpty
                ? Center(
                    child: Text(
                      'No classes assigned to you.',
                      style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[700]),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Filters Section
                          Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  DropdownButtonFormField<String>(
                                    value: _selectedClass,
                                    decoration: InputDecoration(
                                      labelText: 'Select Class',
                                      prefixIcon: const Icon(Icons.class_, color: Colors.blue),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    items: _classes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() => _selectedClass = value);
                                        _fetchHomework();
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  InkWell(
                                    onTap: () => _selectDate(context),
                                    child: InputDecorator(
                                      decoration: InputDecoration(
                                        labelText: 'Date',
                                        prefixIcon: const Icon(Icons.calendar_today, color: Colors.blue),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      child: Text(
                                        DateFormat('dd-MM-yyyy').format(_selectedDate),
                                        style: GoogleFonts.poppins(fontSize: 16),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          Text(
                            'Assign Subject-wise Homework',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue[900],
                            ),
                          ),
                          const SizedBox(height: 16),

                          if (_isLoading)
                            const Center(child: Padding(
                              padding: EdgeInsets.all(40.0),
                              child: CircularProgressIndicator(),
                            ))
                          else ...[
                            _buildSubjectTextField('TELUGU', _teluguController, Colors.red[50]!, Colors.red[900]!),
                            _buildSubjectTextField('ENGLISH', _englishController, Colors.blue[50]!, Colors.blue[900]!),
                            _buildSubjectTextField('HINDI', _hindiController, Colors.orange[50]!, Colors.orange[900]!),
                            _buildSubjectTextField('MATHS', _mathsController, Colors.green[50]!, Colors.green[900]!),
                            _buildSubjectTextField('SCIENCE', _scienceController, Colors.teal[50]!, Colors.teal[900]!),
                            _buildSubjectTextField('SOCIAL', _socialController, Colors.brown[50]!, Colors.brown[900]!),
                            _buildSubjectTextField('OTHERS', _othersController, Colors.purple[50]!, Colors.purple[900]!),
                            
                            const SizedBox(height: 32),
                            
                            SizedBox(
                              width: double.infinity,
                              height: 55,
                              child: ElevatedButton(
                                onPressed: _isSaving ? null : _saveHomework,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue[800],
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 4,
                                ),
                                child: _isSaving
                                    ? const CircularProgressIndicator(color: Colors.white)
                                    : Text(
                                        'Save Homework',
                                        style: GoogleFonts.poppins(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 40),
                          ],
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _buildSubjectTextField(String label, TextEditingController controller, Color bgColor, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextFormField(
          controller: controller,
          maxLines: 3,
          minLines: 1,
          style: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: GoogleFonts.poppins(color: textColor.withOpacity(0.7), fontWeight: FontWeight.w600),
            filled: true,
            fillColor: bgColor.withOpacity(0.3),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: textColor, width: 2),
            ),
          ),
        ),
      ),
    );
  }
}

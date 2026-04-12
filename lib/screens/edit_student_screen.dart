import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:school_management/models/student.dart';
import 'package:school_management/services/supabase_service.dart';

class EditStudentScreen extends StatefulWidget {
  final Student student;

  const EditStudentScreen({super.key, required this.student});

  @override
  State<EditStudentScreen> createState() => _EditStudentScreenState();
}

class _EditStudentScreenState extends State<EditStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _rollNoController;
  late TextEditingController _fatherNameController;
  late TextEditingController _motherNameController;
  late TextEditingController _parentMobileController;
  late TextEditingController _addressController;
  late TextEditingController _dojController;
  late TextEditingController _aadharController;
  late TextEditingController _apaarController;
  
  String? _selectedClass;
  String? _selectedSection;
  String? _selectedGender;
  String? _selectedBusRoute;
  String? _selectedBusNo;
  String? _busFacility;
  String? _hostelFacility;
  String? _hostelType;
  
  Uint8List? _imageBytes;
  bool _isSubmitting = false;
  
  List<String> _classes = [];
  Map<String, List<String>> _classData = {};
  List<String> _busRoutes = [];
  List<String> _busNumbers = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.student.name);
    _rollNoController = TextEditingController(text: widget.student.rollNo);
    _fatherNameController = TextEditingController(text: widget.student.fatherName);
    _motherNameController = TextEditingController(text: widget.student.motherName);
    _parentMobileController = TextEditingController(text: widget.student.parentMobile);
    _addressController = TextEditingController(text: widget.student.address);
    _dojController = TextEditingController(text: widget.student.doj);
    _aadharController = TextEditingController(text: widget.student.aadhar);
    _apaarController = TextEditingController(text: widget.student.apaar);
    
    _selectedGender = widget.student.gender;
    _busFacility = widget.student.busFacility;
    _selectedBusRoute = widget.student.busRoute;
    _selectedBusNo = widget.student.busNo;
    _hostelFacility = widget.student.hostelFacility;
    _hostelType = widget.student.hostelType;

    // Parse class and section
    if (widget.student.className.contains('-')) {
      final parts = widget.student.className.split('-');
      _selectedClass = parts[0].trim();
      _selectedSection = parts[1].trim();
    } else {
      _selectedClass = widget.student.className;
    }

    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final classData = await SupabaseService.getUniqueClassesAndSections();
    final routes = await SupabaseService.getBusRoutes();
    
    setState(() {
      _classData = classData;
      _classes = classData.keys.toList();
      _busRoutes = routes;
    });

    if (_selectedBusRoute != null && _selectedBusRoute!.isNotEmpty) {
      final busNumbers = await SupabaseService.getBusNumbersByRoute(_selectedBusRoute!);
      setState(() {
        _busNumbers = busNumbers;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rollNoController.dispose();
    _fatherNameController.dispose();
    _motherNameController.dispose();
    _parentMobileController.dispose();
    _addressController.dispose();
    _dojController.dispose();
    _aadharController.dispose();
    _apaarController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _imageBytes = bytes;
      });
    }
  }

  Future<void> _saveStudent() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSubmitting = true);
    
    String? photoUrl = widget.student.photoUrl;
    if (_imageBytes != null) {
      final fileName = 'student_${widget.student.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      photoUrl = await SupabaseService.uploadStudentPhoto(fileName, _imageBytes!);
    }

    String finalClass = _selectedClass ?? '';
    if (_selectedSection != null && _selectedSection!.isNotEmpty) {
      finalClass = '$finalClass-$_selectedSection';
    }

    final data = {
      'Name': _nameController.text.trim(),
      'ROLL_NO': _rollNoController.text.trim(),
      'AADHAR': _aadharController.text.trim(),
      'APAAR': _apaarController.text.trim(),
      'PHOTO_URL': photoUrl,
      'Class': finalClass,
      'Father Name': _fatherNameController.text.trim(),
      'Mother Name': _motherNameController.text.trim(),
      'Parent Mobile': _parentMobileController.text.trim(),
      'ADDRESS': _addressController.text.trim(),
      'GENDER': _selectedGender,
      'Route': _selectedBusRoute,
      'BusNo': _selectedBusNo,
      'Bus Facility': _busFacility,
      'Hostel Facility': _hostelFacility,
      'HOSTELTYPE': _hostelType,
      'DOJ': _dojController.text.trim(),
    };

    final result = await SupabaseService.updateStudent(
      widget.student.id!, 
      data, 
      oldName: widget.student.name,
    );
    
    setState(() => _isSubmitting = false);
    
    if (result) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Student details updated successfully')),
      );
      Navigator.pop(context, true); // true indicates reload needed
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update student details')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Student', style: GoogleFonts.poppins()),
        backgroundColor: const Color(0xFF800000),
        foregroundColor: Colors.white,
      ),
      body: _isSubmitting 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                   // Image Picker
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey[200],
                        border: Border.all(color: const Color(0xFF800000), width: 2),
                        image: _imageBytes != null 
                          ? DecorationImage(image: MemoryImage(_imageBytes!), fit: BoxFit.cover) 
                          : (widget.student.photoUrl != null && widget.student.photoUrl!.isNotEmpty 
                              ? DecorationImage(image: NetworkImage(widget.student.photoUrl!), fit: BoxFit.cover)
                              : null),
                      ),
                      child: (_imageBytes == null && (widget.student.photoUrl == null || widget.student.photoUrl!.isEmpty))
                        ? const Icon(Icons.camera_alt, size: 40, color: Colors.grey)
                        : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Tap to change photo', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 24),
                  
                  _buildTextField(_nameController, 'Student Name', Icons.person),
                  _buildTextField(_rollNoController, 'Admsn No', Icons.numbers),
                  _buildTextField(_aadharController, 'AADHAR NO', Icons.credit_card, keyboardType: TextInputType.number),
                  _buildTextField(_apaarController, 'APAAR ID', Icons.badge_outlined),
                  
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdown('Class', _classes, _selectedClass, (val) {
                          setState(() {
                            _selectedClass = val;
                            _selectedSection = null;
                          });
                        }),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildDropdown('Section', _selectedClass != null ? (_classData[_selectedClass] ?? []) : [], _selectedSection, (val) {
                          setState(() {
                            _selectedSection = val;
                          });
                        }),
                      ),
                    ],
                  ),
                  
                  _buildTextField(_fatherNameController, 'Father Name', Icons.man),
                  _buildTextField(_motherNameController, 'Mother Name', Icons.woman),
                  _buildTextField(_parentMobileController, 'Parent Mobile', Icons.phone, keyboardType: TextInputType.phone),
                  _buildTextField(_dojController, 'Joining Date (DD-MM-YYYY)', Icons.calendar_today),
                  _buildTextField(_addressController, 'Address', Icons.location_on, maxLines: 2),
                  
                  _buildDropdown('Gender', ['Male', 'Female', 'Other'], _selectedGender, (val) {
                    setState(() => _selectedGender = val);
                  }),
                  
                  const SizedBox(height: 16),
                  _buildSwitch('Bus Facility', _busFacility == 'Yes', (val) {
                    setState(() => _busFacility = val ? 'Yes' : 'No');
                  }),
                  
                  if (_busFacility == 'Yes') ...[
                    _buildDropdown('Bus Route', _busRoutes, _selectedBusRoute, (val) async {
                      setState(() {
                        _selectedBusRoute = val;
                        _selectedBusNo = null;
                      });
                      if (val != null) {
                        final busNumbers = await SupabaseService.getBusNumbersByRoute(val);
                        setState(() => _busNumbers = busNumbers);
                      }
                    }),
                    _buildDropdown('Bus No', _busNumbers, _selectedBusNo, (val) {
                      setState(() => _selectedBusNo = val);
                    }),
                  ],
                  
                  const SizedBox(height: 16),
                  _buildSwitch('Hostel Facility', _hostelFacility == 'Yes', (val) {
                    setState(() => _hostelFacility = val ? 'Yes' : 'No');
                  }),
                  
                  if (_hostelFacility == 'Yes')
                    _buildDropdown('Hostel Type', ['AC', 'NON-AC'], _hostelType, (val) {
                      setState(() => _hostelType = val);
                    }),
                    
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _saveStudent,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF800000),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Update Details', style: GoogleFonts.poppins(fontSize: 16, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {TextInputType keyboardType = TextInputType.text, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF800000)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: (val) => val == null || val.isEmpty ? 'Required' : null,
      ),
    );
  }

  Widget _buildDropdown(String label, List<String> items, String? value, Function(String?) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: items.contains(value) ? value : null,
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildSwitch(String label, bool value, Function(bool) onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 16)),
        Switch(value: value, onChanged: onChanged, activeColor: const Color(0xFF800000)),
      ],
    );
  }
}

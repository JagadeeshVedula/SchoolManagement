import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'package:school_management/services/supabase_service.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  int _selectedTab = 0; // 0 = Class, 1 = School, 2 = Promotional

  // Class Events State
  List<String> _classes = [];
  String? _selectedClass;
  final TextEditingController _classMessageCtrl = TextEditingController();
  bool _isLoadingClasses = true;

  // School Events State
  final TextEditingController _schoolMessageCtrl = TextEditingController();

  // Promotional Events State
  final TextEditingController _promoMessageCtrl = TextEditingController();
  List<Map<String, String>> _promoContacts = [];
  String? _excelFileName;
  bool _isReadingExcel = false;
  PlatformFile? _promoAttachment;

  // Sending state
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    try {
      final classesMap = await SupabaseService.getUniqueClassesAndSections();
      if (mounted) {
        setState(() {
          _classes = classesMap.keys.toList()..sort();
          _isLoadingClasses = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingClasses = false;
        });
      }
    }
  }

  Future<void> _pickAndParseExcel() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        setState(() {
          _isReadingExcel = true;
          _excelFileName = result.files.single.name;
          _promoContacts.clear();
        });

        final bytes = result.files.single.bytes!;
        final excel = Excel.decodeBytes(bytes);
        final List<Map<String, String>> extracted = [];

        for (var table in excel.tables.keys) {
          final rows = excel.tables[table]?.rows ?? [];
          if (rows.isEmpty) continue;

          int nameIndex = -1;
          int numberIndex = -1;
          final headerRow = rows.first;
          for (int i = 0; i < headerRow.length; i++) {
            final val = headerRow[i]?.value?.toString().toLowerCase().trim();
            if (val == 'name') {
              nameIndex = i;
            } else if (val == 'number' || val == 'mobile' || val == 'phone') {
              numberIndex = i;
            }
          }

          if (nameIndex != -1 && numberIndex != -1) {
            for (int r = 1; r < rows.length; r++) {
              final row = rows[r];
              if (row.length <= numberIndex) continue;
              final numVal = row[numberIndex]?.value?.toString().trim() ?? '';
              if (numVal.isNotEmpty) {
                final nameVal = (row.length > nameIndex) ? (row[nameIndex]?.value?.toString().trim() ?? '') : '';
                extracted.add({'Name': nameVal, 'Number': numVal});
              }
            }
          }
        }

        setState(() {
          _isReadingExcel = false;
          _promoContacts = extracted;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Found ${_promoContacts.length} contacts in the file.')),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isReadingExcel = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error parsing excel: $e')),
        );
      }
    }
  }

  Future<void> _pickWhatsAppAttachment() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _promoAttachment = result.files.first;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking attachment: $e')),
        );
      }
    }
  }

  void _showLoading() {
    setState(() {
      _isSending = true;
    });
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
  }

  void _hideLoading() {
    setState(() {
      _isSending = false;
    });
    Navigator.of(context, rootNavigator: true).pop();
  }

  Future<void> _sendClassEvents() async {
    if (_selectedClass == null || _classMessageCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a class and enter a message.')),
      );
      return;
    }

    _showLoading();
    try {
      final students = await SupabaseService.getStudentsByClassPrefix(_selectedClass!);
      int successCount = 0;
      int failureCount = 0;
      for (var student in students) {
        final mobile = student.parentMobile.trim();
        if (mobile.isNotEmpty) {
          final success = await SupabaseService.sendSms(mobile, _classMessageCtrl.text.trim());
          if (success) {
            successCount++;
          } else {
            failureCount++;
          }
        }
      }
      _hideLoading();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sent: $successCount, Failed: $failureCount. (Total students in class: ${students.length})')),
      );
      _classMessageCtrl.clear();
    } catch (e) {
      _hideLoading();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _sendSchoolEvents() async {
    if (_schoolMessageCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a message.')),
      );
      return;
    }

    _showLoading();
    try {
      final students = await SupabaseService.getAllStudents();
      int successCount = 0;
      int failureCount = 0;
      
      // using a set to ensure unique mobile numbers
      final Set<String> uniqueMobiles = {};
      for (var student in students) {
        final mobile = student.parentMobile.trim();
        if (mobile.isNotEmpty) {
          uniqueMobiles.add(mobile);
        }
      }

      for (var mobile in uniqueMobiles) {
        final success = await SupabaseService.sendSms(mobile, _schoolMessageCtrl.text.trim());
        if (success) {
          successCount++;
        } else {
          failureCount++;
        }
      }

      _hideLoading();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sent: $successCount, Failed: $failureCount. (Total unique parents: ${uniqueMobiles.length})')),
      );
      _schoolMessageCtrl.clear();
    } catch (e) {
      _hideLoading();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _sendPromotionalEvents() async {
    if (_promoContacts.isEmpty || _promoMessageCtrl.text.trim().isEmpty) {
      if (_promoAttachment == null) {
        // If there is an attachment, maybe message isn't mandatory, but let's encourage both.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a message or provide an attachment.')),
        );
        if (_promoMessageCtrl.text.trim().isEmpty && _promoAttachment == null) return;
      }
    }

    if (_promoContacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload a valid excel with numbers.')),
      );
      return;
    }

    _showLoading();
    try {
      int successCount = 0;
      int failureCount = 0;

      for (var contact in _promoContacts) {
        final number = contact['Number'] ?? '';
        if (number.isNotEmpty) {
          final msg = _promoMessageCtrl.text.trim();
          final success = await SupabaseService.sendWhatsApp(
            number, 
            msg, 
            attachmentBytes: _promoAttachment?.bytes, 
            attachmentName: _promoAttachment?.name,
          );
          if (success) {
            successCount++;
          } else {
            failureCount++;
          }
        }
      }

      _hideLoading();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('WhatsApp messages sent: $successCount, Failed: $failureCount')),
      );
      _promoMessageCtrl.clear();
      setState(() {
        _promoContacts.clear();
        _excelFileName = null;
        _promoAttachment = null;
      });
    } catch (e) {
      _hideLoading();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Events', style: GoogleFonts.poppins()),
        backgroundColor: const Color(0xFF800000),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Tabs
            ToggleButtons(
              isSelected: [
                _selectedTab == 0,
                _selectedTab == 1,
                _selectedTab == 2,
              ],
              onPressed: (index) {
                setState(() {
                  _selectedTab = index;
                });
              },
              borderRadius: BorderRadius.circular(8),
              selectedColor: Colors.white,
              fillColor: const Color(0xFF800000),
              color: const Color(0xFF800000),
              children: const [
                Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Class Events')),
                Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('School Events')),
                Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Promotional Events')),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedTab) {
      case 0:
        return _buildClassEvents();
      case 1:
        return _buildSchoolEvents();
      case 2:
        return _buildPromotionalEvents();
      default:
        return const SizedBox();
    }
  }

  Widget _buildClassEvents() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_isLoadingClasses)
          const Center(child: CircularProgressIndicator())
        else
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: 'Select Class',
              border: OutlineInputBorder(),
            ),
            value: _selectedClass,
            items: _classes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (val) {
              setState(() {
                _selectedClass = val;
              });
            },
          ),
        const SizedBox(height: 16),
        TextField(
          controller: _classMessageCtrl,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Type message here',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _isSending ? null : _sendClassEvents,
          icon: const Icon(Icons.send),
          label: const Text('Send Message Option'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF800000),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildSchoolEvents() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'This will send a message to ALL parents in the school.',
          style: GoogleFonts.poppins(color: Colors.redAccent, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _schoolMessageCtrl,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Type message here',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _isSending ? null : _sendSchoolEvents,
          icon: const Icon(Icons.send),
          label: const Text('Send Message Option'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF800000),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildPromotionalEvents() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: _isReadingExcel ? null : _pickAndParseExcel,
          icon: const Icon(Icons.upload_file),
          label: Text(
            _excelFileName != null ? 'Use another Excel File' : 'Upload Excel (containing "Name" and "Number")',
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        const SizedBox(height: 8),
        if (_isReadingExcel)
          const Center(child: LinearProgressIndicator())
        else if (_excelFileName != null)
          Text('File loaded: $_excelFileName (${_promoContacts.length} numbers found)',
              style: GoogleFonts.poppins(color: Colors.green)),
        const SizedBox(height: 16),
        if (_promoContacts.isNotEmpty) ...[
          TextField(
            controller: _promoMessageCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Type WhatsApp message here',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _isSending ? null : _pickWhatsAppAttachment,
                icon: const Icon(Icons.attach_file),
                label: const Text('Add Attachment'),
              ),
              const SizedBox(width: 12),
              if (_promoAttachment != null)
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.insert_drive_file, size: 16, color: Color(0xFF800000)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _promoAttachment!.name,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(color: const Color(0xFF800000), fontWeight: FontWeight.w600),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            _promoAttachment = null;
                          });
                        },
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _isSending ? null : _sendPromotionalEvents,
            icon: const Icon(Icons.send),
            label: const Text('Send WhatsApp Option'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF800000), // WhatsApp-ish color (updated to Maroon)
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ],
    );
  }
}

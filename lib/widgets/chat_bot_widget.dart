import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:school_management/models/student.dart';
import 'package:school_management/services/supabase_service.dart';
import 'package:school_management/screens/student_detail_screen.dart';

class ChatBotWidget extends StatefulWidget {
  const ChatBotWidget({super.key});

  @override
  State<ChatBotWidget> createState() => _ChatBotWidgetState();
}

class _ChatBotWidgetState extends State<ChatBotWidget> with SingleTickerProviderStateMixin {
  bool _isOpen = false;
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isTyping = false;
  final ScrollController _scrollController = ScrollController();
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    // Initial message
    _addBotMessage("Hello! I'm your School Assistant. How can I help you today?", quickReplies: ["Search Student", "General Enquiry"]);
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _addBotMessage(String text, {List<String>? quickReplies, List<Student>? students}) {
    setState(() {
      _messages.add({
        'text': text,
        'isBot': true,
        'quickReplies': quickReplies,
        'students': students,
        'time': DateTime.now(),
      });
    });
    _scrollToBottom();
  }

  void _addUserMessage(String text) {
    setState(() {
      _messages.add({
        'text': text,
        'isBot': false,
        'time': DateTime.now(),
      });
    });
    _scrollToBottom();
  }

  void _handleUserInput(String input) async {
    if (input.trim().isEmpty) return;

    _addUserMessage(input);
    _controller.clear();

    setState(() {
      _isTyping = true;
    });

    // Simple routing logic
    if (input.toLowerCase().contains("search") || input.toLowerCase().contains("student")) {
      await Future.delayed(const Duration(milliseconds: 500));
      _addBotMessage("Please enter the student's name you want to search for.");
    } else {
      // Try searching for student directly
      final students = await SupabaseService.searchStudentsByName(input);
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (students.isNotEmpty) {
        _addBotMessage("I found ${students.length} student(s) matching '$input':", students: students);
      } else {
        _addBotMessage("I couldn't find any student matching '$input'. Try another name or keyword.", quickReplies: ["Search Student", "Help"]);
      }
    }

    setState(() {
      _isTyping = false;
    });
  }

  void _toggleChat() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = const Color(0xFF800000); // Maroon

    return Stack(
      children: [
        // Chat Window
        Positioned(
          bottom: 90,
          right: 20,
          child: SizeTransition(
            sizeFactor: _expandAnimation,
            axisAlignment: 1.0,
            child: Container(
              width: 350,
              height: 500,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
                border: Border.all(color: themeColor.withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [themeColor, const Color(0xFFB91C1C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: Colors.white24,
                          child: Icon(Icons.smart_toy_outlined, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'School Assistant',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'Online',
                              style: GoogleFonts.inter(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: _toggleChat,
                        ),
                      ],
                    ),
                  ),
                  // Messages
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length + (_isTyping ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _messages.length) {
                          return _buildTypingIndicator();
                        }
                        return _buildMessage(_messages[index]);
                      },
                    ),
                  ),
                  // Input
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.2))),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            decoration: InputDecoration(
                              hintText: 'Type your enquiry...',
                              hintStyle: GoogleFonts.inter(fontSize: 14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(25),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.grey[100],
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            ),
                            onSubmitted: _handleUserInput,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _handleUserInput(_controller.text),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: themeColor,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.send, color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // FAB
        Positioned(
          bottom: 20,
          right: 20,
          child: FloatingActionButton(
            onPressed: _toggleChat,
            backgroundColor: themeColor,
            elevation: 8,
            child: Icon(
              _isOpen ? Icons.keyboard_arrow_down : Icons.chat_bubble_outline,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessage(Map<String, dynamic> msg) {
    final isBot = msg['isBot'] as bool;
    final List<String>? quickReplies = msg['quickReplies'];
    final List<Student>? students = msg['students'];

    return Column(
      crossAxisAlignment: isBot ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          constraints: const BoxConstraints(maxWidth: 260),
          decoration: BoxDecoration(
            color: isBot ? Colors.grey[100] : const Color(0xFF800000),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(15),
              topRight: const Radius.circular(15),
              bottomLeft: Radius.circular(isBot ? 0 : 15),
              bottomRight: Radius.circular(isBot ? 15 : 0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                msg['text'],
                style: GoogleFonts.inter(
                  color: isBot ? Colors.black87 : Colors.white,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        if (students != null && students.isNotEmpty)
          _buildStudentsList(students),
        if (isBot && quickReplies != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Wrap(
              spacing: 8,
              children: quickReplies.map((reply) => _buildQuickReply(reply)).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildQuickReply(String text) {
    return ActionChip(
      label: Text(text, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF800000))),
      onPressed: () => _handleUserInput(text),
      backgroundColor: Colors.white,
      side: const BorderSide(color: Color(0xFF800000)),
      padding: EdgeInsets.zero,
    );
  }

  void _showFeeDetails(Student student) async {
    _addUserMessage("View Fees for ${student.name}");
    
    setState(() {
      _isTyping = true;
    });

    final fees = await SupabaseService.getStudentFeeSummary(student);
    await Future.delayed(const Duration(milliseconds: 500));

    final text = """Fee Summary for ${student.name}:
• School Fee: Rs.${fees['schoolFee']?.toStringAsFixed(2)}
• Bus Fee: Rs.${fees['busFee']?.toStringAsFixed(2)}
• Hostel Fee: Rs.${fees['hostelFee']?.toStringAsFixed(2)}
----------------------------
• Total Fees: Rs.${fees['totalFees']?.toStringAsFixed(2)}
• Total Paid: Rs.${fees['totalPaid']?.toStringAsFixed(2)}
• Total Pending: Rs.${fees['totalPending']?.toStringAsFixed(2)}""";

    _addBotMessage(text, quickReplies: ["Search Student"]);

    setState(() {
      _isTyping = false;
    });
  }

  Widget _buildStudentsList(List<Student> students) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      width: 280,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: students.map((student) {
          return Column(
            children: [
              ListTile(
                dense: true,
                title: Text(student.name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                subtitle: Text('Class: ${student.className}', style: GoogleFonts.inter(fontSize: 11)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: Color(0xFF800000)),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => StudentDetailScreen(student: student)),
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 8),
                child: Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => _showFeeDetails(student),
                      icon: const Icon(Icons.receipt_long, size: 14),
                      label: const Text('View Fees', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        backgroundColor: const Color(0xFF800000).withOpacity(0.05),
                        foregroundColor: const Color(0xFF800000),
                      ),
                    ),
                  ],
                ),
              ),
              if (student != students.last) const Divider(height: 1),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dot(1),
            const SizedBox(width: 4),
            _dot(2),
            const SizedBox(width: 4),
            _dot(3),
          ],
        ),
      ),
    );
  }

  Widget _dot(int order) {
    return Container(
      width: 6,
      height: 6,
      decoration: const BoxDecoration(color: Colors.black26, shape: BoxShape.circle),
    );
  }
}

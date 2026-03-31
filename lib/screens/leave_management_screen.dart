// Import Material Design widgets and components for building UI
import 'package:flutter/material.dart';
// Import Google Fonts package to use custom Google Font styles in the app
import 'package:google_fonts/google_fonts.dart';
// Import Supabase service to fetch leave data from the database
import 'package:school_management/services/supabase_service.dart';
// Import apply leave screen to navigate when staff wants to apply for a new leave
import 'package:school_management/screens/apply_leave_screen.dart';

// Main stateful widget class for Leave Management Screen
// Stateful because we need to manage dynamic data (leaves list) and UI state (selected month)
class LeaveManagementScreen extends StatefulWidget {
  // Property to store staff name passed from parent widget
  final String staffName;

  // Constructor with required staffName parameter
  const LeaveManagementScreen({
    super.key,
    required this.staffName, // Required staff name for fetching their leave records
  });

  // Create and return the mutable state object for this stateful widget
  @override
  State<LeaveManagementScreen> createState() => _LeaveManagementScreenState();
}

// State class for LeaveManagementScreen - handles mutable state and UI updates
class _LeaveManagementScreenState extends State<LeaveManagementScreen> {
  // Future that holds the list of leaves data fetched from Supabase
  // Used to manage asynchronous data loading and display it with FutureBuilder
  late Future<List<Map<String, dynamic>>> _leavesFuture;
  
  // String to store currently selected month (format: YYYY-MM) for filtering leaves
  // Default empty string, will be set to current month in initState
  String _selectedMonth = '';

  // Lifecycle method called when the widget is first created
  // Used to initialize state variables and fetch initial data
  @override
  void initState() {
    super.initState(); // Call parent's initState to ensure proper initialization
    _setCurrentMonth(); // Set the current month as default filter
    _loadLeaves(); // Fetch leave data for the current month
  }

  // Method to set the current month in YYYY-MM format
  // This ensures that the app always shows current month leaves by default
  void _setCurrentMonth() {
    final now = DateTime.now(); // Get current date and time
    // Format: concatenate year, hyphen, and month with leading zero (e.g., 2024-03)
    _selectedMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  // Method to fetch leaves for the selected staff and month from Supabase database
  // Called when month filter changes or after applying a new leave
  void _loadLeaves() {
    // Call Supabase service to get leaves data with staff name and selected month
    // Result is stored in _leavesFuture for use with FutureBuilder widget
    _leavesFuture = SupabaseService.getLeavesForStaffForMonth(
      widget.staffName, // Pass staff name to fetch their specific records
      _selectedMonth, // Pass selected month to filter leaves by month
    );
  }

  // Main build method that constructs the UI for the Scaffold
  // Returns the complete Leave Management Screen interface
  @override
  Widget build(BuildContext context) {
    // Scaffold provides the basic material design structure (AppBar, body, etc.)
    return Scaffold(
      // AppBar: top navigation bar with title and green theme
      appBar: AppBar(
        // Title text showing "Leave Management" with custom styling
        title: Text(
          'Leave Management',
          style: GoogleFonts.poppins(
            fontSize: 20, // Large font size for prominent title
            fontWeight: FontWeight.w700, // Bold weight for emphasis
            color: Colors.white, // White text for contrast against green background
          ),
        ),
        backgroundColor: Colors.green[700], // Dark green background for AppBar
        elevation: 2, // Subtle shadow for depth
      ),
      // Main body container with gradient background
      body: Container(
        // Gradient background: light green to lime green for aesthetic appeal
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green[50]!, Colors.lime[50]!], // Light gradient colors
            begin: Alignment.topLeft, // Gradient starts from top-left
            end: Alignment.bottomRight, // Gradient ends at bottom-right
          ),
        ),
        // Column to stack child widgets vertically
        child: Column(
          children: [
            // ========== MONTH FILTER SECTION ==========
            // Container for month filter dropdown
            // Positioned at top with dark green background to stand out
            Container(
              padding: const EdgeInsets.all(16), // Internal spacing
              color: Colors.green[700], // Dark green to match AppBar
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, // Align items to left
                children: [
                  // Label text for the filter section
                  Text(
                    'Filter by Month',
                    style: GoogleFonts.poppins(
                      fontSize: 14, // Standard label size
                      fontWeight: FontWeight.w600, // Semibold for readability
                      color: Colors.white, // White text on green background
                    ),
                  ),
                  const SizedBox(height: 12), // Space between label and dropdown
                  // Container styling the dropdown button
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12), // Internal spacing
                    decoration: BoxDecoration(
                      color: Colors.white, // White background for visibility
                      borderRadius: BorderRadius.circular(8), // Rounded corners
                      border: Border.all(color: Colors.green[300]!, width: 1), // Green border
                    ),
                    // DropdownButton to select month
                    child: DropdownButton<String>(
                      value: _selectedMonth, // Currently selected month
                      isExpanded: true, // Expand to fill available width
                      underline: const SizedBox(), // Remove default underline
                      // Map month options to DropdownMenuItem widgets
                      items: _generateMonthOptions().map((month) {
                        return DropdownMenuItem(
                          value: month, // Value when this option is selected
                          child: Text(
                            month, // Display text (YYYY-MM format)
                            style: GoogleFonts.poppins(), // Use Poppins font
                          ),
                        );
                      }).toList(), // Convert mapped items to list
                      // Callback when user selects a different month
                      onChanged: (value) {
                        setState(() {
                          // Update selected month with new value or keep existing if null
                          _selectedMonth = value ?? _selectedMonth;
                          _loadLeaves(); // Fetch leaves for new month
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),

            // ========== LEAVES LIST SECTION ==========
            // Expanded widget takes remaining vertical space
            // Contains FutureBuilder to handle async data loading
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _leavesFuture, // The Future containing leaves data
                builder: (context, snapshot) {
                  // Show loading spinner while data is being fetched
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(Colors.green[600]), // Green spinner
                      ),
                    );
                  }

                  // Show error message if data fetch failed
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error loading leaves',
                        style: GoogleFonts.poppins(color: Colors.red[600]), // Red error text
                      ),
                    );
                  }

                  // Get leaves data from snapshot, default to empty list if null
                  final leaves = snapshot.data ?? [];

                  // Show empty state message when no leaves exist for the selected month
                  if (leaves.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center, // Center vertically
                        children: [
                          // Calendar icon for visual indication
                          Icon(
                            Icons.calendar_today,
                            size: 64, // Large icon size
                            color: Colors.green[600],
                          ),
                          const SizedBox(height: 16), // Space between icon and text
                          // Empty state message
                          Text(
                            'No leaves found for this month',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.green[900],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // Build scrollable list of leave records
                  return ListView.builder(
                    padding: const EdgeInsets.all(16), // Padding around list items
                    itemCount: leaves.length, // Number of items in the list
                    itemBuilder: (context, index) {
                      // Get individual leave record from list
                      final leave = leaves[index];
                      // Check if leave is approved
                      final isApproved = leave['APPROVED'] == 'YES';
                      // Check if leave is rejected
                      final isRejected = leave['REJECTED'] == 'YES';

                      // Determine status text and color based on approval state
                      String statusText;
                      Color statusColor;

                      if (isApproved) {
                        statusText = 'Approved';
                        statusColor = Colors.green;
                      } else if (isRejected) {
                        statusText = 'Rejected';
                        statusColor = Colors.red;
                      } else {
                        statusText = 'Pending';
                        statusColor = Colors.orange;
                      }

                      // Card widget for each leave record with elevation and rounding
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12), // Space between cards
                        elevation: 4, // Shadow depth
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12), // Rounded corners
                        ),
                        // Container with gradient based on leave status
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12), // Match card shape
                            // Gradient from white to status color for visual distinction
                            gradient: LinearGradient(
                              colors: [Colors.white, statusColor.withOpacity(0.1)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          padding: const EdgeInsets.all(16), // Internal spacing
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start, // Align to left
                            children: [
                              // First row: icon, leave date, and status badge
                              Row(
                                children: [
                                  // Icon representing leave/event
                                  Icon(
                                    Icons.event,
                                    color: statusColor, // Color based on status
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12), // Space after icon
                                  // Expanded widget to take available space
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Small label for date field
                                        Text(
                                          'Leave Date',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12, // Small label size
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey[600], // Grey for subtle look
                                          ),
                                        ),
                                        // Actual leave date value from database
                                        Text(
                                          leave['LEAVEDATE']?.toString() ?? 'N/A',
                                          style: GoogleFonts.poppins(
                                            fontSize: 16, // Larger for main content
                                            fontWeight: FontWeight.w700, // Bold for emphasis
                                            color: Colors.grey[800],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Status badge showing approval state
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.1), // Light status color
                                      borderRadius: BorderRadius.circular(20), // Pill shape
                                    ),
                                    child: Text(
                                      statusText, // Approved/Rejected/Pending
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: statusColor, // Matches background color
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12), // Space between rows
                              // Label for reason section
                              Text(
                                'Reason',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 4), // Small space between label and content
                              // Reason text provided by staff for the leave
                              Text(
                                leave['REASON']?.toString() ?? 'No reason provided',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // ========== APPLY LEAVE BUTTON SECTION ==========
            // Padding around the apply leave button
            Padding(
              padding: const EdgeInsets.all(16), // Space from edges
              child: SizedBox(
                width: double.infinity, // Button takes full width
                child: ElevatedButton.icon(
                  // Navigate to ApplyLeaveScreen when button is pressed
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ApplyLeaveScreen(
                          staffName: widget.staffName, // Pass staff name to apply leave screen
                        ),
                      ),
                    ).then((_) {
                      // After returning from ApplyLeaveScreen, refresh the leaves list
                      setState(() {
                        _loadLeaves(); // Reload leaves to show newly applied leave
                      });
                    });
                  },
                  // Button styling: green background, padding, rounded corners
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600], // Green button to match theme
                    padding: const EdgeInsets.symmetric(vertical: 14), // Taller button
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12), // Rounded corners
                    ),
                    elevation: 4, // Shadow for depth
                  ),
                  icon: const Icon(Icons.add, color: Colors.white), // Plus icon
                  // Button label text
                  label: Text(
                    'Apply Leave',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white, // White text
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to generate month options for the dropdown filter
  // Creates a list of months from 6 months ago to 6 months in the future
  // This allows staff to view and apply for leaves across a wide date range
  List<String> _generateMonthOptions() {
    final now = DateTime.now(); // Get current date
    final months = <String>[]; // List to store generated month strings

    // Loop from 6 months before current to 6 months after current
    for (int i = -6; i <= 6; i++) {
      // Create a date by adding 'i' months to current month
      final date = DateTime(now.year, now.month + i);
      // Format month as YYYY-MM (e.g., 2024-03)
      final month = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      months.add(month); // Add formatted month to list
    }

    return months; // Return list of 13 month options
  }
}

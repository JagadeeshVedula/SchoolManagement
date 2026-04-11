import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  // Testing with quoted column name in select
  const url = 'https://mggcskkkricnmkjqdqai.supabase.co/rest/v1/STUDENTS?select=%22Parent%20Mobile%22&limit=1';
  const anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1nZ2Nza2trcmljbm1ranFkcWFpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjMxNjk4MjQsImV4cCI6MjA3ODc0NTgyNH0.Z74XcwusKBcVr82QWU5UxKBRgwyAILwKXiVgyTg5SaQ';
  
  try {
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'apikey': anonKey,
        'Authorization': 'Bearer $anonKey',
      },
    );
    
    if (response.statusCode == 200) {
      print('DATA: ${response.body}');
    } else {
      print('ERROR: ${response.statusCode} - ${response.body}');
    }
  } catch (e) {
    print('CONNECTION ERROR: $e');
  }
}

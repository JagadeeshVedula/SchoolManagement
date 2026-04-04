import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';

Future<void> saveFileImpl(Uint8List bytes, String fileName, String mimeType) async {
  try {
    if (Platform.isAndroid) {
      // Request Manage External Storage for Android 11+ to allow arbitrary folder writing
      // This is often needed for users to save to their chosen directory
      if (await Permission.manageExternalStorage.request().isDenied) {
         // If denied, we'll try to proceed with standard permissions
         await Permission.storage.request();
      }
    }

    String? selectedPath;
    try {
      selectedPath = await FilePicker.platform.getDirectoryPath();
    } catch (e) {
      print('Folder picker failed: $e');
    }

    Directory? directory;
    if (selectedPath != null) {
      directory = Directory(selectedPath);
    } else {
      // Use Downloads folder as the default public location for better user access
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
           directory = await getExternalStorageDirectory();
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }
    }

    if (directory == null) {
      directory = await getApplicationDocumentsDirectory();
    }

    final filePath = '${directory.path}/$fileName';
    final file = File(filePath);
    
    try {
      await file.writeAsBytes(bytes);
      print('File saved successfully at: $filePath');
    } catch (e) {
      print('Write error: $e');
      
      // Fallback 1: Try public Downloads if picked path failed
      if (Platform.isAndroid && !filePath.contains('/Download')) {
        try {
          final downloadFile = File('/storage/emulated/0/Download/$fileName');
          await downloadFile.writeAsBytes(bytes);
          print('Successfully saved to public Downloads: ${downloadFile.path}');
          return;
        } catch (downloadError) {
          print('Public download save failed: $downloadError');
        }
      }

      // Fallback 2: Final fallback to app-specific storage (harder to reach)
      final fallbackDir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
      final fallbackPath = '${fallbackDir.path}/$fileName';
      await File(fallbackPath).writeAsBytes(bytes);
      print('Emergency fallback save successful at: $fallbackPath');
    }
  } catch (e) {
    print('Critical save error: $e');
  }
}

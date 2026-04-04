import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'platform_file_saver_stub.dart'
    if (dart.library.html) 'platform_file_saver_web.dart'
    if (dart.library.io) 'platform_file_saver_mobile.dart';

abstract class PlatformFileSaver {
  static Future<void> saveFile(Uint8List bytes, String fileName, String mimeType) async {
    return saveFileImpl(bytes, fileName, mimeType);
  }
}

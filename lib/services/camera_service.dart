import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

class CameraService {
  static final ImagePicker _picker = ImagePicker();

  static Future<File?> captureAndCrop() async {
    try {
      // 🎯 1. កំណត់ទំហំរូបថត maxWidth/maxHeight ការពារការថតរូបធំពេកអស់ Ram
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80, // 🎯 កំណត់គុណភាពរូបភាព (0-100)
        maxWidth: 1200,
        maxHeight: 1200,
      );

      if (image == null) return null;

      // 🎯 2. Crop រូបភាពដោយមានប្លុក Try-Catch ការពារ
      final CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: '🎯 សូមអូសតម្រង់លើដុំលេខកុងទ័រ',
            toolbarColor: Colors.blue,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(title: '🎯 សូមអូសតម្រង់លើដុំលេខកុងទ័រ'),
        ],
      );

      if (croppedFile == null) return null;
      return File(croppedFile.path);
    } catch (e) {
      debugPrint("❌ Camera Exception (Catch ការពារមិនឱ្យ Crash): $e");
      return null;
    }
  }
}

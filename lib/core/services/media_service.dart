import 'dart:io';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../app_config.dart';

class MediaService {
  static final ImagePicker _picker = ImagePicker();
  static final AudioRecorder _recorder = AudioRecorder();

  // Image picking
  static Future<String?> pickImageAsBase64(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null) {
        final bytes = await image.readAsBytes();
        return base64Encode(bytes);
      }
    } catch (e) {
      print('Error picking image: $e');
    }
    return null;
  }

  // Video picking
  static Future<String?> pickVideoAsBase64() async {
    try {
      final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
      if (video != null) {
        final file = File(video.path);
        final bytes = await file.readAsBytes();
        
        // Check file size (30MB limit)
        if (bytes.length > AppConfig.maxFileSize) {
          throw Exception('File size exceeds 30MB limit');
        }
        
        return base64Encode(bytes);
      }
    } catch (e) {
      print('Error picking video: $e');
      rethrow;
    }
    return null;
  }

  // Document picking
  static Future<Map<String, String>?> pickDocumentAsBase64() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      
      if (result != null) {
        final file = File(result.files.single.path!);
        final bytes = await file.readAsBytes();
        
        // Check file size
        if (bytes.length > AppConfig.maxFileSize) {
          throw Exception('File size exceeds 30MB limit');
        }
        
        return {
          'data': base64Encode(bytes),
          'filename': result.files.single.name,
          'size': bytes.length.toString(),
        };
      }
    } catch (e) {
      print('Error picking document: $e');
      rethrow;
    }
    return null;
  }

  // Audio recording
  static Future<bool> startRecording() async {
    try {
      final permission = await Permission.microphone.request();
      if (!permission.isGranted) {
        throw Exception('Microphone permission denied');
      }

      await _recorder.start(const RecordConfig(), path: '');
      return true;
    } catch (e) {
      print('Error starting recording: $e');
      return false;
    }
  }

  static Future<String?> stopRecordingAsBase64() async {
    try {
      final path = await _recorder.stop();
      if (path != null) {
        final file = File(path);
        final bytes = await file.readAsBytes();
        await file.delete(); // Clean up temp file
        return base64Encode(bytes);
      }
    } catch (e) {
      print('Error stopping recording: $e');
    }
    return null;
  }

  static Future<bool> isRecording() async {
    return await _recorder.isRecording();
  }

  // Location
  static Future<Map<String, double>?> getCurrentLocation() async {
    try {
      final permission = await Permission.location.request();
      if (!permission.isGranted) {
        throw Exception('Location permission denied');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
      };
    } catch (e) {
      print('Error getting location: $e');
      rethrow;
    }
  }

  // Utility methods
  static String getMimeType(String filename) {
    final extension = filename.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/mov';
      case 'mp3':
        return 'audio/mp3';
      case 'wav':
        return 'audio/wav';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'application/octet-stream';
    }
  }

  static bool isImageFile(String filename) {
    final extension = filename.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(extension);
  }

  static bool isVideoFile(String filename) {
    final extension = filename.split('.').last.toLowerCase();
    return ['mp4', 'mov', 'avi', 'mkv', 'flv', 'webm'].contains(extension);
  }

  static bool isAudioFile(String filename) {
    final extension = filename.split('.').last.toLowerCase();
    return ['mp3', 'wav', 'aac', 'ogg', 'm4a'].contains(extension);
  }
}
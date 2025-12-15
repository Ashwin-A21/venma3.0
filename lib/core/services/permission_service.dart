import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// Service to handle runtime permissions, especially for Android 13+ media permissions
class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();
  
  int? _sdkVersion;
  
  /// Get the Android SDK version
  Future<int> getSdkVersion() async {
    if (_sdkVersion != null) return _sdkVersion!;
    
    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      _sdkVersion = androidInfo.version.sdkInt;
      return _sdkVersion!;
    }
    return 0;
  }
  
  /// Check and request media permissions based on Android version
  /// Returns true if all required permissions are granted
  Future<bool> requestMediaPermissions() async {
    if (!Platform.isAndroid) return true;
    
    final sdkVersion = await getSdkVersion();
    
    if (sdkVersion >= 33) {
      // Android 13+ - request granular media permissions
      final statuses = await [
        Permission.photos,
        Permission.videos,
      ].request();
      
      return statuses[Permission.photos]!.isGranted &&
             statuses[Permission.videos]!.isGranted;
    } else {
      // Android 12 and below - request legacy storage permission
      final status = await Permission.storage.request();
      return status.isGranted;
    }
  }
  
  /// Check and request camera permission
  Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }
  
  /// Check and request microphone permission
  Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }
  
  /// Check and request notification permission (Android 13+)
  Future<bool> requestNotificationPermission() async {
    if (!Platform.isAndroid) return true;
    
    final sdkVersion = await getSdkVersion();
    
    if (sdkVersion >= 33) {
      final status = await Permission.notification.request();
      return status.isGranted;
    }
    return true; // No permission needed on older versions
  }
  
  /// Check and request all permissions needed for media picking
  Future<PermissionResults> requestAllMediaPermissions() async {
    final results = PermissionResults();
    
    results.media = await requestMediaPermissions();
    results.camera = await requestCameraPermission();
    results.notifications = await requestNotificationPermission();
    
    return results;
  }
  
  /// Check if we have media read permissions
  Future<bool> hasMediaPermissions() async {
    if (!Platform.isAndroid) return true;
    
    final sdkVersion = await getSdkVersion();
    
    if (sdkVersion >= 33) {
      return await Permission.photos.isGranted && 
             await Permission.videos.isGranted;
    } else {
      return await Permission.storage.isGranted;
    }
  }
  
  /// Open app settings if permission was permanently denied
  Future<bool> openSettings() async {
    return await openAppSettings();
  }
}

class PermissionResults {
  bool media = false;
  bool camera = false;
  bool microphone = false;
  bool notifications = false;
  
  bool get allGranted => media && camera && notifications;
}

# Venma

A Flutter-based social messaging application with real-time chat, voice/video calls, and status updates.

## Overview

Venma is an Android application built with Flutter that provides:
- Real-time messaging with Supabase backend
- Voice and video calling via WebRTC
- Status updates (photos, videos)
- User profiles with customizable avatars
- Contact integration
- Notifications

## Package Information

- **Package Name**: `com.venma.app`
- **App Name**: `venma`
- **Version**: `1.0.0+1`
- **Platform**: Android only

## Build Configuration

### Requirements
- Flutter SDK 3.10.0 or higher
- Android SDK with minimum API level 24 (Android 7.0)
- Target SDK: Latest Flutter default

### Building

Clean and rebuild:
```bash
flutter clean
flutter pub get
flutter build apk --release
```

For debug build:
```bash
flutter build apk --debug
```

## Project Structure

This is an **Android-only** Flutter project. All iOS, web, Windows, Linux, and macOS platform folders have been removed to optimize the project size and focus on Android development.

### Key Directories
- `android/` - Android platform-specific code
- `lib/` - Dart application code
- `lib/core/` - Core utilities and constants
- `lib/features/` - Feature-specific modules
- `lib/services/` - Backend services and APIs

## Dependencies

Key dependencies include:
- `supabase_flutter` - Backend and real-time database
- `google_sign_in` - Google authentication
- `flutter_webrtc` - Voice/video calling
- `camera` - Camera access for photos/videos
- `flutter_local_notifications` - Push notifications
- `fluttermoji` - Avatar customization
- `provider` - State management

## Development Notes

- The project uses Kotlin for Android-specific code
- Core library desugaring is enabled for Java 8+ API support
- Package structure: `com.venma.app`
- Debug signing is used for release builds (update before production deployment)

## Next Steps

1. Set up proper signing configuration for release builds
2. Configure Firebase (if using for notifications)
3. Update Supabase credentials in the app
4. Test all features on physical devices
5. Generate a proper release keystore

## License

Private project - All rights reserved

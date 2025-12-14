# Venma (Version 1)

A deeply personal social app designed for close friends.

## Features

- **Version Selection**: Choose your Venma experience (Currently Version 1 is active).
- **Friend Selection**: Integrate with contacts to invite or add friends.
- **Home Dashboard**:
  - Friend Status (Duration pill).
  - Communication Actions (Call, Video, Nudge/Pinch).
  - Chat Preview with Stickers.
  - Story & Game Footer (Flash Fury).
- **Chat Interface**:
  - Message bubbles with gradient backgrounds.
  - Mymoji and attachment options.
- **Profile Module**:
  - User and Friend profiles.
  - Custom tabs for details (Venma ID, Age, etc.).
  - Atman currency display.
- **Camera Module**:
  - Integrated camera preview.
  - Swipe access from Home.

## Getting Started

1.  **Install Dependencies**:
    ```bash
    flutter pub get
    ```

2.  **Run the App**:
    ```bash
    flutter run
    ```

## Permissions

The app requires the following permissions (already added to `AndroidManifest.xml`):
- Internet
- Contacts (Read/Write)
- Camera
- Microphone

## Note

- This is a frontend implementation with mock data.
- Backend integration (Supabase/Firebase) is needed for real-time features.
- "Mymoji" and "Stickers" are currently placeholders.

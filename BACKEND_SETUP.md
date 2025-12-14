# Supabase Setup Instructions

To make the app work live, you need to set up a Supabase project.

1.  **Create a Project**: Go to [Supabase](https://supabase.com) and create a new project.
2.  **Get Credentials**:
    *   Go to **Project Settings** -> **API**.
    *   Copy the `Project URL` and `anon` public key.
    *   Open `lib/core/constants/app_constants.dart` and paste them there.
3.  **Run SQL Schema**:
    *   Go to the **SQL Editor** in Supabase.
    *   Copy the content of `supabase_schema.sql` from this project.
    *   Paste it into the SQL Editor and click **Run**.
4.  **Enable Auth**:
    *   Go to **Authentication** -> **Providers**.
    *   Enable **Email/Password**.
    *   (Optional) Enable Phone Auth if you have a provider.
5.  **Storage (IMPORTANT for images to work)**:
    *   Go to **Storage** in Supabase Dashboard.
    *   For each bucket (`avatars`, `chat_media`, `status`):
        - Click on the bucket
        - Click the **Settings** (gear icon) or three dots menu
        - Enable **"Public bucket"** toggle
    *   Without this, images will upload but won't display!
    *   The schema creates these buckets automatically, but they may not be public by default.
    *   **Re-run the updated `supabase_schema.sql`** to set buckets as public.

## Running the App

1.  `flutter pub get`
2.  `flutter run`

The app will start at the Login screen. Sign up to create a user, then you can use the app.

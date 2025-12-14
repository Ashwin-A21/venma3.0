# Google Auth Setup

To enable Google Sign-In, you need to configure it in Supabase and your Android app.

## Supabase Configuration
1. Go to **Authentication** -> **Providers** -> **Google**.
2. Enable it.
3. You will need a **Client ID** and **Client Secret** from Google Cloud Console.
   - Go to [Google Cloud Console](https://console.cloud.google.com/).
   - Create a project.
   - Go to **APIs & Services** -> **Credentials**.
   - Create **OAuth Client ID** -> **Web Application**.
   - Add `https://<project-id>.supabase.co/auth/v1/callback` to **Authorized redirect URIs**.
   - Copy Client ID and Secret to Supabase.

## Android Configuration
1. In Google Cloud Console, create another **OAuth Client ID** -> **Android**.
2. Add your package name: `com.example.venma` (check `android/app/build.gradle`).
3. Add your SHA-1 certificate fingerprint.
   - Run `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android` to get the SHA-1.

## Deep Link Configuration
The app uses `io.supabase.venma://login-callback/` as the redirect URL.
Ensure this is added to your Supabase Redirect URLs if needed (usually handled automatically for OAuth).

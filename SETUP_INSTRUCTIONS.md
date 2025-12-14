# Critical Setup Instructions

To make the app work exactly as you requested (Simple Login, No Email Verification, Google Auth), you **MUST** follow these steps in your Supabase Dashboard.

## 1. Disable Email Verification (Crucial)
This ensures users are logged in immediately after signing up, without needing to click a link (which fails on Android).
1.  Go to **Authentication** -> **Providers** -> **Email**.
2.  **Disable** "Confirm email".
3.  Click **Save**.

## 2. Fix "Row Level Security" Error
This ensures user profiles are created automatically without errors.
1.  Go to the **SQL Editor** in Supabase.
2.  Copy the code below:
    ```sql
    -- Trigger to automatically create a user profile
    create or replace function public.handle_new_user()
    returns trigger
    language plpgsql
    security definer set search_path = public
    as $$
    begin
      insert into public.users (id, username, display_name, created_at)
      values (
        new.id,
        new.raw_user_meta_data ->> 'username',
        coalesce(new.raw_user_meta_data ->> 'username', 'New User'),
        now()
      );
      return new;
    end;
    $$;

    drop trigger if exists on_auth_user_created on auth.users;
    create trigger on_auth_user_created
      after insert on auth.users
      for each row execute procedure public.handle_new_user();
    ```
3.  Paste it into the SQL Editor and click **Run**.

## 3. Google Auth Setup
1.  Go to **Authentication** -> **Providers** -> **Google**.
2.  Enable it.
3.  Enter your **Client ID** and **Secret** from Google Cloud Console.
4.  Ensure you have added the **Android Client ID** in Google Cloud Console with your app's SHA-1 fingerprint.

## 4. Run the App
Install the APK located at `build\app\outputs\flutter-apk\app-release.apk`.

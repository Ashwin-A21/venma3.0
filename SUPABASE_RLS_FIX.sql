-- FIXED SCRIPT
-- The previous error "must be owner of table objects" happened because we tried to enable RLS on a system table.
-- RLS is ALREADY enabled on storage.objects, so we can skip that step.
-- Run this script to safely create buckets and policies.

-- 1. Create the buckets if they don't exist
INSERT INTO storage.buckets (id, name, public) 
VALUES 
  ('status', 'status', true),
  ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

-- 2. Safely create policies
-- We use a DO block to check if policies exist before creating them to avoid errors.

DO $$
BEGIN
    -- Policy: Allow uploads to 'status' bucket
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Allow authenticated status uploads'
    ) THEN
        CREATE POLICY "Allow authenticated status uploads"
        ON storage.objects FOR INSERT TO authenticated
        WITH CHECK ( bucket_id = 'status' );
    END IF;

    -- Policy: Allow viewing 'status' bucket
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Allow public status viewing'
    ) THEN
        CREATE POLICY "Allow public status viewing"
        ON storage.objects FOR SELECT TO public
        USING ( bucket_id = 'status' );
    END IF;

    -- Policy: Allow uploads to 'avatars' bucket
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Allow authenticated avatar uploads'
    ) THEN
        CREATE POLICY "Allow authenticated avatar uploads"
        ON storage.objects FOR INSERT TO authenticated
        WITH CHECK ( bucket_id = 'avatars' );
    END IF;

    -- Policy: Allow viewing 'avatars' bucket
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Allow public avatar viewing'
    ) THEN
        CREATE POLICY "Allow public avatar viewing"
        ON storage.objects FOR SELECT TO public
        USING ( bucket_id = 'avatars' );
    END IF;
END $$;

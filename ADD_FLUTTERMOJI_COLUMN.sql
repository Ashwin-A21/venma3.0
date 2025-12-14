-- Run this migration in Supabase SQL Editor to add missing columns

-- Add fluttermoji column to users table
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS fluttermoji text;

-- Update statuses type check to include video
ALTER TABLE public.statuses 
DROP CONSTRAINT IF EXISTS statuses_type_check;

ALTER TABLE public.statuses 
ADD CONSTRAINT statuses_type_check 
CHECK (type IN ('image', 'text', 'video'));

-- Create status storage bucket if not exists
INSERT INTO storage.buckets (id, name) 
VALUES ('status', 'status') 
ON CONFLICT (id) DO NOTHING;

-- RLS for status bucket
DROP POLICY IF EXISTS "Users can upload status media." ON storage.objects;
CREATE POLICY "Users can upload status media." 
ON storage.objects FOR INSERT 
WITH CHECK (
  bucket_id = 'status' AND auth.uid() = (storage.foldername(name))[1]::uuid
);

DROP POLICY IF EXISTS "Public can view status media." ON storage.objects;
CREATE POLICY "Public can view status media." 
ON storage.objects FOR SELECT 
USING (bucket_id = 'status');

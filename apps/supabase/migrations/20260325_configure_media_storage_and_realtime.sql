INSERT INTO storage.buckets (id, name, public, file_size_limit)
VALUES
  ('screenshots', 'screenshots', false, 52428800),
  ('recordings', 'recordings', false, 52428800)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Users can upload own screenshots" ON storage.objects;
CREATE POLICY "Users can upload own screenshots"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'screenshots' AND (storage.foldername(name))[1] = auth.uid()::text);

DROP POLICY IF EXISTS "Users can read own screenshots" ON storage.objects;
CREATE POLICY "Users can read own screenshots"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'screenshots' AND (storage.foldername(name))[1] = auth.uid()::text);

DROP POLICY IF EXISTS "Users can delete own screenshots" ON storage.objects;
CREATE POLICY "Users can delete own screenshots"
  ON storage.objects FOR DELETE
  USING (bucket_id = 'screenshots' AND (storage.foldername(name))[1] = auth.uid()::text);

DROP POLICY IF EXISTS "Users can upload own recordings" ON storage.objects;
CREATE POLICY "Users can upload own recordings"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'recordings' AND (storage.foldername(name))[1] = auth.uid()::text);

DROP POLICY IF EXISTS "Users can read own recordings" ON storage.objects;
CREATE POLICY "Users can read own recordings"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'recordings' AND (storage.foldername(name))[1] = auth.uid()::text);

DROP POLICY IF EXISTS "Users can delete own recordings" ON storage.objects;
CREATE POLICY "Users can delete own recordings"
  ON storage.objects FOR DELETE
  USING (bucket_id = 'recordings' AND (storage.foldername(name))[1] = auth.uid()::text);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'screenshots'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE screenshots;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'recordings'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE recordings;
  END IF;
END $$;

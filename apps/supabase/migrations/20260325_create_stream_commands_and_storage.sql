-- Stream commands table (web → macOS signaling via Realtime postgres changes)
CREATE TABLE IF NOT EXISTS stream_commands (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  action TEXT NOT NULL,
  udid TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

ALTER TABLE stream_commands ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can insert own commands"
  ON stream_commands FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can read own commands"
  ON stream_commands FOR SELECT USING (auth.uid() = user_id);

CREATE INDEX idx_stream_commands_user_id ON stream_commands(user_id);
CREATE INDEX idx_stream_commands_created_at ON stream_commands(created_at DESC);

-- Enable Realtime for stream_commands (macOS subscribes to INSERTs)
ALTER PUBLICATION supabase_realtime ADD TABLE stream_commands;

-- Storage buckets for screenshots and recordings
INSERT INTO storage.buckets (id, name, public, file_size_limit)
VALUES
  ('screenshots', 'screenshots', false, 52428800),
  ('recordings', 'recordings', false, 52428800)
ON CONFLICT (id) DO NOTHING;

-- Storage RLS: users can manage files under their own user_id prefix
CREATE POLICY "Users can upload own screenshots"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'screenshots' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY "Users can read own screenshots"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'screenshots' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY "Users can delete own screenshots"
  ON storage.objects FOR DELETE
  USING (bucket_id = 'screenshots' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY "Users can upload own recordings"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'recordings' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY "Users can read own recordings"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'recordings' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY "Users can delete own recordings"
  ON storage.objects FOR DELETE
  USING (bucket_id = 'recordings' AND (storage.foldername(name))[1] = auth.uid()::text);

-- Streams ownership table (edge function upserts on publish, checks on subscribe)
CREATE TABLE IF NOT EXISTS streams (
  room_name TEXT PRIMARY KEY,
  owner_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

ALTER TABLE streams ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own streams"
  ON streams FOR ALL USING (auth.uid() = owner_id);

-- Enable Realtime for screenshots and recordings (web gallery auto-updates)
ALTER PUBLICATION supabase_realtime ADD TABLE screenshots;
ALTER PUBLICATION supabase_realtime ADD TABLE recordings;

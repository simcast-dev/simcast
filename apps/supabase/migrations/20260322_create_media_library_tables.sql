CREATE TABLE IF NOT EXISTS screenshots (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  storage_path TEXT NOT NULL,
  simulator_name TEXT,
  simulator_udid TEXT,
  width INTEGER,
  height INTEGER,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'ready', 'failed')),
  error_message TEXT,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

ALTER TABLE screenshots ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage own screenshots" ON screenshots;
CREATE POLICY "Users can manage own screenshots"
  ON screenshots FOR ALL USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_screenshots_user_id ON screenshots(user_id);
CREATE INDEX IF NOT EXISTS idx_screenshots_created_at ON screenshots(created_at DESC);

CREATE TABLE IF NOT EXISTS recordings (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  storage_path TEXT NOT NULL,
  simulator_name TEXT,
  simulator_udid TEXT,
  duration_seconds REAL,
  file_size_bytes BIGINT,
  width INTEGER,
  height INTEGER,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'ready', 'failed')),
  error_message TEXT,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

ALTER TABLE recordings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage own recordings" ON recordings;
CREATE POLICY "Users can manage own recordings"
  ON recordings FOR ALL USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_recordings_user_id ON recordings(user_id);
CREATE INDEX IF NOT EXISTS idx_recordings_created_at ON recordings(created_at DESC);

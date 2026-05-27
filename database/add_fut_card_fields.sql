-- FUT Kart Düzenleme Alanları
-- Bu SQL'i Supabase SQL Editor'de çalıştırın

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS fut_photo_url TEXT,
  ADD COLUMN IF NOT EXISTS fut_pac INTEGER DEFAULT 75 CHECK (fut_pac BETWEEN 1 AND 99),
  ADD COLUMN IF NOT EXISTS fut_sho INTEGER DEFAULT 75 CHECK (fut_sho BETWEEN 1 AND 99),
  ADD COLUMN IF NOT EXISTS fut_pas INTEGER DEFAULT 75 CHECK (fut_pas BETWEEN 1 AND 99),
  ADD COLUMN IF NOT EXISTS fut_dri INTEGER DEFAULT 75 CHECK (fut_dri BETWEEN 1 AND 99),
  ADD COLUMN IF NOT EXISTS fut_def INTEGER DEFAULT 75 CHECK (fut_def BETWEEN 1 AND 99),
  ADD COLUMN IF NOT EXISTS fut_phy INTEGER DEFAULT 75 CHECK (fut_phy BETWEEN 1 AND 99);

-- Storage bucket oluştur (player_photos bucket'ı oluşturur)
INSERT INTO storage.buckets (id, name, public)
VALUES ('player_photos', 'player_photos', true)
ON CONFLICT (id) DO NOTHING;

-- RLS Policy: Kullanıcı fotoğraf yükleyebilir
-- (Daha önce oluşturulduysa silinip yeniden oluşturulur)
DROP POLICY IF EXISTS "Players can upload own photo" ON storage.objects;
CREATE POLICY "Players can upload own photo"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'player_photos');

-- RLS Policy: Fotoğrafları listeleyebilme izni (Sadece Giriş Yapmış Olanlar)
DROP POLICY IF EXISTS "Player photos are public" ON storage.objects;
CREATE POLICY "Player photos are public"
ON storage.objects
FOR SELECT
TO authenticated
USING (bucket_id = 'player_photos');


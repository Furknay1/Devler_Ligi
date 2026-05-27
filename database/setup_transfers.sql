-- ==========================================
-- EŞSİZ OYUNCU KİMLİĞİ VE TRANSFER MİMARİSİ
-- ==========================================
-- Bu kodu Supabase SQL Editor içerisinde tek seferde kopyalayıp çalıştırın.

-- 1. Eşsiz Kısa ID Sütunu eklentisi (Sadece yoksa ekler)
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS short_id TEXT UNIQUE;

-- 2. Rastgele 4 Haneli (#1000 - #9999) Kimlik Üreten Fonksiyon
CREATE OR REPLACE FUNCTION generate_short_id()
RETURNS TRIGGER AS $$
DECLARE
  new_id TEXT;
  is_unique BOOLEAN := FALSE;
BEGIN
  -- Yeni bir kullanıcı kaydolduğunda sonsuz döngüyle hiç kimsede olmayan bir #ID aranır
  WHILE NOT is_unique LOOP
    new_id := '#' || (floor(random() * 9000 + 1000)::int)::TEXT;
    
    PERFORM 1 FROM profiles WHERE short_id = new_id;
    IF NOT FOUND THEN
      is_unique := TRUE;
    END IF;
  END LOOP;
  
  -- Bulunan eşsiz id'yi yeni oyuncunun sütununa kaydet
  NEW.short_id := new_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. Trigger (Yeni bir hesap Supabase'de açıldığı salise short_id üretir)
DROP TRIGGER IF EXISTS trigger_generate_short_id ON profiles;
CREATE TRIGGER trigger_generate_short_id
BEFORE INSERT ON profiles
FOR EACH ROW
EXECUTE FUNCTION generate_short_id();

-- 3.1. Güvenlik: tetikleyici fonksiyonunun dışarıdan doğrudan çağrılmasını engelle
REVOKE EXECUTE ON FUNCTION public.generate_short_id() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.generate_short_id() FROM anon, authenticated;

-- 4. GEÇMİŞ KULLANICILAR İÇİN OTOMATİK ID ATAMA DÖNGÜSÜ
-- (Zaten kayıtlı olup short_id'si boşta olan tüm kullanıcılara #1234 formatı dağıtır)
DO $$
DECLARE
  r RECORD;
  new_id TEXT;
  is_unique BOOLEAN;
BEGIN
  FOR r IN SELECT id FROM profiles WHERE short_id IS NULL LOOP
    is_unique := FALSE;
    WHILE NOT is_unique LOOP
      new_id := '#' || (floor(random() * 9000 + 1000)::int)::TEXT;
      PERFORM 1 FROM profiles WHERE short_id = new_id;
      IF NOT FOUND THEN
        UPDATE profiles SET short_id = new_id WHERE id = r.id;
        is_unique := TRUE;
      END IF;
    END LOOP;
  END LOOP;
END $$;

-- 5. TRANSFER İSTEKLERİ TABLOSU
CREATE TABLE IF NOT EXISTS transfer_requests (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    team_id UUID REFERENCES teams(id) ON DELETE CASCADE NOT NULL,
    profile_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    -- Bir takım, aynı oyuncuya reddedilmemiş başka bir "BEKLEMEDE" (pending) olan istek varken üst üste spam atamaz:
    UNIQUE(team_id, profile_id, status) 
);

-- Hızlı filtreleme için indeksler
CREATE INDEX IF NOT EXISTS idx_transfer_req_team ON transfer_requests(team_id);
CREATE INDEX IF NOT EXISTS idx_transfer_req_profile ON transfer_requests(profile_id);

-- 6. GÜVENLİK (Row Level Security)
ALTER TABLE transfer_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Herkes istekleri görebilir" 
ON transfer_requests FOR SELECT USING (true);

CREATE POLICY "Herkes (Kaptanlar) istek oluşturabilir" 
ON transfer_requests FOR INSERT 
TO authenticated 
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  )
  OR EXISTS (
    SELECT 1 FROM public.teams
    WHERE id = team_id AND owner_id = auth.uid()
  )
);

CREATE POLICY "Herkes kendi isteğini onaylayıp/reddedebilir" 
ON transfer_requests FOR UPDATE 
TO authenticated 
USING (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  )
  OR (profile_id = auth.uid())
);

CREATE POLICY "Yalnızca Kaptanlar silebilir" 
ON transfer_requests FOR DELETE 
TO authenticated 
USING (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  )
  OR EXISTS (
    SELECT 1 FROM public.teams
    WHERE id = team_id AND owner_id = auth.uid()
  )
);

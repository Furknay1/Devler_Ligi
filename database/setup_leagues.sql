-- ===========================================
-- SUPABASE STORAGE VE LİG SÜTUNU YAPILANDIRMASI
-- ===========================================

-- 1. "team_requests" VE "teams" TABLOLARINA LİG KİMLİĞİNİ EKLE
-- Eğer bu tablolarda 'league_id' adlı sütunlar yoksa (ilk defa takım kurarken lig aranacaksa), 
-- leagues tablosuna bağlamak suretiyle oluşturur.
ALTER TABLE public.team_requests ADD COLUMN IF NOT EXISTS league_id UUID REFERENCES public.leagues(id);
ALTER TABLE public.teams ADD COLUMN IF NOT EXISTS league_id UUID REFERENCES public.leagues(id);


-- 2. GÜVENLİK DUVARI: RESİM YÜKLEME (STORAGE_RLS) İZİNLERİNİ AÇMA
-- Şu ana kadarki kod, sunucu kovanıza ('team_logos') dışarıdan saldırı sanıp her fotoğrafı bloke ediyordu.

-- Kurulum Öncesi Olası Yüklü Politikaları Siler
DROP POLICY IF EXISTS "Public Access" ON storage.objects;
DROP POLICY IF EXISTS "Auth Insert" ON storage.objects;

-- Politikaları Yaz (Sadece Giriş Yapmış Olanlar listeleyebilir)
CREATE POLICY "Public Access" 
ON storage.objects FOR SELECT 
TO authenticated
USING ( bucket_id = 'team_logos' );

CREATE POLICY "Auth Insert" 
ON storage.objects FOR INSERT TO authenticated 
WITH CHECK ( bucket_id = 'team_logos' );

-- (Eğer Supabase "Dashboard -> Storage -> Policies" menüsünde `team_logos` kovasına policy ekelediyseniz 
-- bu komut onu konsol üzerinden direkt bypasslar).

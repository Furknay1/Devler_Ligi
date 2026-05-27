-- ==========================================
-- DEVLER LIGI - OYUNCU TABLOSU GÜVENLİ RLS POLİTİKALARI
-- ==========================================
-- Bu kod, public.players tablosuna yönelik geniş yetkili wildcard politikasını kaldırır
-- ve yerine Admin, Kaptan ve Oyuncunun kendisini yetkilendiren güvenli kurallar ekler.
-- Lütfen bu kodu Supabase SQL Editor kısmına yapıştırıp "Run" butonuna basın.

-- 1. Eski zayıf veya çakışan politikaları kaldıralım:
DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON public.players;
DROP POLICY IF EXISTS "Users can insert their own player record" ON public.players;
DROP POLICY IF EXISTS "Enable insert for users based on profile_id" ON public.players;
DROP POLICY IF EXISTS "Allow all operations for authenticated users on players" ON public.players;
DROP POLICY IF EXISTS "Allow select for everyone on players" ON public.players;
DROP POLICY IF EXISTS "Allow insert for admin, self, or captain on players" ON public.players;
DROP POLICY IF EXISTS "Allow update for admin, self, or captain on players" ON public.players;
DROP POLICY IF EXISTS "Allow delete for admin or captain on players" ON public.players;

-- 2. players tablosunda RLS'i etkinleştiriyoruz
ALTER TABLE public.players ENABLE ROW LEVEL SECURITY;

-- 3. GÜVENLİ POLİTİKALAR:

-- SELECT: Herkes tüm oyuncuları listeleyebilir (Genel Puan Durumu, Kadrolar vb. için gereklidir)
CREATE POLICY "Allow select for everyone on players"
ON public.players
FOR SELECT
USING (true);

-- INSERT: Sadece Adminler, kendi kaydını oluşturan oyuncular veya takım kaptanları ekleyebilir
CREATE POLICY "Allow insert for admin, self, or captain on players"
ON public.players
FOR INSERT
TO authenticated
WITH CHECK (
  -- Admin Rolü
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  )
  OR
  -- Kendi Oyuncu Profilini Oluşturma (Profile_id eşleşmesi)
  (profile_id = auth.uid())
  OR
  -- Takım Kaptanı (Takım sahibi ise takıma oyuncu ekleyebilir)
  EXISTS (
    SELECT 1 FROM public.teams
    WHERE id = team_id AND owner_id = auth.uid()
  )
);

-- UPDATE: Sadece Adminler, kendi kaydını güncelleyen oyuncular veya takım kaptanları güncelleyebilir
CREATE POLICY "Allow update for admin, self, or captain on players"
ON public.players
FOR UPDATE
TO authenticated
USING (
  -- Admin Rolü
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  )
  OR
  -- Kendi Oyuncu Profilini Güncelleme (Profile_id eşleşmesi)
  (profile_id = auth.uid())
  OR
  -- Takım Kaptanı (Takım sahibi ise takımdaki oyuncuyu güncelleyebilir)
  EXISTS (
    SELECT 1 FROM public.teams
    WHERE id = team_id AND owner_id = auth.uid()
  )
)
WITH CHECK (
  -- Admin Rolü
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  )
  OR
  -- Kendi Oyuncu Profilini Güncelleme (Profile_id eşleşmesi)
  (profile_id = auth.uid())
  OR
  -- Takım Kaptanı (Takım sahibi ise takımdaki oyuncuyu güncelleyebilir)
  EXISTS (
    SELECT 1 FROM public.teams
    WHERE id = team_id AND owner_id = auth.uid()
  )
);

-- DELETE: Sadece Adminler veya takım kaptanları silebilir
CREATE POLICY "Allow delete for admin or captain on players"
ON public.players
FOR DELETE
TO authenticated
USING (
  -- Admin Rolü
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  )
  OR
  -- Takım Kaptanı (Takım sahibi ise takımdaki oyuncuyu silebilir)
  EXISTS (
    SELECT 1 FROM public.teams
    WHERE id = team_id AND owner_id = auth.uid()
  )
);

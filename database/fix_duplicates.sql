-- ==========================================
-- DEVLER LİGİ - TEKRARLANAN TAKIMLARI VE HATALI İSTEKLERİ DÜZELTME
-- ==========================================
-- Önceki RLS hatasından dolayı aynı isimde birçok takım açıldı ama ne istekler
-- onaylandı göründü, ne de siz takımınıza eklendiniz. Bu kod sistemi temizler.

-- 1. AYNI TAKIMIN TEKRARLARINI (KOPYALARINI) SİL (Sadece ilk açılan kalsın)
DELETE FROM public.teams
WHERE id IN (
  SELECT id FROM (
    SELECT id, ROW_NUMBER() OVER(PARTITION BY name, owner_id ORDER BY created_at ASC) as rnum
    FROM public.teams
  ) t
  WHERE t.rnum > 1
);

-- 2. TAKIMI OLUŞAN AMA SİSTEMDE "BEKLİYOR" KALAN İSTEKLERİ ONAYLANMIŞA ÇEVİR
UPDATE public.team_requests tr
SET status = 'approved'
FROM public.teams t
WHERE tr.user_id = t.owner_id AND tr.status = 'pending';

-- 3. TAKIMI OLUŞAN AMA OYUNCU (KAPTAN) OLARAK KENDİSİ EKLENEMEYENLERİ EKLE
-- (Önceki 42501 RLS hatası yüzünden kendi takımınıza oyuncu olarak yazılamamıştınız)
INSERT INTO public.players (team_id, profile_id, name, position, number)
SELECT 
  t.id, 
  t.owner_id, 
  COALESCE(p.username, p.full_name, 'Kaptan'), 
  'KAPTAN', 
  10
FROM public.teams t
JOIN public.profiles p ON t.owner_id = p.id
WHERE NOT EXISTS (
  SELECT 1 FROM public.players pl 
  WHERE pl.team_id = t.id AND pl.profile_id = t.owner_id
);

-- ==========================================
-- DEVLER LİGİ - TÜM KULLANICILARI SİLME
-- ==========================================
-- DİKKAT: Bu kod admin ("role" = 'admin') HARİCİNDEKİ tüm hesapları 
-- hem giriş yapmalarını engellemek için ana auth.users tablosundan siler, 
-- hem de public.profiles tablosundan temizler.

DELETE FROM auth.users 
WHERE id IN (
  SELECT id FROM public.profiles 
  WHERE role != 'admin' OR role IS NULL
);

-- (Eğer üstteki auth tablosu yetki hatası verirse alternatif olarak sadece alttakini de çalıştırabilirsiniz)
DELETE FROM public.profiles WHERE role != 'admin' OR role IS NULL;

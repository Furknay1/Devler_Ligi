-- ========================================================
-- DEVLER LİGİ - TELEFON NUMARASI SÜTUNU VE TETİKLEYİCİ
-- ========================================================
-- Bu SQL kodunu Supabase SQL Editor üzerinde çalıştırın.
-- Yeni kullanıcı kaydolurken girdiğimiz telefon numarasını
-- "profiles" tablosuna senkronize etmeyi sağlar.

-- 1. Profiles tablosuna telefon numarası sütununu ekle
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS phone TEXT;

-- 2. Yeni kullanıcı kaydolduğunda tetiklenen fonksiyonu güncelle
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, username, full_name, role, phone)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'username', SPLIT_PART(NEW.email, '@', 1)),
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    'player',
    COALESCE(NEW.raw_user_meta_data->>'phone', '')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 3. Tetikleyiciyi (trigger) yeniden tanımla (mevcutsa hata vermez)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 4. Güvenlik: SECURITY DEFINER fonksiyonunun dışarıdan çağrılmasını engelle (Sadece dahili tetikleyici çalıştırsın)
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM anon, authenticated;

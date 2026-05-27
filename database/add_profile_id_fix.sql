-- OYUNCULAR TABLOSUNI KULLANICI PROFİLLERİNE BAĞLAMA
-- Bu özellik transfer sistemi için şarttır ve oyuncuların hangi gerçek üyeye 
-- (hesaba) ait olduğunu belirler. Eğer daha önce eklenmediyse, "players" tablosuna
-- "profile_id" kolonunu ekler.

ALTER TABLE public.players
ADD COLUMN IF NOT EXISTS profile_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL;

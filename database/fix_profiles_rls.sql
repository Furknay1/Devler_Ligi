-- PROFILES TABLOSUNU GÜNCELLEME İZNİ (RLS - Row Level Security Politikası)
-- Supabase güvenlik kuralları bazen tabloları korumak için "update" iznini engeller.
-- Bu politika, kullanıcıların SADECE KENDİ hesaplarını güncelleyebilmesini sağlar.

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "everyone_update_own_profile" 
ON public.profiles 
FOR UPDATE 
USING (auth.uid() = id);

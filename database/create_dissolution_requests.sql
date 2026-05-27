-- TAKİM FESİH TALEPLERİ TABLOSU
-- Supabase SQL Editor'da çalıştırın

CREATE TABLE IF NOT EXISTS dissolution_requests (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  team_id uuid REFERENCES teams(id) ON DELETE CASCADE NOT NULL,
  owner_id uuid REFERENCES auth.users(id) NOT NULL,
  status text DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  created_at timestamptz DEFAULT now()
);

-- Row Level Security
ALTER TABLE dissolution_requests ENABLE ROW LEVEL SECURITY;

-- Kaptan kendi talebini görebilir ve oluşturabilir
CREATE POLICY "kaptan_kendi_talebini_gorur" ON dissolution_requests
  FOR SELECT USING (auth.uid() = owner_id);

CREATE POLICY "kaptan_talep_olusturabilir" ON dissolution_requests
  FOR INSERT WITH CHECK (auth.uid() = owner_id);

-- Admin her şeyi yapabilir
CREATE POLICY "admin_tam_yetki" ON dissolution_requests
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- ==========================================
-- OYUNCU REYTİNG / FORM TABLOSU KURULUMU
-- ==========================================
-- Bu kodu kopyalayıp Supabase SQL Editor içerisinde çalıştırın.

CREATE TABLE IF NOT EXISTS match_player_stats (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    match_id UUID REFERENCES matches(id) ON DELETE CASCADE NOT NULL,
    player_id UUID REFERENCES players(id) ON DELETE CASCADE NOT NULL,
    rating NUMERIC(3, 1) DEFAULT 0.0 CHECK (rating >= 1.0 AND rating <= 10.0), -- 1.0 ile 10.0 arası Form Puanı
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    -- Bir oyuncuya aynı maç için sadece 1 kez form notu verilebilir kısıtlaması
    CONSTRAINT unique_player_match UNIQUE (match_id, player_id)
);

-- Maçları tarih sırasına göre hızlıca filtrelemek için Index (Performans artırır)
CREATE INDEX IF NOT EXISTS idx_match_player_stats_match_id ON match_player_stats(match_id);
CREATE INDEX IF NOT EXISTS idx_match_player_stats_player_id ON match_player_stats(player_id);

-- GÜVENLİK (Row Level Security): Sadece yetkili/admin kişiler yazabilsin ama herkes okuyabilsin.
ALTER TABLE match_player_stats ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Herkes notları görüntüleyebilir" 
ON match_player_stats FOR SELECT USING (true);

CREATE POLICY "Sadece yetkililer not girebilir" 
ON match_player_stats FOR INSERT 
TO authenticated 
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  )
);

CREATE POLICY "Sadece yetkililer not güncelleyebilir" 
ON match_player_stats FOR UPDATE 
TO authenticated 
USING (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  )
);

CREATE POLICY "Sadece yetkililer not silebilir" 
ON match_player_stats FOR DELETE 
TO authenticated 
USING (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  )
);

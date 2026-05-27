-- Takım kadrosu (lineup) JSONB kolonunu teams tablosuna ekle
-- Supabase SQL editöründe bu scripti çalıştırın!

ALTER TABLE teams ADD COLUMN IF NOT EXISTS lineup JSONB DEFAULT '{}'::jsonb;

-- Örnek lineup yapısı:
-- {
--   "KALECİ": "player_id_uuid",
--   "DEF_SOL": "player_id_uuid",
--   "DEF_SAĞ": "player_id_uuid",
--   "ORT_SOL": "player_id_uuid",
--   "ORT_SAĞ": "player_id_uuid",
--   "FOR_SOL": "player_id_uuid",
--   "FOR_SAĞ": "player_id_uuid"
-- }

-- RLS: Kaptan kendi takımının lineup'ını güncelleyebilmeli
-- (Eğer teams tablosunda update policy varsa bu otomatik çalışır)

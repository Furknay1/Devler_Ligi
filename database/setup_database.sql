-- ==========================================
-- DEVLER LIGI - SUPABASE VERİTABANI KURULUMU
-- ==========================================
-- Bu betiği Supabase projenizdeki "SQL Editor" bölümüne yapıştırıp çalıştırın (Run).
-- Uygulamanızın çok daha hızlı çalışmasını sağlayacak olan Puan Durumu ve Gol Krallığı hesaplamalarını
-- Flutter yerine Supabase'in üzerinde gerçek zamanlı View (Görünüm) olarak yapmasını sağlar.

-- 1. PUAN DURUMU (STANDINGS) GÖRÜNÜMÜ
-- Eski view varsa siliyoruz (Çünkü REPLACE VIEW sütun adlarını/sırasını değiştiremez)
DROP VIEW IF EXISTS standings_view CASCADE;

CREATE OR REPLACE VIEW standings_view AS
WITH match_stats AS (
  SELECT
    t.id AS team_id,
    t.name AS team_name,
    t.logo_url,
    m.id AS match_id,
    CASE 
      WHEN m.home_team_id = t.id AND m.home_score > m.away_score THEN 3
      WHEN m.away_team_id = t.id AND m.away_score > m.home_score THEN 3
      WHEN m.home_score = m.away_score THEN 1
      ELSE 0
    END AS points,
    CASE 
      WHEN m.home_team_id = t.id AND m.home_score > m.away_score THEN 1
      WHEN m.away_team_id = t.id AND m.away_score > m.home_score THEN 1
      ELSE 0
    END AS won,
    CASE 
      WHEN m.home_score = m.away_score THEN 1
      ELSE 0
    END AS drawn,
    CASE 
      WHEN m.home_team_id = t.id AND m.home_score < m.away_score THEN 1
      WHEN m.away_team_id = t.id AND m.away_score < m.home_score THEN 1
      ELSE 0
    END AS lost,
    CASE
      WHEN m.home_team_id = t.id THEN m.home_score
      ELSE m.away_score
    END AS gf,
    CASE
      WHEN m.home_team_id = t.id THEN m.away_score
      ELSE m.home_score
    END AS ga
  FROM teams t
  JOIN matches m ON (t.id = m.home_team_id OR t.id = m.away_team_id)
  WHERE m.status = 'finished'
)
SELECT
  t.id AS team_id,
  t.name AS team_name,
  t.logo_url,
  t.league_id,
  COALESCE(COUNT(ms.match_id), 0) AS played,
  COALESCE(SUM(ms.won), 0) AS won,
  COALESCE(SUM(ms.drawn), 0) AS drawn,
  COALESCE(SUM(ms.lost), 0) AS lost,
  COALESCE(SUM(ms.gf), 0) AS gf,
  COALESCE(SUM(ms.ga), 0) AS ga,
  COALESCE(SUM(ms.gf), 0) - COALESCE(SUM(ms.ga), 0) AS avg,
  COALESCE(SUM(ms.points), 0) AS points
FROM teams t
LEFT JOIN match_stats ms ON t.id = ms.team_id
GROUP BY t.id, t.name, t.logo_url, t.league_id
ORDER BY 
  points DESC, 
  avg DESC;


-- 2. GOL KRALLIĞI (TOP SCORERS) GÖRÜNÜMÜ
-- En çok gol atanları büyükten küçüğe sıralar
CREATE OR REPLACE VIEW top_scorers_view AS
SELECT
  p.id AS player_id,
  p.name AS player_name,
  t.name AS team_name,
  COUNT(mg.id) AS goals
FROM players p
JOIN teams t ON p.team_id = t.id
JOIN match_goals mg ON p.id = mg.player_id
GROUP BY p.id, p.name, t.name
ORDER BY goals DESC;

-- SONUÇ:
-- Artık Flutter/Dart kodumuzda "await supabase.from('standings_view').select()" diyerek tüm sıralı listeyi anında alabileceğiz!

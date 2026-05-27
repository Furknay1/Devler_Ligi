-- ============================================
-- DEVLER LİGİ - HARD RESET (SİSTEM SIFIRLAMA)
-- ============================================
-- DİKKAT: Bu kod çalıştırıldığında Supabase'de bulunan Takımlar, Eski Maç Skorları, 
-- Oyuncular, Transfer İstekleri ve Analizler TAMAMEN SİLİNİR (Sıfırlanır).
-- Adminlerin, Kaptanların ve tüm kullanıcıların sadece Login Miktarları (Profilleri) kalır.
-- Bu sayede sisteme takımları baştan, ID usulü transferle düzgün şekilde kaydedebilirsiniz.

TRUNCATE TABLE 
    teams,
    team_requests,
    players,
    matches,
    match_goals,
    match_cards,
    match_player_stats,
    transfer_requests
RESTART IDENTITY CASCADE;

-- (Not: Eğer profiles (Giriş yapan kitle) tamamen silinmek isteniyorsa auth yetkisi gerekir. 
-- Bu yüzden en sağlıklısı olan, bütün site içeriklerini ve takımlarını sıfırlayan kod budur.)

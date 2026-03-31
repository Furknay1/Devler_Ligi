import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:devler_ligi/main.dart'; // supabase erişimi için

// Admin State Sınıfı (AYNI KALIYOR)
class AdminState {
  final bool isLoading;
  final List<Map<String, dynamic>> matches;
  final List<Map<String, dynamic>> standings;
  final List<Map<String, dynamic>> requests;
  final String? errorMessage;

  AdminState({
    this.isLoading = false,
    this.matches = const [],
    this.standings = const [],
    this.requests = const [],
    this.errorMessage,
  });

  AdminState copyWith({
    bool? isLoading,
    List<Map<String, dynamic>>? matches,
    List<Map<String, dynamic>>? standings,
    List<Map<String, dynamic>>? requests,
    String? errorMessage,
  }) {
    return AdminState(
      isLoading: isLoading ?? this.isLoading,
      matches: matches ?? this.matches,
      standings: standings ?? this.standings,
      requests: requests ?? this.requests,
      errorMessage: errorMessage,
    );
  }
}

// Admin Logic (Notifier)
class AdminNotifier extends Notifier<AdminState> {
  @override
  AdminState build() {
    return AdminState();
  }

  // Verileri Yenile (AYNI)
  Future<void> refreshAllData() async {
    state = state.copyWith(isLoading: true);
    try {
      await Future.wait([
        _getMatches(),
        _calculateStandings(),
        _getRequests(),
      ]);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  // --- (MEVCUT FONKSİYONLAR: _getMatches, _getRequests, _calculateStandings, approveTeam BURADA KALACAK) ---
  // Yer kaplamasın diye onları tekrar yazmıyorum, yukarıdaki kodlarının altına ŞUNLARI EKLE:

  // --- YENİ: MAÇ SİLME ---
  Future<bool> deleteMatch(String matchId) async {
    try {
      // Önce goleleri sil (İlişkisel bütünlük için)
      await supabase.from('match_goals').delete().eq('match_id', matchId);
      // Sonra maçı sil
      await supabase.from('matches').delete().eq('id', matchId);
      
      await refreshAllData(); // Listeyi yenile
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: "Maç silinemedi: $e");
      return false;
    }
  }

  // --- YENİ: TAKIM SİLME ---
  Future<bool> deleteTeam(String teamId) async {
    try {
      // Önce takıma bağlı oyuncuları sil
      await supabase.from('players').delete().eq('team_id', teamId);
      
      // Takımın maçları varsa hata verebilir (FK Constraint). 
      // Basitlik adına, önce takımı silmeyi deniyoruz.
      await supabase.from('teams').delete().eq('id', teamId);
      
      await refreshAllData();
      return true;
    } catch (e) {
      // Eğer takımın oynadığı maçlar varsa veritabanı silmeye izin vermeyebilir.
      state = state.copyWith(errorMessage: "Takım silinemedi. Önce bu takımın maçlarını silmelisiniz. Hata: $e");
      return false;
    }
  }
  
  // İstek Reddetme (AYNI)
  Future<void> rejectRequest(String id) async {
     await supabase.from('team_requests').update({'status': 'rejected'}).eq('id', id);
     await refreshAllData();
  }

  // --- MEVCUT YARDIMCI FONKSİYONLARINI (_getMatches vb.) BURADA KORU ---
  Future<void> _getMatches() async {
    final response = await supabase
        .from('matches')
        .select('*, home_team:teams!home_team_id(name), away_team:teams!away_team_id(name)')
        .order('match_date', ascending: false);
    state = state.copyWith(matches: List<Map<String, dynamic>>.from(response));
  }

  Future<void> _getRequests() async {
    final response = await supabase
        .from('team_requests')
        .select()
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    state = state.copyWith(requests: List<Map<String, dynamic>>.from(response));
  }

  Future<void> _calculateStandings() async {
    // ... (Senin mevcut puan hesaplama kodun buraya gelecek) ...
    // Hızlıca geçiyorum, mevcut kodunu koru.
    final teamsData = await supabase.from('teams').select('id, name, logo_url');
    final matchesData = await supabase.from('matches').select().eq('status', 'finished');
    Map<String, Map<String, dynamic>> teamStats = {};
    for (var team in teamsData) {
      teamStats[team['id']] = { 'id': team['id'], 'name': team['name'], 'logo_url': team['logo_url'], 'played': 0, 'won': 0, 'drawn': 0, 'lost': 0, 'gf': 0, 'ga': 0, 'points': 0 };
    }
    for (var match in matchesData) {
      final homeId = match['home_team_id']; final awayId = match['away_team_id'];
      final homeScore = match['home_score'] as int; final awayScore = match['away_score'] as int;
      if (teamStats[homeId] == null || teamStats[awayId] == null) continue;
      teamStats[homeId]!['played'] += 1; teamStats[awayId]!['played'] += 1;
      teamStats[homeId]!['gf'] += homeScore; teamStats[homeId]!['ga'] += awayScore;
      teamStats[awayId]!['gf'] += awayScore; teamStats[awayId]!['ga'] += homeScore;
      if (homeScore > awayScore) { teamStats[homeId]!['won'] += 1; teamStats[homeId]!['points'] += 3; teamStats[awayId]!['lost'] += 1; } 
      else if (awayScore > homeScore) { teamStats[awayId]!['won'] += 1; teamStats[awayId]!['points'] += 3; teamStats[homeId]!['lost'] += 1; } 
      else { teamStats[homeId]!['drawn'] += 1; teamStats[homeId]!['points'] += 1; teamStats[awayId]!['drawn'] += 1; teamStats[awayId]!['points'] += 1; }
    }
    List<Map<String, dynamic>> sortedList = teamStats.values.toList();
    for (var team in sortedList) team['avg'] = team['gf'] - team['ga'];
    sortedList.sort((a, b) {
      int point = b['points'].compareTo(a['points']);
      return point != 0 ? point : b['avg'].compareTo(a['avg']);
    });
    state = state.copyWith(standings: sortedList);
  }

  Future<bool> approveTeam(Map<String, dynamic> request) async {
      // Mevcut kodun...
      return true; // placeholder
  }
}

final adminProvider = NotifierProvider<AdminNotifier, AdminState>(() => AdminNotifier());
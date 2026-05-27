import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:devler_ligi/main.dart'; 


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


class AdminNotifier extends Notifier<AdminState> {
  @override
  AdminState build() {
    return AdminState();
  }

  Future<void> refreshAllData() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      await Future.wait([
        _getMatches().catchError((e) {
          state = state.copyWith(errorMessage: "Maçlar alınamadı: $e");
        }),
        _calculateStandings().catchError((e) {
          state = state.copyWith(errorMessage: "Puan durumu alınamadı (Büyük ihtimalle setup_database.sql tam çalıştırılmadı): $e");
        }),
        _getRequests().catchError((e) {
          state = state.copyWith(errorMessage: "İstekler alınamadı: $e");
        }),
      ]);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  
  

  
  Future<bool> deleteMatch(String matchId) async {
    try {
      
      await supabase.from('match_goals').delete().eq('match_id', matchId);
      
      await supabase.from('matches').delete().eq('id', matchId);
      
      await refreshAllData(); 
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: "Maç silinemedi: $e");
      return false;
    }
  }

  
  Future<bool> deleteTeam(String teamId) async {
    try {
      
      await supabase.from('players').delete().eq('team_id', teamId);
      
      
      
      await supabase.from('teams').delete().eq('id', teamId);
      
      await refreshAllData();
      return true;
    } catch (e) {
      
      state = state.copyWith(errorMessage: "Takım silinemedi. Önce bu takımın maçlarını silmelisiniz. Hata: $e");
      return false;
    }
  }
  
  
  Future<void> rejectRequest(String id) async {
     await supabase.from('team_requests').update({'status': 'rejected'}).eq('id', id);
     await refreshAllData();
  }

  
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
    final response = await supabase.from('standings_view').select().order('points', ascending: false).order('avg', ascending: false);
    state = state.copyWith(standings: List<Map<String, dynamic>>.from(response));
  }

  Future<bool> approveTeam(Map<String, dynamic> request) async {
      
      return true; 
  }
}

final adminProvider = NotifierProvider<AdminNotifier, AdminState>(() => AdminNotifier());
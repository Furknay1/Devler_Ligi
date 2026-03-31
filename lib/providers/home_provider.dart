import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:devler_ligi/main.dart'; // supabase erişimi için

// State
class HomeState {
  final bool isLoading;
  final List<Map<String, dynamic>> standings;
  final List<Map<String, dynamic>> topScorers;
  final String? errorMessage;

  HomeState({
    this.isLoading = false,
    this.standings = const [],
    this.topScorers = const [],
    this.errorMessage,
  });

  HomeState copyWith({
    bool? isLoading,
    List<Map<String, dynamic>>? standings,
    List<Map<String, dynamic>>? topScorers,
    String? errorMessage,
  }) {
    return HomeState(
      isLoading: isLoading ?? this.isLoading,
      standings: standings ?? this.standings,
      topScorers: topScorers ?? this.topScorers,
      errorMessage: errorMessage,
    );
  }
}

// Notifier
class HomeNotifier extends Notifier<HomeState> {
  @override
  HomeState build() {
    return HomeState();
  }

  // Verileri Yenile
  Future<void> refreshData() async {
    state = state.copyWith(isLoading: true);
    try {
      await Future.wait([
        _calculateStandings(),
        _calculateTopScorers(),
      ]);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  // Puan Durumu Hesapla
  Future<void> _calculateStandings() async {
    final teamsData = await supabase.from('teams').select('id, name');
    final matchesData = await supabase.from('matches').select().eq('status', 'finished');

    Map<String, Map<String, dynamic>> teamStats = {};

    for (var team in teamsData) {
      teamStats[team['id']] = {
        'name': team['name'], 'played': 0, 'won': 0, 'drawn': 0, 'lost': 0,
        'gf': 0, 'ga': 0, 'points': 0,
      };
    }

    for (var match in matchesData) {
      final homeId = match['home_team_id'];
      final awayId = match['away_team_id'];
      final homeScore = match['home_score'] as int;
      final awayScore = match['away_score'] as int;

      if (teamStats[homeId] == null || teamStats[awayId] == null) continue;

      teamStats[homeId]!['played'] += 1;
      teamStats[awayId]!['played'] += 1;
      teamStats[homeId]!['gf'] += homeScore;
      teamStats[homeId]!['ga'] += awayScore;
      teamStats[awayId]!['gf'] += awayScore;
      teamStats[awayId]!['ga'] += homeScore;

      if (homeScore > awayScore) {
        teamStats[homeId]!['won'] += 1;
        teamStats[homeId]!['points'] += 3;
        teamStats[awayId]!['lost'] += 1;
      } else if (awayScore > homeScore) {
        teamStats[awayId]!['won'] += 1;
        teamStats[awayId]!['points'] += 3;
        teamStats[homeId]!['lost'] += 1;
      } else {
        teamStats[homeId]!['drawn'] += 1;
        teamStats[homeId]!['points'] += 1;
        teamStats[awayId]!['drawn'] += 1;
        teamStats[awayId]!['points'] += 1;
      }
    }

    List<Map<String, dynamic>> sortedList = teamStats.values.toList();
    for (var team in sortedList) {
      team['avg'] = team['gf'] - team['ga'];
    }
    sortedList.sort((a, b) {
      int pointCompare = b['points'].compareTo(a['points']);
      if (pointCompare != 0) return pointCompare;
      return b['avg'].compareTo(a['avg']);
    });

    state = state.copyWith(standings: sortedList);
  }

  // Gol Krallığı Hesapla
  Future<void> _calculateTopScorers() async {
    final response = await supabase
        .from('match_goals')
        .select('player_id, players(name), teams(name)');
    
    Map<String, Map<String, dynamic>> scorerStats = {};

    for (var goal in response) {
      final pid = goal['player_id'];
      final pName = goal['players'] != null ? goal['players']['name'] : 'Bilinmeyen';
      final tName = goal['teams'] != null ? goal['teams']['name'] : '';

      if (!scorerStats.containsKey(pid)) {
        scorerStats[pid] = {'name': pName, 'team': tName, 'goals': 0};
      }
      scorerStats[pid]!['goals'] += 1;
    }

    List<Map<String, dynamic>> sortedScorers = scorerStats.values.toList();
    sortedScorers.sort((a, b) => b['goals'].compareTo(a['goals']));

    state = state.copyWith(topScorers: sortedScorers);
  }
}

// Provider Tanımı
final homeProvider = NotifierProvider<HomeNotifier, HomeState>(() => HomeNotifier());
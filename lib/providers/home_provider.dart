import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:devler_ligi/main.dart'; 


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


class HomeNotifier extends Notifier<HomeState> {
  @override
  HomeState build() {
    return HomeState();
  }

  
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

  
  Future<void> _calculateStandings() async {
    final response = await supabase.from('standings_view').select();
    state = state.copyWith(standings: List<Map<String, dynamic>>.from(response));
  }

  
  Future<void> _calculateTopScorers() async {
    final response = await supabase.from('top_scorers_view').select().limit(10);
    state = state.copyWith(topScorers: List<Map<String, dynamic>>.from(response));
  }
}


final homeProvider = NotifierProvider<HomeNotifier, HomeState>(() => HomeNotifier());
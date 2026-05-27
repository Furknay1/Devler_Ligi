import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:devler_ligi/main.dart'; 
import 'package:devler_ligi/features/admin/add_match_page.dart';
import 'package:go_router/go_router.dart';
import 'package:devler_ligi/providers/admin_provider.dart';
import 'package:devler_ligi/providers/auth_provider.dart';
import 'package:devler_ligi/widgets/custom_nav_bar.dart';
import 'package:devler_ligi/widgets/team_logo.dart'; 

class AdminPanel extends ConsumerStatefulWidget {
  const AdminPanel({super.key});

  @override
  ConsumerState<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends ConsumerState<AdminPanel> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  
  final TextEditingController _newsTitleController = TextEditingController();
  final TextEditingController _newsContentController = TextEditingController();
  final TextEditingController _youtubeController = TextEditingController();
  String _newsCategory = 'genel';
  File? _newsImageFile;
  bool _isPublishingNews = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adminProvider.notifier).refreshAllData();
    });
  }

  
  Future<void> _confirmDelete({
    required String title, 
    required String content, 
    required VoidCallback onConfirm
  }) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text("İPTAL", style: TextStyle(color: Colors.grey))
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("SİL", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  
  Future<void> _handleLogout() async {
    await ref.read(authProvider.notifier).signOut();
    if (mounted) {
      context.go('/');
    }
  }

  
  Future<void> _showTeamPlayersDialog(Map<String, dynamic> team) async {
    final teamName = team['name'] ?? team['team_name'] ?? 'İsimsiz Takım';
    final teamId = team['id'] ?? team['team_id'];
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("$teamName Kadrosu", style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: FutureBuilder(
              future: supabase.from('players').select().eq('team_id', teamId).order('number', ascending: true),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError) return Text("Hata: ${snapshot.error}");
                
                final players = snapshot.data as List<dynamic>? ?? [];
                if (players.isEmpty) return const Text("Bu takımda henüz oyuncu yok.", style: TextStyle(color: Colors.grey));
                
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: players.length,
                  itemBuilder: (context, idx) {
                    final p = players[idx];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(backgroundColor: Colors.blueAccent.withOpacity(0.2), child: Text("${p['number'] ?? '?'}", style: const TextStyle(fontWeight: FontWeight.bold))),
                        title: Text(p['name'] ?? 'İsimsiz', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(p['position'] ?? 'Mevki Belirtilmedi'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            _confirmDelete(
                              title: "Oyuncu Sil",
                              content: "${p['name']} isimli oyuncuyu takımdan çıkarmak üzeresin.",
                              onConfirm: () async {
                                await supabase.from('players').delete().eq('id', p['id']);
                                if (context.mounted) Navigator.pop(context); 
                                _showTeamPlayersDialog(team); 
                              }
                            );
                          }
                        ),
                      ),
                    );
                  }
                );
              }
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Kapat")),
          ]
        );
      }
    );
  }

  
  Future<void> _approveTeamRequest(Map<String, dynamic> req) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final leagueData = await supabase.from('leagues').select('id').limit(1).single();
      
      final insertedTeam = await supabase.from('teams').insert({
        'name': req['team_name'],
        'short_name': req['short_name'],
        'logo_url': req['logo_url'],
        'owner_id': req['user_id'],
        'league_id': leagueData['id'],
      }).select().single();
      
      
      final ownerProfile = await supabase.from('profiles').select('username, full_name').eq('id', req['user_id']).maybeSingle();
      final String ownerName = (ownerProfile?['username'] as String?) ?? (ownerProfile?['full_name'] as String?) ?? 'Kaptan';

      await supabase.from('players').insert({
        'profile_id': req['user_id'],
        'team_id': insertedTeam['id'],
        'name': ownerName,
        'position': 'KAPTAN',
        'number': 10
      });
      
      await supabase.from('team_requests').update({'status': 'approved'}).eq('id', req['id']);
      
      messenger.showSnackBar(const SnackBar(content: Text("✅ Takım Onaylandı!")));
      ref.read(adminProvider.notifier).refreshAllData();
      
    } catch(e) {
      messenger.showSnackBar(SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red));
    }
  }

  
  Future<void> _showScoreDialog(Map<String, dynamic> match) async {
    
    final homePlayersData = await supabase.from('players').select().eq('team_id', match['home_team_id']);
    final awayPlayersData = await supabase.from('players').select().eq('team_id', match['away_team_id']);

    final homePlayers = List<Map<String, dynamic>>.from(homePlayersData);
    final awayPlayers = List<Map<String, dynamic>>.from(awayPlayersData);

    
    List<Map<String, String?>> homeGoals = [];
    List<Map<String, String?>> awayGoals = [];
    
    List<Map<String, String>> homeCards = [];
    List<Map<String, String>> awayCards = [];

    
    List<Map<String, dynamic>> homeRatings = homePlayers.map((p) => {'player_id': p['id'], 'rating': null}).toList();
    List<Map<String, dynamic>> awayRatings = awayPlayers.map((p) => {'player_id': p['id'], 'rating': null}).toList();

    int homeScore = match['home_score'] ?? 0;
    int awayScore = match['away_score'] ?? 0;

    
    for (int i = 0; i < homeScore; i++) {
      homeGoals.add({'scorer': null, 'assist': null});
    }
    for (int i = 0; i < awayScore; i++) {
      awayGoals.add({'scorer': null, 'assist': null});
    }

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text("Maç Detayları"),
            content: SizedBox(
              width: double.maxFinite,
              height: 500, 
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildScoreCounter(match['home_team']['name'], homeScore, (val) {
                          setStateDialog(() {
                            homeScore = val;
                            if (val > homeGoals.length) homeGoals.add({'scorer': null, 'assist': null});
                            if (val < homeGoals.length) homeGoals.removeLast();
                          });
                        }),
                        const Padding(padding: EdgeInsets.symmetric(horizontal: 15), child: Text("-", style: TextStyle(fontSize: 30))),
                        _buildScoreCounter(match['away_team']['name'], awayScore, (val) {
                          setStateDialog(() {
                            awayScore = val;
                            if (val > awayGoals.length) awayGoals.add({'scorer': null, 'assist': null});
                            if (val < awayGoals.length) awayGoals.removeLast();
                          });
                        }),
                      ],
                    ),
                    const Divider(),
                    
                    
                    DefaultTabController(
                      length: 3,
                      child: Column(
                        children: [
                          const TabBar(
                            labelColor: Colors.black,
                            unselectedLabelColor: Colors.grey,
                            indicatorColor: Colors.redAccent,
                            tabs: [Tab(text: "GOLLER & ASİST"), Tab(text: "KARTLAR"), Tab(text: "REYTİNG")],
                          ),
                          SizedBox(
                            height: 300,
                            child: TabBarView(
                              children: [
                                
                                ListView(
                                  children: [
                                    if (homeScore > 0) ...[
                                      Text("${match['home_team']['name']} Golleri", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                                      ...List.generate(homeGoals.length, (index) => _buildGoalInput(index, homePlayers, homeGoals, setStateDialog)),
                                    ],
                                    const SizedBox(height: 10),
                                    if (awayScore > 0) ...[
                                      Text("${match['away_team']['name']} Golleri", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                                      ...List.generate(awayGoals.length, (index) => _buildGoalInput(index, awayPlayers, awayGoals, setStateDialog)),
                                    ],
                                  ],
                                ),

                                
                                ListView(
                                  children: [
                                    _buildCardAdder(match['home_team']['name'], homePlayers, homeCards, setStateDialog, Colors.blue),
                                    const Divider(),
                                    _buildCardAdder(match['away_team']['name'], awayPlayers, awayCards, setStateDialog, Colors.red),
                                  ],
                                ),

                                
                                ListView(
                                  children: [
                                    Text("${match['home_team']['name']} Reytingleri", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                                    ...List.generate(homePlayers.length, (index) => _buildRatingSlider(homePlayers[index]['name'], index, homeRatings, setStateDialog)),
                                    const Divider(),
                                    Text("${match['away_team']['name']} Reytingleri", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                                    ...List.generate(awayPlayers.length, (index) => _buildRatingSlider(awayPlayers[index]['name'], index, awayRatings, setStateDialog)),
                                  ],
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal")),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _saveMatchResult(match, homeScore, awayScore, homeGoals, awayGoals, homeCards, awayCards, homeRatings, awayRatings);
                },
                child: const Text("KAYDET & BİTİR"),
              ),
            ],
          );
        },
      ),
    );
  }

  
  Widget _buildScoreCounter(String teamName, int score, Function(int) onChange) {
    return Column(
      children: [
        Text(teamName, style: const TextStyle(fontWeight: FontWeight.bold)),
        Row(
          children: [
            IconButton(icon: const Icon(Icons.remove_circle, color: Colors.red), onPressed: () => score > 0 ? onChange(score - 1) : null),
            Text("$score", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            IconButton(icon: const Icon(Icons.add_circle, color: Colors.green), onPressed: () => onChange(score + 1)),
          ],
        ),
      ],
    );
  }

  
  Widget _buildRatingSlider(String playerName, int index, List<Map<String, dynamic>> ratingList, StateSetter setStateDialog) {
    double currentVal = ratingList[index]['rating'] ?? 6.0;
    return Row(
      children: [
        SizedBox(width: 80, child: Text(playerName, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
        Expanded(
          child: Slider(
            value: currentVal,
            min: 1.0,
            max: 10.0,
            divisions: 90,
            activeColor: currentVal >= 8 ? Colors.green : (currentVal < 5 ? Colors.red : Colors.orange),
            onChanged: (val) {
              setStateDialog(() {
                ratingList[index]['rating'] = val;
              });
            },
          )
        ),
        Text(currentVal.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold)),
      ]
    );
  }

  
  Widget _buildGoalInput(int index, List players, List<Map<String, String?>> goalList, StateSetter setStateDialog) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("${index + 1}. Gol", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    hint: const Text("Atan"),
                    value: goalList[index]['scorer'],
                    items: players.map<DropdownMenuItem<String>>((p) => DropdownMenuItem(value: p['id'].toString(), child: Text("${p['number']} - ${p['name']}"))).toList(),
                    onChanged: (val) => setStateDialog(() => goalList[index]['scorer'] = val),
                  ),
                ),
                const SizedBox(width: 5),
                const Icon(Icons.handshake, size: 16, color: Colors.grey),
                const SizedBox(width: 5),
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    hint: const Text("Asist"),
                    value: goalList[index]['assist'],
                    items: [
                      const DropdownMenuItem(value: null, child: Text("Yok")),
                      
                      ...players.map<DropdownMenuItem<String>>((p) => DropdownMenuItem(value: p['id'].toString(), child: Text("${p['number']} - ${p['name']}"))),
                    ],
                    onChanged: (val) => setStateDialog(() => goalList[index]['assist'] = val),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  
  Widget _buildCardAdder(String teamName, List players, List<Map<String, String>> cardList, StateSetter setStateDialog, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("$teamName Kartları", style: TextStyle(fontWeight: FontWeight.bold, color: color)),
            IconButton(
              icon: const Icon(Icons.add_box, color: Colors.grey),
              tooltip: "Kart Ekle",
              onPressed: () {
                if (players.isNotEmpty) {
                  setStateDialog(() {
                    cardList.add({'player': players.first['id'], 'type': 'yellow'});
                  });
                }
              },
            )
          ],
        ),
        ...List.generate(cardList.length, (index) {
          return Row(
            children: [
              Expanded(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: cardList[index]['player'],
                  items: players.map<DropdownMenuItem<String>>((p) => DropdownMenuItem(value: p['id'].toString(), child: Text("${p['number']} - ${p['name']}"))).toList(),
                  onChanged: (val) => setStateDialog(() => cardList[index]['player'] = val!),
                ),
              ),
              const SizedBox(width: 10),
              ToggleButtons(
                constraints: const BoxConstraints(minHeight: 30, minWidth: 30),
                isSelected: [cardList[index]['type'] == 'yellow', cardList[index]['type'] == 'red'],
                onPressed: (int idx) {
                  setStateDialog(() => cardList[index]['type'] = idx == 0 ? 'yellow' : 'red');
                },
                children: const [
                  Padding(padding: EdgeInsets.all(4), child: Icon(Icons.stop, color: Colors.yellow)),
                  Padding(padding: EdgeInsets.all(4), child: Icon(Icons.stop, color: Colors.red)),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.grey, size: 20),
                onPressed: () => setStateDialog(() => cardList.removeAt(index)),
              )
            ],
          );
        })
      ],
    );
  }

  
  Future<void> _saveMatchResult(
    Map match, 
    int hScore, 
    int aScore, 
    List<Map<String, String?>> hGoals, 
    List<Map<String, String?>> aGoals,
    List<Map<String, String>> hCards,
    List<Map<String, String>> aCards,
    List<Map<String, dynamic>> hRatings,
    List<Map<String, dynamic>> aRatings
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      
      await supabase.from('matches').update({
        'home_score': hScore,
        'away_score': aScore,
        'status': 'finished'
      }).eq('id', match['id']);

      
      await supabase.from('match_goals').delete().eq('match_id', match['id']);
      await supabase.from('match_cards').delete().eq('match_id', match['id']);

      
      List<Map<String, dynamic>> goalsToInsert = [];
      
      for (var g in hGoals) {
        if (g['scorer'] != null) {
          goalsToInsert.add({
            'match_id': match['id'],
            'team_id': match['home_team_id'],
            'player_id': g['scorer'],
            'assist_player_id': g['assist']
          });
        }
      }
      
      for (var g in aGoals) {
        if (g['scorer'] != null) {
          goalsToInsert.add({
            'match_id': match['id'],
            'team_id': match['away_team_id'],
            'player_id': g['scorer'],
            'assist_player_id': g['assist']
          });
        }
      }

      
      List<Map<String, dynamic>> cardsToInsert = [];
      for (var c in hCards) {
        cardsToInsert.add({
          'match_id': match['id'], 'team_id': match['home_team_id'], 'player_id': c['player'], 'card_type': c['type']
        });
      }
      for (var c in aCards) {
        cardsToInsert.add({
          'match_id': match['id'], 'team_id': match['away_team_id'], 'player_id': c['player'], 'card_type': c['type']
        });
      }

      
      List<Map<String, dynamic>> ratingsToInsert = [];
      for(var r in hRatings) {
         if (r['rating'] != null) {
            ratingsToInsert.add({'match_id': match['id'], 'player_id': r['player_id'], 'rating': r['rating']});
         }
      }
      for(var r in aRatings) {
         if (r['rating'] != null) {
            ratingsToInsert.add({'match_id': match['id'], 'player_id': r['player_id'], 'rating': r['rating']});
         }
      }

      await supabase.from('match_player_stats').delete().eq('match_id', match['id']);

      
      if (goalsToInsert.isNotEmpty) await supabase.from('match_goals').insert(goalsToInsert);
      if (cardsToInsert.isNotEmpty) await supabase.from('match_cards').insert(cardsToInsert);
      if (ratingsToInsert.isNotEmpty) await supabase.from('match_player_stats').insert(ratingsToInsert);

      messenger.showSnackBar(const SnackBar(content: Text("✅ Maç Detayları Kaydedildi!")));
      
      if (mounted) ref.read(adminProvider.notifier).refreshAllData();

    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final adminState = ref.watch(adminProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          const CustomNavBar(showBackButton: false),
          Container(
            color: const Color(0xFF06283D),
            child: Row(
              children: [
                Expanded(
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.redAccent,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white60,
                    tabs: const [
                      Tab(text: "MAÇLAR"),
                      Tab(text: "PUANLAR"),
                      Tab(text: "İSTEKLER"),
                      Tab(text: "FESİH"),
                      Tab(text: "HABERLER"),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: () => ref.read(adminProvider.notifier).refreshAllData(),
                ),
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.redAccent),
                  onPressed: _handleLogout,
                ),
                const SizedBox(width: 10),
              ],
            ),
          ),
          Expanded(
            child: adminState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildMatchesTab(adminState.matches),   
                      _buildStandingsTab(adminState.standings), 
                      _buildRequestsTab(adminState.requests),
                      _buildDissolutionTab(),
                      _buildNewsTab(),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await context.push<bool>('/admin/add-match');
          if (result == true && mounted) {
            ref.read(adminProvider.notifier).refreshAllData();
          }
        },
        backgroundColor: Colors.redAccent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  

  Widget _buildMatchesTab(List<Map<String, dynamic>> matches) {
    if (matches.isEmpty) return const Center(child: Text("Henüz maç yok."));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: matches.length,
      itemBuilder: (context, index) {
        final match = matches[index];
        final isFinished = match['status'] == 'finished';
        final homeName = match['home_team']?['name'] ?? 'A';
        final awayName = match['away_team']?['name'] ?? 'B';

        return Card(
          child: ListTile(
            leading: Icon(isFinished ? Icons.check_circle : Icons.schedule, color: isFinished ? Colors.green : Colors.orange),
            title: Text("$homeName vs $awayName", style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(match['match_date'].toString().substring(0, 16).replaceAll('T', ' ')),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(isFinished ? "${match['home_score']}-${match['away_score']}" : "- -", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(width: 10),
                IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showScoreDialog(match)),
                
                
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red), 
                  onPressed: () {
                    _confirmDelete(
                      title: "Maçı Sil",
                      content: "Bu maçı ve atılan golleri silmek istediğine emin misin?",
                      onConfirm: () async {
                         
                         final messenger = ScaffoldMessenger.of(context);
                         final success = await ref.read(adminProvider.notifier).deleteMatch(match['id']);
                         if (mounted && success) {
                           messenger.showSnackBar(const SnackBar(content: Text("🗑️ Maç silindi.")));
                         }
                      }
                    );
                  }
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStandingsTab(List<Map<String, dynamic>> standings) {
    if (standings.isEmpty) return const Center(child: Text("Puan durumu hesaplanamadı."));
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          color: Colors.grey.shade200,
          child: const Row(
            children: [
              SizedBox(width: 30, child: Text("#", style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(flex: 3, child: Text("Takım", style: TextStyle(fontWeight: FontWeight.bold))),
              SizedBox(width: 30, child: Text("O", style: TextStyle(fontWeight: FontWeight.bold))),
              SizedBox(width: 30, child: Text("G", style: TextStyle(fontWeight: FontWeight.bold))),
              SizedBox(width: 30, child: Text("B", style: TextStyle(fontWeight: FontWeight.bold))),
              SizedBox(width: 30, child: Text("M", style: TextStyle(fontWeight: FontWeight.bold))),
              SizedBox(width: 35, child: Text("Av", style: TextStyle(fontWeight: FontWeight.bold))),
              SizedBox(width: 35, child: Text("P", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red))),
              SizedBox(width: 30),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: standings.length,
            separatorBuilder: (c, i) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final team = standings[index];
              return InkWell(
                onTap: () => _showTeamPlayersDialog(team),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  color: index < 4 ? Colors.green.shade50 : Colors.white,
                  child: Row(
                  children: [
                    SizedBox(width: 30, child: Text("${index + 1}.")),
                    Expanded(flex: 3, child: Text(team['name'] ?? team['team_name'] ?? 'İsimsiz', style: const TextStyle(fontWeight: FontWeight.w500))),
                    SizedBox(width: 30, child: Text("${team['played']}")),
                    SizedBox(width: 30, child: Text("${team['won']}", style: const TextStyle(color: Colors.green))),
                    SizedBox(width: 30, child: Text("${team['drawn']}", style: const TextStyle(color: Colors.grey))),
                    SizedBox(width: 30, child: Text("${team['lost']}", style: const TextStyle(color: Colors.red))),
                    SizedBox(width: 35, child: Text("${team['avg']}")),
                    SizedBox(width: 35, child: Text("${team['points']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red))),
                    
                    
                    SizedBox(
                      width: 30,
                      child: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          _confirmDelete(
                            title: "Takımı Sil",
                            content: "${team['name'] ?? team['team_name']} takımını silmek üzeresin. Bu işlem geri alınamaz.",
                            onConfirm: () async {
                               
                               final messenger = ScaffoldMessenger.of(context);
                               final teamId = team['id'] ?? team['team_id'];
                               final success = await ref.read(adminProvider.notifier).deleteTeam(teamId);
                               if (mounted && success) {
                                 messenger.showSnackBar(const SnackBar(content: Text("🗑️ Takım silindi.")));
                               } else if (mounted) {
                                 final err = ref.read(adminProvider).errorMessage;
                                 messenger.showSnackBar(SnackBar(content: Text(err ?? "Hata"), backgroundColor: Colors.red));
                               }
                            }
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          ),
        ),
      ],
    );
  }

  Widget _buildRequestsTab(List<Map<String, dynamic>> requests) {
    if (requests.isEmpty) return const Center(child: Text("Bekleyen istek yok."));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final req = requests[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: TeamLogo(url: req['logo_url'], size: 50),
            title: Text(req['team_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("Kısaltma: ${req['short_name']}"),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.check_circle, color: Colors.green), onPressed: () => _approveTeamRequest(req)),
                IconButton(icon: const Icon(Icons.cancel, color: Colors.red), onPressed: () => ref.read(adminProvider.notifier).rejectRequest(req['id'])),
              ],
            ),
          ),
        );
      },
    );
  }

  
  Widget _buildDissolutionTab() {
    return FutureBuilder(
      future: supabase
          .from('dissolution_requests')
          .select('*, teams(name, logo_url, short_name)')
          .eq('status', 'pending')
          .order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Hata: ${snapshot.error}"));
        }
        final requests = snapshot.data as List<dynamic>? ?? [];
        if (requests.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.gavel, size: 60, color: Colors.grey),
                SizedBox(height: 12),
                Text("Bekleyen fesih talebi yok.",
                    style: TextStyle(color: Colors.grey, fontSize: 16)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final req = Map<String, dynamic>.from(requests[index]);
            final team = req['teams'] as Map<String, dynamic>? ?? {};
            final teamName = team['name'] ?? 'İsimsiz Takım';
            final logoUrl = team['logo_url'] as String?;
            final createdAt = (req['created_at'] as String).substring(0, 16).replaceAll('T', ' ');

            return Card(
              margin: const EdgeInsets.only(bottom: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        TeamLogo(url: logoUrl, size: 50),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(teamName.toString().toUpperCase(),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 16)),
                              Text("Talep: $createdAt",
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.orange),
                          ),
                          child: const Text("BEKLEMEDE",
                              style: TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11)),
                        )
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              await supabase
                                  .from('dissolution_requests')
                                  .update({'status': 'rejected'})
                                  .eq('id', req['id']);
                              if (mounted) setState(() {});
                            },
                            icon: const Icon(Icons.close, color: Colors.red),
                            label: const Text("REDDET",
                                style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              _confirmDelete(
                                title: "Fesih Onayla",
                                content:
                                    "'$teamName' takımını feshetmek istediğine emin misin? Takım ve tüm oyuncular silinecek.",
                                onConfirm: () async {
                                  final messenger =
                                      ScaffoldMessenger.of(context);
                                  try {
                                    final teamId = req['team_id'];
                                    
                                    await supabase
                                        .from('players')
                                        .delete()
                                        .eq('team_id', teamId);
                                    await supabase
                                        .from('teams')
                                        .delete()
                                        .eq('id', teamId);
                                    await supabase
                                        .from('dissolution_requests')
                                        .update({'status': 'approved'})
                                        .eq('id', req['id']);
                                    if (mounted) {
                                      setState(() {});
                                      messenger.showSnackBar(const SnackBar(
                                          content: Text(
                                              "✅ Takım feshi onaylandı ve takım silindi."),
                                          backgroundColor: Colors.green));
                                      ref
                                          .read(adminProvider.notifier)
                                          .refreshAllData();
                                    }
                                  } catch (e) {
                                    messenger.showSnackBar(SnackBar(
                                        content: Text("Hata: $e"),
                                        backgroundColor: Colors.red));
                                  }
                                },
                              );
                            },
                            icon: const Icon(Icons.check, color: Colors.white),
                            label: const Text("FESHİ ONAYLA",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  
  Widget _buildNewsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("📰 YENİ BÜLTEN / HABER OLUŞTUR", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: "Kategori", border: OutlineInputBorder()),
                    value: _newsCategory,
                    items: const [
                      DropdownMenuItem(value: 'genel', child: Text("Genel Duyuru")),
                      DropdownMenuItem(value: 'haftanin_11i', child: Text("Haftanın 11'i")),
                      DropdownMenuItem(value: 'haftanin_oyuncusu', child: Text("Haftanın Oyuncusu")),
                      DropdownMenuItem(value: 'video', child: Text("Video (YouTube)")),
                    ],
                    onChanged: (val) => setState(() => _newsCategory = val!),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _newsTitleController,
                    decoration: const InputDecoration(labelText: "Haber Başlığı", border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _newsContentController,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: "İçerik (İsteğe Bağlı)", border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  
                  if (_newsCategory == 'video')
                    TextField(
                      controller: _youtubeController,
                      decoration: const InputDecoration(
                        labelText: "YouTube Linki (Örn: https://youtube.com/watch?v=...)", 
                        border: OutlineInputBorder(), 
                        prefixIcon: Icon(Icons.video_library, color: Colors.red)
                      ),
                    )
                  else ...[
                    
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () async {
                            final picker = ImagePicker();
                            final picked = await picker.pickImage(source: ImageSource.gallery);
                            if (picked != null) {
                              setState(() => _newsImageFile = File(picked.path));
                            }
                          }, 
                          icon: const Icon(Icons.image), 
                          label: const Text("Görsel Yükle (İsteğe Bağlı)")
                        ),
                        const SizedBox(width: 16),
                        if (_newsImageFile != null) ...[
                          const Icon(Icons.check_circle, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_newsImageFile!.path.split(Platform.pathSeparator).last, overflow: TextOverflow.ellipsis)),
                          IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => setState(()=> _newsImageFile = null))
                        ] else 
                          const Text("Görsel seçilmedi", style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                    if (_newsImageFile != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Image.file(_newsImageFile!, height: 200, fit: BoxFit.contain),
                      ),
                  ],
                  
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isPublishingNews ? null : _publishNews,
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF06283D)),
                      child: _isPublishingNews 
                        ? const CircularProgressIndicator(color: Colors.white) 
                        : const Text("HABERİ YAYINLA", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      )
    );
  }

  Future<void> _publishNews() async {
    if (_newsTitleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen bir başlık girin.")));
      return;
    }
    
    if (_newsCategory == 'video' && _youtubeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen Youtube linkini girin.")));
      return;
    }

    setState(() => _isPublishingNews = true);
    final messenger = ScaffoldMessenger.of(context);
    
    try {
      String? uploadedImageUrl;
      if (_newsCategory != 'video' && _newsImageFile != null) {
        final fileName = 'news_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await supabase.storage.from('news_images').upload(fileName, _newsImageFile!);
        uploadedImageUrl = supabase.storage.from('news_images').getPublicUrl(fileName);
      }
      
      await supabase.from('news_feed').insert({
        'title': _newsTitleController.text,
        'content': _newsContentController.text,
        'category': _newsCategory,
        'image_url': uploadedImageUrl,
        'youtube_url': _newsCategory == 'video' ? _youtubeController.text : null,
        'author_id': supabase.auth.currentUser!.id,
      });
      
      messenger.showSnackBar(const SnackBar(content: Text("✅ Haber başarıyla yayınlandı!"), backgroundColor: Colors.green));
      
      
      setState(() {
        _newsTitleController.clear();
        _newsContentController.clear();
        _youtubeController.clear();
        _newsImageFile = null;
        _isPublishingNews = false;
        
      });
      
    } catch(e) {
      setState(() => _isPublishingNews = false);
      messenger.showSnackBar(SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red));
    }
  }

}
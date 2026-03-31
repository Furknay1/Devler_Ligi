import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:devler_ligi/main.dart'; 
import 'package:devler_ligi/features/auth/login_page.dart';
import 'package:devler_ligi/features/admin/add_match_page.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Verileri yükle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adminProvider.notifier).refreshAllData();
    });
  }

  // --- SİLME ONAY PENCERESİ ---
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

  // --- LOGOUT İŞLEMİ ---
  Future<void> _handleLogout() async {
    await ref.read(authProvider.notifier).signOut();
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
    }
  }

  // --- TAKIM ONAYLAMA ---
  Future<void> _approveTeamRequest(Map<String, dynamic> req) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final leagueData = await supabase.from('leagues').select('id').limit(1).single();
      
      await supabase.from('teams').insert({
        'name': req['team_name'],
        'short_name': req['short_name'],
        'logo_url': req['logo_url'],
        'owner_id': req['user_id'],
        'league_id': leagueData['id'],
      });
      
      await supabase.from('team_requests').update({'status': 'approved'}).eq('id', req['id']);
      
      messenger.showSnackBar(const SnackBar(content: Text("✅ Takım Onaylandı!")));
      ref.read(adminProvider.notifier).refreshAllData();
      
    } catch(e) {
      messenger.showSnackBar(SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red));
    }
  }

  // --- YENİLENMİŞ DETAYLI SKOR DİYALOĞU ---
  Future<void> _showScoreDialog(Map<String, dynamic> match) async {
    // 1. Oyuncuları Çek
    final homePlayersData = await supabase.from('players').select().eq('team_id', match['home_team_id']);
    final awayPlayersData = await supabase.from('players').select().eq('team_id', match['away_team_id']);

    final homePlayers = List<Map<String, dynamic>>.from(homePlayersData);
    final awayPlayers = List<Map<String, dynamic>>.from(awayPlayersData);

    // 2. Veri Tutucular
    List<Map<String, String?>> homeGoals = [];
    List<Map<String, String?>> awayGoals = [];
    
    List<Map<String, String>> homeCards = [];
    List<Map<String, String>> awayCards = [];

    int homeScore = match['home_score'] ?? 0;
    int awayScore = match['away_score'] ?? 0;

    // Gol Listelerini Başlat (Düzeltme: Süslü parantezler eklendi)
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
                    // --- SKOR TABELASI ---
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
                    
                    // --- SEKMELİ YAPI ---
                    DefaultTabController(
                      length: 2,
                      child: Column(
                        children: [
                          const TabBar(
                            labelColor: Colors.black,
                            unselectedLabelColor: Colors.grey,
                            indicatorColor: Colors.redAccent,
                            tabs: [Tab(text: "GOLLER & ASİST"), Tab(text: "KARTLAR")],
                          ),
                          SizedBox(
                            height: 300,
                            child: TabBarView(
                              children: [
                                // 1. GOLLER SEKME İÇERİĞİ
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

                                // 2. KARTLAR SEKME İÇERİĞİ
                                ListView(
                                  children: [
                                    _buildCardAdder(match['home_team']['name'], homePlayers, homeCards, setStateDialog, Colors.blue),
                                    const Divider(),
                                    _buildCardAdder(match['away_team']['name'], awayPlayers, awayCards, setStateDialog, Colors.red),
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
                  await _saveMatchResult(match, homeScore, awayScore, homeGoals, awayGoals, homeCards, awayCards);
                },
                child: const Text("KAYDET & BİTİR"),
              ),
            ],
          );
        },
      ),
    );
  }

  // Skor Arttır/Azalt Widget'ı
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

  // Gol ve Asist Seçimi Widget'ı
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
                      // Düzeltme: .toList() kaldırıldı
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

  // Kart Ekleme Paneli Widget'ı
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

  // --- GELİŞMİŞ KAYDETME FONKSİYONU ---
  Future<void> _saveMatchResult(
    Map match, 
    int hScore, 
    int aScore, 
    List<Map<String, String?>> hGoals, 
    List<Map<String, String?>> aGoals,
    List<Map<String, String>> hCards,
    List<Map<String, String>> aCards
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      // 1. Maç Skorunu Güncelle
      await supabase.from('matches').update({
        'home_score': hScore,
        'away_score': aScore,
        'status': 'finished'
      }).eq('id', match['id']);

      // 2. Eski Verileri Temizle
      await supabase.from('match_goals').delete().eq('match_id', match['id']);
      await supabase.from('match_cards').delete().eq('match_id', match['id']);

      // 3. Golleri Hazırla
      List<Map<String, dynamic>> goalsToInsert = [];
      // Ev Sahibi
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
      // Deplasman
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

      // 4. Kartları Hazırla
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

      // 5. Veritabanına Yaz
      if (goalsToInsert.isNotEmpty) await supabase.from('match_goals').insert(goalsToInsert);
      if (cardsToInsert.isNotEmpty) await supabase.from('match_cards').insert(cardsToInsert);

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
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddMatchPage()));
          if (result == true && mounted) {
            ref.read(adminProvider.notifier).refreshAllData();
          }
        },
        backgroundColor: Colors.redAccent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // --- TABLO GÖRÜNÜMLERİ ---

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
                
                // --- MAÇ SİLME BUTONU ---
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red), 
                  onPressed: () {
                    _confirmDelete(
                      title: "Maçı Sil",
                      content: "Bu maçı ve atılan golleri silmek istediğine emin misin?",
                      onConfirm: () async {
                         // Düzeltme: Context güvenliği
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
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                color: index < 4 ? Colors.green.shade50 : Colors.white,
                child: Row(
                  children: [
                    SizedBox(width: 30, child: Text("${index + 1}.")),
                    Expanded(flex: 3, child: Text(team['name'], style: const TextStyle(fontWeight: FontWeight.w500))),
                    SizedBox(width: 30, child: Text("${team['played']}")),
                    SizedBox(width: 30, child: Text("${team['won']}", style: const TextStyle(color: Colors.green))),
                    SizedBox(width: 30, child: Text("${team['drawn']}", style: const TextStyle(color: Colors.grey))),
                    SizedBox(width: 30, child: Text("${team['lost']}", style: const TextStyle(color: Colors.red))),
                    SizedBox(width: 35, child: Text("${team['avg']}")),
                    SizedBox(width: 35, child: Text("${team['points']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red))),
                    
                    // --- TAKIM SİLME BUTONU ---
                    SizedBox(
                      width: 30,
                      child: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          _confirmDelete(
                            title: "Takımı Sil",
                            content: "${team['name']} takımını silmek üzeresin. Bu işlem geri alınamaz.",
                            onConfirm: () async {
                               // Düzeltme: Context güvenliği
                               final messenger = ScaffoldMessenger.of(context);
                               final success = await ref.read(adminProvider.notifier).deleteTeam(team['id']);
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
}
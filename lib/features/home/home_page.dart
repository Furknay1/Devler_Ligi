import 'package:flutter/material.dart';
import 'package:devler_ligi/main.dart'; 
import 'package:devler_ligi/features/auth/welcome_dashboard.dart';
import 'package:devler_ligi/features/home/my_team_page.dart';
import 'package:devler_ligi/widgets/custom_nav_bar.dart';
import 'package:devler_ligi/widgets/team_logo.dart'; 
import 'package:devler_ligi/widgets/player_profile_dialog.dart';
import 'package:devler_ligi/features/home/team_detail_page.dart';
import 'package:devler_ligi/widgets/news_detail_dialog.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:devler_ligi/widgets/custom_footer.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _selectedMenu = "HABERLER";
  bool isLoading = true;

  
  List<Map<String, dynamic>> standings = [];
  List<Map<String, dynamic>> topScorers = [];
  List<Map<String, dynamic>> topAssists = [];
  Map<int, List<Map<String, dynamic>>> fixture = {};
  List<Map<String, dynamic>> _newsList = [];
  List<Map<String, dynamic>> _leagues = [];
  String? _selectedStatLeagueId;

  
  List<Map<String, dynamic>> _allPlayers = [];
  List<Map<String, dynamic>> _filteredPlayers = [];
  List<Map<String, dynamic>> _sentOffers = [];
  List<Map<String, dynamic>> _myPendingOffers = [];
  Map<String, dynamic>? _myTeamData;
  bool _marketLoading = false;
  final _nameFilter = TextEditingController();
  String? _positionFilter;
  String? _teamFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthAndLoad();
    });
  }

  Future<void> _checkAuthAndLoad() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (mounted) context.go('/');
    } else {
      _refreshData();
    }
  }

  Future<void> _refreshData() async {
    setState(() => isLoading = true);
    await _loadLeagues();
    await Future.wait([
      _calculateStandings(),
      _calculatePlayerStats(),
      _getFixture(),
      _loadMyTeamAndOffers(),
      _loadNews(),
    ]);
    if (mounted) setState(() => isLoading = false);
  }

  Future<void> _loadNews() async {
    try {
      final response = await supabase.from('news_feed').select().order('created_at', ascending: false);
      setState(() {
        _newsList = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      debugPrint('News load error: $e');
    }
  }

  Future<void> _loadLeagues() async {
    try {
      final res = await supabase.from('leagues').select().order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _leagues = List<Map<String, dynamic>>.from(res);
          if (_leagues.isNotEmpty && _selectedStatLeagueId == null) {
            _selectedStatLeagueId = _leagues.first['id']?.toString();
          }
        });
      }
    } catch (e) {
      debugPrint("Ligleri çekerken hata: $e");
    }
  }

  Future<void> _loadMyTeamAndOffers() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final teamData = await supabase
          .from('teams')
          .select('id, name, owner_id')
          .eq('owner_id', userId)
          .limit(1)
          .maybeSingle();
      _myTeamData = teamData;
      final offersData = await supabase
          .from('transfer_requests')
          .select('*, teams(name, logo_url)')
          .eq('profile_id', userId)
          .eq('status', 'pending');
      _myPendingOffers = List<Map<String, dynamic>>.from(offersData);
    } catch (e) {
      debugPrint('Team/offers load error: $e');
    }
  }

  Future<void> _loadMarket() async {
    if (_marketLoading) return;
    setState(() => _marketLoading = true);
    try {
      final profilesData = await supabase
          .from('profiles')
          .select('id, username, full_name, short_id, avatar_url, preferred_position');
      final playersData = await supabase
          .from('players')
          .select('id, name, position, number, team_id, profile_id, teams(name, logo_url)');
      if (_myTeamData != null) {
        final sentData = await supabase
            .from('transfer_requests')
            .select('profile_id, status')
            .eq('team_id', _myTeamData!['id'])
            .eq('status', 'pending');
        _sentOffers = List<Map<String, dynamic>>.from(sentData);
      }

      
      final myTeamId = _myTeamData?['id'] as String?;
      final myTeamPlayerProfileIds = myTeamId != null
          ? playersData
              .where((p) => p['team_id']?.toString() == myTeamId)
              .map((p) => p['profile_id']?.toString())
              .whereType<String>()
              .toSet()
          : <String>{};

      final List<Map<String, dynamic>> combined = [];
      final registeredProfileIds = playersData
          .where((p) => p['profile_id'] != null)
          .map((p) => p['profile_id'].toString())
          .toSet();
      final currentUserId = supabase.auth.currentUser?.id;

      for (final profile in profilesData) {
        final pid = profile['id'].toString();
        
        if (myTeamPlayerProfileIds.contains(pid)) continue;
        if (pid == currentUserId && myTeamId != null) continue;
        if (!registeredProfileIds.contains(pid)) {
          combined.add({
            'profile_id': pid,
            'name': profile['username'] ?? profile['full_name'] ?? 'Isimsiz',
            'position': profile['preferred_position'],
            'number': null,
            'team_name': null,
            'team_logo': null,
            'is_free': true,
          });
        }
      }
      for (final player in playersData) {
        final pid = player['profile_id']?.toString();
        
        if (myTeamId != null && player['team_id']?.toString() == myTeamId) continue;
        final teamMap = player['teams'] as Map<String, dynamic>?;
        
        String? prefPos;
        if (pid != null) {
          final prof = profilesData.where((p) => p['id'].toString() == pid).firstOrNull;
          prefPos = prof?['preferred_position'];
        }

        combined.add({
          'profile_id': pid,
          'player_id': player['id'].toString(),
          'name': player['name'],
          'position': prefPos ?? player['position'],
          'number': player['number'],
          'team_name': teamMap?['name'],
          'team_logo': teamMap?['logo_url'],
          'is_free': player['team_id'] == null,
        });
      }
      combined.sort((a, b) {
        if (a['is_free'] && !b['is_free']) return -1;
        if (!a['is_free'] && b['is_free']) return 1;
        return (a['name'] as String).compareTo(b['name'] as String);
      });
      setState(() {
        _allPlayers = combined;
        _applyFilters();
        _marketLoading = false;
      });
    } catch (e) {
      debugPrint('Market load error: $e');
      setState(() => _marketLoading = false);
    }
  }

  bool _positionMatches(String? dbPos, String? filterPos) {
    if (filterPos == null || filterPos.isEmpty || filterPos == 'Tümü') return true;
    if (dbPos == null || dbPos.isEmpty) return false;
    
    final posUpper = dbPos.toUpperCase();
    switch (filterPos) {
      case 'Kaleci':
        return posUpper.contains('KALEC') || posUpper == 'GK' || posUpper == 'GOALKEEPER';
      case 'Defans':
        return posUpper.contains('DEFANS') || posUpper.contains('STP') || posUpper.contains('BEK') || posUpper == 'CB' || posUpper == 'LB' || posUpper == 'RB' || posUpper == 'DF' || posUpper == 'STOPER';
      case 'Orta Saha':
        return posUpper.contains('ORTA') || posUpper.contains('OS') || posUpper.contains('MDF') || posUpper == 'CM' || posUpper == 'CDM' || posUpper == 'CAM' || posUpper == 'MF';
      case 'Forvet':
        return posUpper.contains('FORVET') || posUpper.contains('SNT') || posUpper.contains('KANAT') || posUpper == 'ST' || posUpper == 'RW' || posUpper == 'LW' || posUpper == 'FW' || posUpper == 'SANTRFOR';
      default:
        return false;
    }
  }

  void _applyFilters() {
    final name = _nameFilter.text.toLowerCase();
    final pos = _positionFilter;
    final team = _teamFilter;
    setState(() {
      _filteredPlayers = _allPlayers.where((p) {
        final nameMatch = name.isEmpty ||
            (p['name'] as String).toLowerCase().contains(name);
        final posMatch = _positionMatches(p['position'] as String?, pos);
        final teamMatch = team == null ||
            team == 'Tümü' ||
            (team == 'SERBEST' ? p['is_free'] == true : p['team_name'] == team);
        return nameMatch && posMatch && teamMatch;
      }).toList();
    });
  }

  
  Future<void> _getFixture() async {
    try {
      var query = supabase
          .from('matches')
          .select('*, home:teams!home_team_id(name, logo_url), away:teams!away_team_id(name, logo_url)');
      
      if (_selectedStatLeagueId != null) {
        query = query.eq('league_id', _selectedStatLeagueId!);
      }

      final response = await query
          .order('match_week', ascending: true) 
          .order('match_date', ascending: true);

      Map<int, List<Map<String, dynamic>>> grouped = {};
      
      for (var match in response) {
        int week = match['match_week'] ?? 1; 
        if (!grouped.containsKey(week)) grouped[week] = [];
        grouped[week]!.add(match);
      }
      
      setState(() => fixture = grouped);
    } catch (e) { debugPrint("Fikstür hatası: $e"); }
  }

  
  Future<void> _calculateStandings() async {
    try {
      var query = supabase.from('standings_view').select();
      
      if (_selectedStatLeagueId != null) {
        query = query.eq('league_id', _selectedStatLeagueId!);
      }

      final response = await query;
      
      // Normalize columns to map team_id -> id and team_name -> name for compatibility
      final List<Map<String, dynamic>> sortedList = (response as List).map((item) {
        final Map<String, dynamic> team = Map<String, dynamic>.from(item);
        return {
          ...team,
          'id': team['team_id'] ?? team['id'],
          'name': team['team_name'] ?? team['name'],
        };
      }).toList();

      setState(() {
        standings = sortedList;
      });
    } catch (e) { debugPrint("Puan hatası: $e"); }
  }

  
  Future<void> _calculatePlayerStats() async {
    try {
      var query = supabase
          .from('match_goals')
          .select('player_id, assist_player_id, matches!inner(league_id), players!player_id(name, teams(name)), assist_player:players!assist_player_id(name, teams(name))');
      
      if (_selectedStatLeagueId != null) {
        query = query.eq('matches.league_id', _selectedStatLeagueId!);
      }
      
      final response = await query;
      
      Map<String, Map<String, dynamic>> goalStats = {};
      Map<String, Map<String, dynamic>> assistStats = {};

      for (var goal in response) {
        final pid = goal['player_id'];
        if (pid != null) {
          if (!goalStats.containsKey(pid)) {
            final pData = goal['players'];
            goalStats[pid] = {'id': pid, 'name': pData?['name'] ?? 'Bilinmiyor', 'team': pData?['teams']?['name'] ?? 'Bilinmiyor', 'count': 0};
          }
          goalStats[pid]!['count'] += 1;
        }
        final aid = goal['assist_player_id'];
        if (aid != null) {
          if (!assistStats.containsKey(aid)) {
            final aData = goal['assist_player'];
            assistStats[aid] = {'id': aid, 'name': aData?['name'] ?? 'Bilinmiyor', 'team': aData?['teams']?['name'] ?? 'Bilinmiyor', 'count': 0};
          }
          assistStats[aid]!['count'] += 1;
        }
      }
      topScorers = goalStats.values.toList()..sort((a, b) => b['count'].compareTo(a['count']));
      topAssists = assistStats.values.toList()..sort((a, b) => b['count'].compareTo(a['count']));
    } catch (e) { debugPrint("İstatistik hatası: $e"); }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          const CustomNavBar(showBackButton: false),
          Expanded(
            child: isMobile 
            ? _buildMobileLayout()
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 280, child: _buildSidebar()),
                  Expanded(child: _buildContentArea()),
                ],
              ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      color: const Color(0xFF0F172A), 
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        children: [
          _buildSidebarHeader("LİG MENÜSÜ"),
          _buildMenuItem("HABERLER", Icons.newspaper),
          _buildMenuItem("GENEL BAKIŞ", Icons.dashboard),
          _buildMenuItem("PUAN DURUMU", Icons.format_list_numbered),
          _buildMenuItem("MAÇ PROGRAMI", Icons.calendar_month),
          
          _buildSidebarHeader("İSTATİSTİKLER"),
          _buildMenuItem("OYUNCU İSTATİSTİKLERİ", Icons.bar_chart), 
          _buildMenuItem("TRANSFER BORSASI", Icons.swap_horiz),
          _buildMenuItem("CEZA TAHTASI", Icons.gavel),
          
          _buildSidebarHeader("YÖNETİM"),
          _buildMenuItem("TAKIMIM", Icons.shield, isAction: true),
        ],
      ),
    );
  }

  Widget _buildSidebarHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 25, 20, 10),
      child: Text(title, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }

  Widget _buildMenuItem(String title, IconData icon, {bool isAction = false}) {
    final isSelected = _selectedMenu == title;
    const Color activeColor = Color(0xFF00FF7F); 

    return InkWell(
      onTap: () {
        if (isAction && title == "TAKIMIM") {
          context.push('/my-team');
        } else {
          setState(() => _selectedMenu = title);
          if (title == "TRANSFER BORSASI" && _allPlayers.isEmpty) {
            _loadMarket();
          }
        }
      },
      child: Container(
        decoration: BoxDecoration(
          border: isSelected ? const Border(left: BorderSide(color: activeColor, width: 4)) : null,
          color: isSelected ? const Color(0xFF1E293B) : Colors.transparent, 
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? activeColor : Colors.grey.shade400, size: 22),
            const SizedBox(width: 12),
            Text(title, style: TextStyle(color: isSelected ? Colors.white : Colors.grey.shade400, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildContentArea() {
    Widget content;
    if (isLoading) {
      content = const Center(child: CircularProgressIndicator());
    } else {
      switch (_selectedMenu) {
        case "HABERLER": content = _buildNewsPage(); break;
        case "PUAN DURUMU": content = _buildStandingsTable(); break;
        case "OYUNCU İSTATİSTİKLERİ": content = _buildStatisticsPage(); break;
        case "MAÇ PROGRAMI": content = _buildFixturePage(); break;
        case "TRANSFER BORSASI": content = _buildTransferMarket(); break;
        default: content = Center(child: Text("$_selectedMenu sayfası hazırlanıyor...", style: const TextStyle(color: Colors.grey, fontSize: 18)));
      }
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height - 180),
            child: content,
          ),
          const CustomFooter(),
        ],
      ),
    );
  }

  
  Widget _buildFixturePage() {
    if (fixture.isEmpty) return const Center(child: Text("Henüz maç planlanmadı.", style: TextStyle(fontSize: 16, color: Colors.grey)));
    
    
    final sortedWeeks = fixture.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedWeeks.length,
      itemBuilder: (context, index) {
        final week = sortedWeeks[index];
        final matches = fixture[week]!;

        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
              margin: const EdgeInsets.only(top: 15, bottom: 5),
              decoration: BoxDecoration(color: const Color(0xFF06283D), borderRadius: BorderRadius.circular(5)),
              child: Text("$week. HAFTA", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.center),
            ),
            ...matches.map((match) {
              final isFinished = match['status'] == 'finished';
              final date = DateTime.parse(match['match_date']);
              final hour = "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
              final day = "${date.day}/${date.month}";

              return Card(
                elevation: 2, margin: const EdgeInsets.only(bottom: 8), color: const Color(0xFF1E293B), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5), side: BorderSide(color: Colors.grey.withOpacity(0.2))),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
                  child: Row(
                    children: [
                      Expanded(child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [Text(match['home']['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white), textAlign: TextAlign.right), const SizedBox(width: 10), TeamLogo(url: match['home']['logo_url'], size: 35)])),
                      Container(
                        width: 90, alignment: Alignment.center,
                        child: isFinished 
                          ? Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(5)), child: Text("${match['home_score']} - ${match['away_score']}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white)))
                          : Column(children: [Text(hour, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00FF7F), fontSize: 16)), Text(day, style: const TextStyle(fontSize: 11, color: Colors.grey))]),
                      ),
                      Expanded(child: Row(children: [TeamLogo(url: match['away']['logo_url'], size: 35), const SizedBox(width: 10), Text(match['away']['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white))])),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  
  Widget _buildNewsPage() {
    if (_newsList.isEmpty) return const Center(child: Text("Henüz bir haber yayınlanmamış.", style: TextStyle(color: Colors.grey, fontSize: 16)));
    
    return LayoutBuilder(
      builder: (context, constraints) {
        int columns = 1;
        if (constraints.maxWidth > 1100) columns = 3;
        else if (constraints.maxWidth > 700) columns = 2;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 50, left: 16, right: 16, top: 16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            mainAxisExtent: 360, 
          ),
          itemCount: _newsList.length,
          itemBuilder: (context, index) {
            final news = _newsList[index];
            final title = news['title'] ?? '';
            final desc = news['content'] ?? '';
            final category = news['category'] ?? 'genel';
            final imageUrl = news['image_url'];
            final youtubeUrl = news['youtube_url'];
            
            Color catColor = const Color(0xFF2ECC71); 
            String catLabel = 'HABER';
            if (category == 'haftanin_11i') { catColor = Colors.blueAccent; catLabel = "HAFTANIN 11'İ"; }
            else if (category == 'haftanin_oyuncusu') { catColor = const Color(0xFFF39C12); catLabel = "HAFTANIN OYUNCUSU"; }
            else if (category == 'video') { catColor = Colors.redAccent; catLabel = "VİDEO (YOUTUBE)"; }

            final hasImage = imageUrl != null && imageUrl.toString().isNotEmpty;

            return Card(
              elevation: 2,
              margin: EdgeInsets.zero,
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300, width: 1)),
              child: InkWell(
                onTap: () => NewsDetailDialog.show(context, news),
                borderRadius: BorderRadius.circular(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasImage)
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        child: Image.network(imageUrl, width: double.infinity, height: 180, fit: BoxFit.cover), 
                      ),
                    if (category == 'video' && !hasImage)
                      Container(
                        height: 180,
                        width: double.infinity,
                        decoration: const BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.vertical(top: Radius.circular(12))
                        ),
                        child: const Center(child: Icon(Icons.play_circle_fill, color: Colors.redAccent, size: 60)),
                      ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: catColor.withOpacity(0.15), 
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(catLabel, style: TextStyle(color: catColor, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 0.5)),
                            ),
                            const SizedBox(height: 10),
                            Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.2)),
                            if (desc.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Expanded(
                                child: Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade700, fontSize: 13, height: 1.4)),
                              ),
                            ],
                            if (category == 'video') ...[
                              const Spacer(),
                              Row(
                                children: const [
                                  Icon(Icons.play_circle_outline, color: Colors.redAccent, size: 18),
                                  SizedBox(width: 4),
                                  Text("Videoyu İzle", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12))
                                ],
                              )
                            ]
                          ]
                        )
                      )
                    )
                  ]
                )
              )
            );
          }
        );
      }
    );
  }

  
  Widget _buildStandingsTable() {
    if (standings.isEmpty) return const Center(child: Text("Henüz veri yok."));
    return Card(elevation: 4, color: const Color(0xFF1E293B), child: Column(children: [
          Container(padding: const EdgeInsets.all(15), color: const Color(0xFF0F172A), child: const Row(children: [SizedBox(width: 30, child: Text("#", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))), Expanded(flex: 3, child: Text("Takım", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))), SizedBox(width: 30, child: Text("O", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))), SizedBox(width: 30, child: Text("G", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))), SizedBox(width: 30, child: Text("B", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))), SizedBox(width: 30, child: Text("M", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))), SizedBox(width: 35, child: Text("Av", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))), SizedBox(width: 30, child: Text("P", style: TextStyle(color: Color(0xFF00FF7F), fontWeight: FontWeight.bold)))])),
          ListView.separated(shrinkWrap: true, itemCount: standings.length, separatorBuilder: (c, i) => Divider(height: 1, color: Colors.grey.withOpacity(0.2)), itemBuilder: (context, index) { 
            final team = standings[index];
            final teamId = team['id'] as String?;
            return InkWell(
              onTap: teamId != null ? () => context.push('/team/$teamId') : null,
              child: Padding(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15), child: Row(children: [
                SizedBox(width: 30, child: Text("${index + 1}.", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                Expanded(flex: 3, child: Row(children: [
                  TeamLogo(url: team['logo_url'], size: 24),
                  const SizedBox(width: 8),
                  Expanded(child: Text(team['name'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                  const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                ])),
                SizedBox(width: 30, child: Text("${team['played']}", style: const TextStyle(color: Colors.white70))),
                SizedBox(width: 30, child: Text("${team['won']}", style: const TextStyle(color: Colors.white70))),
                SizedBox(width: 30, child: Text("${team['drawn']}", style: const TextStyle(color: Colors.white70))),
                SizedBox(width: 30, child: Text("${team['lost']}", style: const TextStyle(color: Colors.white70))),
                SizedBox(width: 35, child: Text("${team['avg']}", style: const TextStyle(color: Colors.white70))),
                SizedBox(width: 30, child: Text("${team['points']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00FF7F)))),
              ])),
            );
          })
    ]));
  }

  Widget _buildStatisticsPage() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("OYUNCU İSTATİSTİKLERİ", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF06283D))),
              if (_leagues.isNotEmpty)
                Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade800)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedStatLeagueId,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                      items: _leagues.map((l) => DropdownMenuItem<String>(value: l['id'].toString(), child: Text(l['name']))).toList(),
                      onChanged: (val) {
                        if (val != null && val != _selectedStatLeagueId) {
                          setState(() { _selectedStatLeagueId = val; isLoading = true; });
                          Future.wait([
                            _calculatePlayerStats(),
                            _calculateStandings(),
                            _getFixture(),
                          ]).then((_) {
                            if (mounted) setState(() => isLoading = false);
                          });
                        }
                      },
                    ),
                  ),
                )
            ]
          ),
          const SizedBox(height: 20),
          LayoutBuilder(builder: (context, constraints) {
              if (constraints.maxWidth > 900) return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: _buildStatCard("GOL KRALLIĞI", topScorers, "⚽", Colors.green)), const SizedBox(width: 20), Expanded(child: _buildStatCard("ASİST KRALLIĞI", topAssists, "👟", Colors.blue))]);
              else return Column(children: [_buildStatCard("GOL KRALLIĞI", topScorers, "⚽", Colors.green), const SizedBox(height: 20), _buildStatCard("ASİST KRALLIĞI", topAssists, "👟", Colors.blue)]);
          })
    ]);
  }

  Widget _buildStatCard(String title, List<Map<String, dynamic>> data, String icon, Color color) {
    return Card(elevation: 4, color: const Color(0xFF1E293B), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), child: Column(children: [
          Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.8), borderRadius: const BorderRadius.vertical(top: Radius.circular(8))), child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.center)),
          if (data.isEmpty) const Padding(padding: EdgeInsets.all(20), child: Text("Veri Yok", style: TextStyle(color: Colors.white))),
          ListView.separated(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: data.length > 10 ? 10 : data.length, separatorBuilder: (c, i) => Divider(height: 1, color: Colors.grey.withOpacity(0.2)), itemBuilder: (context, index) { 
            final item = data[index]; 
            return ListTile(
              onTap: () {
                if (item['id'] != null) {
                   PlayerProfileDialog.show(context, item['id']);
                }
              },
              leading: CircleAvatar(backgroundColor: Colors.white10, child: Text("${index + 1}", style: TextStyle(color: color, fontWeight: FontWeight.bold))), 
              title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)), 
              subtitle: Text(item['team'], style: TextStyle(color: Colors.grey.shade400)), 
              trailing: Chip(label: Text("$icon ${item['count']}", style: TextStyle(color: color, fontWeight: FontWeight.bold)), backgroundColor: color.withOpacity(0.1))
            ); 
          })
    ]));
  }

  Widget _buildMobileLayout() {
    return Column(children: [Expanded(child: _buildContentArea())]);
  }

  
  
  
  Widget _buildTransferMarket() {
    final currentUserId = supabase.auth.currentUser?.id;
    final isCaptan = _myTeamData != null && _myTeamData!['owner_id'] == currentUserId;
    final teamNames = <String>['Tümü', 'SERBEST', ..._allPlayers
        .where((p) => p['team_name'] != null)
        .map((p) => p['team_name'] as String)
        .toSet()
        .toList()..sort()];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 4, height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2ECC71),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('OYUNCU BORSASI',
                      style: TextStyle(color: Colors.white, fontSize: 22,
                          fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white70),
                    onPressed: _loadMarket, tooltip: 'Yenile',
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Padding(
                padding: EdgeInsets.only(left: 16),
                child: Text('Listedeki oyuncuları görüntüleyin ve teklif gönderin.',
                    style: TextStyle(color: Colors.white60, fontSize: 13)),
              ),
            ],
          ),
        ),

        
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('FİLTRE:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70, fontSize: 13)),
              SizedBox(
                width: 160, height: 38,
                child: TextField(
                  controller: _nameFilter,
                  onChanged: (_) => _applyFilters(),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Oyuncu Adı',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.withOpacity(0.3))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.withOpacity(0.3))),
                  ),
                ),
              ),
              _buildDropdown(
                hint: 'Pozisyon', value: _positionFilter,
                items: const ['Tümü','Kaleci','Defans','Orta Saha','Forvet'],
                onChanged: (v) { setState(() => _positionFilter = v == 'Tümü' ? null : v); _applyFilters(); },
              ),
              _buildDropdown(
                hint: 'Takım', value: _teamFilter,
                items: teamNames,
                onChanged: (v) { setState(() => _teamFilter = v); _applyFilters(); },
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  _nameFilter.clear();
                  setState(() { _positionFilter = null; _teamFilter = null; });
                  _applyFilters();
                },
                icon: const Icon(Icons.clear, size: 16),
                label: const Text('TEMİZLE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ],
          ),
        ),

        
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
          ),
          child: const Row(
            children: [
              SizedBox(width: 30, child: Text('#', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70, fontSize: 13))),
              Expanded(flex: 3, child: Text('OYUNCU', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70, fontSize: 13))),
              Expanded(flex: 2, child: Text('TAKIM', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70, fontSize: 13))),
              Expanded(flex: 2, child: Text('MEVKİ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70, fontSize: 13))),
              SizedBox(width: 80, child: Text('DURUM', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70, fontSize: 13))),
              SizedBox(width: 120, child: Text('İŞLEM', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70, fontSize: 13), textAlign: TextAlign.center)),
            ],
          ),
        ),

        
        _marketLoading
            ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
            : _filteredPlayers.isEmpty
                ? SizedBox(
                    height: 200,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.search_off, size: 60, color: Colors.grey),
                          const SizedBox(height: 12),
                          Text(
                            _allPlayers.isEmpty
                                ? 'Borsayı yüklemek için Yenile butonuna basın.'
                                : 'Arama kriterlerine uygun oyuncu bulunamadı.',
                            style: const TextStyle(color: Colors.grey, fontSize: 15),
                          ),
                          if (_allPlayers.isEmpty) ...[
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _loadMarket,
                              icon: const Icon(Icons.refresh),
                              label: const Text('BORSAYI YÜKLE'),
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF06283D), foregroundColor: Colors.white),
                            ),
                          ]
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: _filteredPlayers.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
                    itemBuilder: (context, index) {
                      final player = _filteredPlayers[index];
                      final profileId = player['profile_id'] as String?;
                      final isFree = player['is_free'] as bool;
                      final alreadySent = profileId != null &&
                          _sentOffers.any((o) => o['profile_id'] == profileId);
                      final isMe = profileId == currentUserId;

                      return Container(
                        color: index.isEven ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        child: Row(
                          children: [
                            SizedBox(width: 30, child: Text('${index + 1}', style: const TextStyle(color: Colors.white70, fontSize: 13))),
                            Expanded(
                              flex: 3,
                              child: GestureDetector(
                                onTap: player['player_id'] != null
                                    ? () => context.push('/player/${player['player_id']}')
                                    : null,
                                child: Text(
                                  player['name'] as String,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: 14,
                                    decoration: player['player_id'] != null ? TextDecoration.underline : null,
                                    decorationColor: Colors.white54,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: isFree
                                  ? const Text('Takım Yok', style: TextStyle(color: Colors.grey, fontSize: 13))
                                  : Row(children: [
                                      TeamLogo(url: player['team_logo'] as String?, size: 22),
                                      const SizedBox(width: 6),
                                      Expanded(child: Text(player['team_name'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white), overflow: TextOverflow.ellipsis)),
                                    ]),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text((player['position'] as String?) ?? 'Belirtilmedi', style: const TextStyle(fontSize: 13, color: Colors.white70)),
                            ),
                            SizedBox(
                              width: 80,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isFree ? const Color(0xFF2ECC71).withOpacity(0.2) : Colors.blueAccent.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: isFree ? const Color(0xFF2ECC71) : Colors.blueAccent),
                                ),
                                child: Text(
                                  isFree ? 'SERBEST' : 'TAKIM',
                                  style: TextStyle(color: isFree ? const Color(0xFF2ECC71) : Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 10),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 120,
                              child: _buildOfferButton(
                                isMe: isMe, isCaptan: isCaptan,
                                alreadySent: alreadySent,
                                profileId: profileId,
                                playerName: player['name'] as String,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ],
    );
  }

  Widget _buildIncomingOffersBanner(String? userId) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF0D47A1)]),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.notifications_active, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('Transfer Tekliflerin (${_myPendingOffers.length})',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
          ),
          ..._myPendingOffers.map((offer) {
            final team = offer['teams'] as Map<String, dynamic>? ?? {};
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  TeamLogo(url: team['logo_url'] as String?, size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(team['name']?.toString().toUpperCase() ?? 'Bilinmeyen Takım',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        const Text('seni transfer etmek istiyor', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2ECC71), foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () async => _respondToOffer(offer['id'], userId!, offer['team_id'], accepted: true),
                    child: const Text('KABUL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  const SizedBox(width: 6),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () async => _respondToOffer(offer['id'], userId!, offer['team_id'], accepted: false),
                    child: const Text('RET', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _respondToOffer(String offerId, String userId, String teamId, {required bool accepted}) async {
    try {
      if (accepted) {
        final existingPlayer = await supabase.from('players').select('id').eq('profile_id', userId).maybeSingle();
        if (existingPlayer != null) {
          await supabase.from('players').update({'team_id': teamId}).eq('id', existingPlayer['id']);
        } else {
          final profile = await supabase.from('profiles').select('username, full_name').eq('id', userId).maybeSingle();
          final name = (profile?['username'] as String?) ?? (profile?['full_name'] as String?) ?? 'Oyuncu';
          await supabase.from('players').insert({'profile_id': userId, 'team_id': teamId, 'name': name, 'position': 'Orta Saha', 'number': 0});
        }
      }
      await supabase.from('transfer_requests').update({'status': accepted ? 'accepted' : 'rejected'}).eq('id', offerId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(accepted ? 'Transfer kabul edildi! Artik yeni takimindasin.' : 'Teklif reddedildi.'),
          backgroundColor: accepted ? Colors.green : Colors.orange,
        ));
        await _loadMyTeamAndOffers();
        await _loadMarket();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));
    }
  }

  Widget _buildOfferButton({required bool isMe, required bool isCaptan, required bool alreadySent, required String? profileId, required String playerName}) {
    if (isMe || !isCaptan) return const SizedBox.shrink();
    if (alreadySent) {
      return const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check, color: Colors.green, size: 16),
          SizedBox(width: 4),
          Text('GONDERILDI', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      );
    }
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF06283D), foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        minimumSize: const Size(110, 34),
      ),
      onPressed: profileId == null ? null : () => _sendTransferOffer(profileId, playerName),
      child: const Text('TEKLIF GONDER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }

  Future<void> _sendTransferOffer(String profileId, String playerName) async {
    if (_myTeamData == null) return;
    try {
      await supabase.from('transfer_requests').insert({'team_id': _myTeamData!['id'], 'profile_id': profileId, 'status': 'pending'});
      setState(() { _sentOffers.add({'profile_id': profileId, 'status': 'pending'}); });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$playerName oyuncusuna teklif gonderildi!'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().contains('unique') || e.toString().contains('duplicate') ? 'Bu oyuncuya zaten bekleyen bir teklifiniz var!' : 'Hata: $e'),
        backgroundColor: Colors.orange,
      ));
    }
  }

  Widget _buildDropdown({required String hint, required String? value, required List<String> items, required ValueChanged<String?> onChanged}) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.withOpacity(0.3)), borderRadius: BorderRadius.circular(8), color: const Color(0xFF1E293B)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          dropdownColor: const Color(0xFF1E293B),
          style: const TextStyle(color: Colors.white, fontSize: 13),
          value: value,
          hint: Text(hint, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13)),
          isDense: true,
          icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.white70),
          items: items.map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(color: Colors.white, fontSize: 13)))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
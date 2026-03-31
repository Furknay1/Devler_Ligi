import 'package:flutter/material.dart';
import 'package:devler_ligi/main.dart'; // supabase client
import 'package:devler_ligi/features/auth/welcome_dashboard.dart';
import 'package:devler_ligi/features/home/my_team_page.dart';
import 'package:devler_ligi/widgets/custom_nav_bar.dart';
import 'package:devler_ligi/widgets/team_logo.dart'; 

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Varsayılan seçili menü
  String _selectedMenu = "HABERLER"; 
  bool isLoading = true;

  // Veri Listeleri
  List<Map<String, dynamic>> standings = [];
  List<Map<String, dynamic>> topScorers = []; 
  List<Map<String, dynamic>> topAssists = [];
  
  // Fikstür Verisi (Hafta -> Maçlar Listesi)
  Map<int, List<Map<String, dynamic>>> fixture = {};

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
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const WelcomeDashboard()));
    } else {
      _refreshData();
    }
  }

  Future<void> _refreshData() async {
    setState(() => isLoading = true);
    await Future.wait([
      _calculateStandings(),
      _calculatePlayerStats(),
      _getFixture(),
    ]);
    if(mounted) setState(() => isLoading = false);
  }

  // --- 1. MAÇ PROGRAMI (FİKSTÜR) ÇEKME ---
  Future<void> _getFixture() async {
    try {
      final response = await supabase
          .from('matches')
          .select('*, home:teams!home_team_id(name, logo_url), away:teams!away_team_id(name, logo_url)')
          .order('match_week', ascending: true) // Veritabanından sıralı çekiyoruz ama UI'da ters çevireceğiz
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

  // --- 2. PUAN DURUMU (AVERAJ DAHİL) ---
  Future<void> _calculateStandings() async {
    try {
      final teamsData = await supabase.from('teams').select('id, name, logo_url');
      final matchesData = await supabase.from('matches').select().eq('status', 'finished');

      Map<String, Map<String, dynamic>> teamStats = {};
      for (var team in teamsData) {
        teamStats[team['id']] = {
          'name': team['name'], 
          'logo_url': team['logo_url'], 
          'played': 0, 'won': 0, 'drawn': 0, 'lost': 0, 
          'gf': 0, 'ga': 0, 'points': 0
        };
      }

      for (var match in matchesData) {
        final homeId = match['home_team_id']; final awayId = match['away_team_id'];
        final homeScore = match['home_score'] as int; final awayScore = match['away_score'] as int;

        if (teamStats[homeId] == null || teamStats[awayId] == null) continue;

        teamStats[homeId]!['played'] += 1; teamStats[awayId]!['played'] += 1;
        teamStats[homeId]!['gf'] += homeScore; teamStats[homeId]!['ga'] += awayScore;
        teamStats[awayId]!['gf'] += awayScore; teamStats[awayId]!['ga'] += homeScore;

        if (homeScore > awayScore) {
          teamStats[homeId]!['won'] += 1; teamStats[homeId]!['points'] += 3; teamStats[awayId]!['lost'] += 1;
        } else if (awayScore > homeScore) {
          teamStats[awayId]!['won'] += 1; teamStats[awayId]!['points'] += 3; teamStats[homeId]!['lost'] += 1;
        } else {
          teamStats[homeId]!['drawn'] += 1; teamStats[homeId]!['points'] += 1;
          teamStats[awayId]!['drawn'] += 1; teamStats[awayId]!['points'] += 1;
        }
      }

      List<Map<String, dynamic>> sortedList = teamStats.values.toList();
      
      // AVERAJ HESAPLAMA (GF - GA)
      for (var team in sortedList) { team['avg'] = team['gf'] - team['ga']; }
      
      // SIRALAMA: Önce Puan, Sonra Averaj
      sortedList.sort((a, b) {
        int point = b['points'].compareTo(a['points']);
        return point != 0 ? point : b['avg'].compareTo(a['avg']);
      });
      standings = sortedList;
    } catch (e) { debugPrint("Puan hatası: $e"); }
  }

  // --- 3. İSTATİSTİKLER ---
  Future<void> _calculatePlayerStats() async {
    try {
      final response = await supabase
          .from('match_goals')
          .select('player_id, assist_player_id, players!player_id(name, teams(name)), assist_player:players!assist_player_id(name, teams(name))');
      
      Map<String, Map<String, dynamic>> goalStats = {};
      Map<String, Map<String, dynamic>> assistStats = {};

      for (var goal in response) {
        final pid = goal['player_id'];
        if (pid != null) {
          if (!goalStats.containsKey(pid)) {
            final pData = goal['players'];
            goalStats[pid] = {'name': pData?['name'] ?? '', 'team': pData?['teams']?['name'] ?? '', 'count': 0};
          }
          goalStats[pid]!['count'] += 1;
        }
        final aid = goal['assist_player_id'];
        if (aid != null) {
          if (!assistStats.containsKey(aid)) {
            final aData = goal['assist_player'];
            assistStats[aid] = {'name': aData?['name'] ?? '', 'team': aData?['teams']?['name'] ?? '', 'count': 0};
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
      backgroundColor: const Color(0xFFF5F5F5),
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
                  Expanded(child: Padding(padding: const EdgeInsets.all(20), child: _buildContentArea())),
                ],
              ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      color: Colors.white,
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
    const Color activeColor = Color(0xFF2E7D32); 

    return InkWell(
      onTap: () {
        if (isAction && title == "TAKIMIM") {
           Navigator.push(context, MaterialPageRoute(builder: (_) => const MyTeamPage()));
        } else {
          setState(() => _selectedMenu = title);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          border: isSelected ? const Border(left: BorderSide(color: activeColor, width: 4)) : null,
          color: isSelected ? Colors.grey.shade100 : Colors.transparent,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? activeColor : Colors.grey.shade600, size: 22),
            const SizedBox(width: 12),
            Text(title, style: TextStyle(color: isSelected ? Colors.black : Colors.grey.shade700, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildContentArea() {
    if (isLoading) return const Center(child: CircularProgressIndicator());

    switch (_selectedMenu) {
      case "HABERLER": return _buildNewsPage();
      case "PUAN DURUMU": return _buildStandingsTable();
      case "OYUNCU İSTATİSTİKLERİ": return _buildStatisticsPage();
      case "MAÇ PROGRAMI": return _buildFixturePage();
      default: return Center(child: Text("$_selectedMenu sayfası hazırlanıyor...", style: const TextStyle(color: Colors.grey, fontSize: 18)));
    }
  }

  // --- MAÇ PROGRAMI SAYFASI (YENİLENMİŞ SIRALAMA) ---
  Widget _buildFixturePage() {
    if (fixture.isEmpty) return const Center(child: Text("Henüz maç planlanmadı.", style: TextStyle(fontSize: 16, color: Colors.grey)));
    
    // YENİ: Haftaları BÜYÜKTEN KÜÇÜĞE sırala (En yeni hafta en üstte)
    final sortedWeeks = fixture.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
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
                elevation: 1, margin: const EdgeInsets.only(bottom: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
                  child: Row(
                    children: [
                      Expanded(child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [Text(match['home']['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), textAlign: TextAlign.right), const SizedBox(width: 10), TeamLogo(url: match['home']['logo_url'], size: 35)])),
                      Container(
                        width: 90, alignment: Alignment.center,
                        child: isFinished 
                          ? Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(5)), child: Text("${match['home_score']} - ${match['away_score']}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.black)))
                          : Column(children: [Text(hour, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 16)), Text(day, style: const TextStyle(fontSize: 11, color: Colors.grey))]),
                      ),
                      Expanded(child: Row(children: [TeamLogo(url: match['away']['logo_url'], size: 35), const SizedBox(width: 10), Text(match['away']['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))])),
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

  // --- DİĞER SAYFALAR ---
  Widget _buildNewsPage() {
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(height: 350, width: double.infinity, decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8), image: const DecorationImage(image: NetworkImage("https://images.unsplash.com/photo-1574629810360-7efbbe195018?q=80&w=1920&auto=format&fit=crop"), fit: BoxFit.cover, opacity: 0.7)), child: Stack(children: [const Center(child: Icon(Icons.play_circle_fill, color: Colors.white, size: 70)), Positioned(bottom: 20, left: 20, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), color: Colors.green, child: const Text("HABER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))), const SizedBox(height: 10), const Text("Devler Ligi / 2025 Sezonu Açıldı / Haftanın Golleri", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold))]))])),
          const SizedBox(height: 30),
          _buildNewsItem("Transfer Borsası Açıldı!", "Takımlar kadrolarını güçlendirmeye başladı...", "2 saat önce"),
          _buildNewsItem("Haftanın Kurtarışları", "Kaleciler bu hafta devleşti.", "5 saat önce"),
      ]),
    );
  }

  Widget _buildNewsItem(String title, String desc, String time) {
    return Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(leading: Container(width: 80, height: 60, color: Colors.grey.shade300), title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(desc), trailing: Text(time, style: const TextStyle(fontSize: 12, color: Colors.grey))));
  }

  // PUAN DURUMU TABLOSU (AVERAJLI)
  Widget _buildStandingsTable() {
    if (standings.isEmpty) return const Center(child: Text("Henüz veri yok."));
    return Card(elevation: 2, child: Column(children: [
          Container(padding: const EdgeInsets.all(15), color: const Color(0xFF06283D), child: const Row(children: [SizedBox(width: 30, child: Text("#", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))), Expanded(flex: 3, child: Text("Takım", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))), SizedBox(width: 30, child: Text("O", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))), SizedBox(width: 30, child: Text("G", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))), SizedBox(width: 30, child: Text("B", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))), SizedBox(width: 30, child: Text("M", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))), SizedBox(width: 35, child: Text("Av", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))), SizedBox(width: 30, child: Text("P", style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold)))])),
          ListView.separated(shrinkWrap: true, itemCount: standings.length, separatorBuilder: (c, i) => const Divider(height: 1), itemBuilder: (context, index) { 
            final team = standings[index]; 
            return Padding(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15), child: Row(children: [SizedBox(width: 30, child: Text("${index + 1}.")), Expanded(flex: 3, child: Row(children: [TeamLogo(url: team['logo_url'], size: 24), const SizedBox(width: 8), Expanded(child: Text(team['name'], style: const TextStyle(fontWeight: FontWeight.bold)))])), SizedBox(width: 30, child: Text("${team['played']}")), SizedBox(width: 30, child: Text("${team['won']}")), SizedBox(width: 30, child: Text("${team['drawn']}")), SizedBox(width: 30, child: Text("${team['lost']}")), SizedBox(width: 35, child: Text("${team['avg']}")), SizedBox(width: 30, child: Text("${team['points']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF06283D))))])); 
          })
    ]));
  }

  Widget _buildStatisticsPage() {
    return SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("OYUNCU İSTATİSTİKLERİ", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF06283D))), const SizedBox(height: 20),
          LayoutBuilder(builder: (context, constraints) {
              if (constraints.maxWidth > 900) return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: _buildStatCard("GOL KRALLIĞI", topScorers, "⚽", Colors.green)), const SizedBox(width: 20), Expanded(child: _buildStatCard("ASİST KRALLIĞI", topAssists, "👟", Colors.blue))]);
              else return Column(children: [_buildStatCard("GOL KRALLIĞI", topScorers, "⚽", Colors.green), const SizedBox(height: 20), _buildStatCard("ASİST KRALLIĞI", topAssists, "👟", Colors.blue)]);
          })
    ]));
  }

  Widget _buildStatCard(String title, List<Map<String, dynamic>> data, String icon, Color color) {
    return Card(elevation: 3, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), child: Column(children: [
          Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color, borderRadius: const BorderRadius.vertical(top: Radius.circular(8))), child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.center)),
          if (data.isEmpty) const Padding(padding: EdgeInsets.all(20), child: Text("Veri Yok")),
          ListView.separated(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: data.length > 10 ? 10 : data.length, separatorBuilder: (c, i) => const Divider(height: 1), itemBuilder: (context, index) { final item = data[index]; return ListTile(leading: CircleAvatar(backgroundColor: Colors.grey.shade100, child: Text("${index + 1}", style: TextStyle(color: color, fontWeight: FontWeight.bold))), title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(item['team']), trailing: Chip(label: Text("$icon ${item['count']}", style: TextStyle(color: color, fontWeight: FontWeight.bold)), backgroundColor: color.withOpacity(0.1))); })
    ]));
  }

  Widget _buildMobileLayout() { return Column(children: [Expanded(child: _buildContentArea())]); }
}
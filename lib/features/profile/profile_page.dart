import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:devler_ligi/main.dart';
import 'package:devler_ligi/widgets/custom_nav_bar.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;

  Map<String, dynamic>? profileData;
  Map<String, dynamic>? playerStats;
  List<Map<String, dynamic>> recentForms = [];
  List<Map<String, dynamic>> pendingTransfers = [];
  bool isLoading = true;

  
  Map<String, int> _currentSeasonStats = {'matches': 0, 'goals': 0, 'assists': 0, 'yellow': 0, 'red': 0};
  Map<String, int> _allTimeStats = {'matches': 0, 'goals': 0, 'assists': 0, 'yellow': 0, 'red': 0};
  double _currentSeasonRating = 0.0;
  double _allTimeRating = 0.0;
  String _currentLeagueName = '';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.2, end: 1.0).animate(_controller);
    _fetchProfile();
    _fetchSeasonStats();
  }

  Future<void> _fetchProfile() async {
    final user = supabase.auth.currentUser;
    if (user != null) {
      try {
        final res = await supabase.from('profiles').select().eq('id', user.id).maybeSingle();
        
        
        Map<String, dynamic>? playRes;
        List<Map<String, dynamic>> forms = [];
        List<Map<String, dynamic>> tRes = [];
        
        try {
           playRes = await supabase.from('players').select('*, teams(name, logo_url)').eq('profile_id', user.id).maybeSingle();
           if (playRes != null) {
             final formsRes = await supabase
                 .from('match_player_stats')
                 .select('rating, matches(match_date)')
                 .eq('player_id', playRes['id'])
                 .order('created_at', ascending: false)
                 .limit(5);
             forms = List<Map<String, dynamic>>.from(formsRes);
           }
        } catch (_) {} 
        
        try {
           final tr = await supabase
               .from('transfer_requests')
               .select('*, teams(name, logo_url)')
               .eq('profile_id', user.id)
               .eq('status', 'pending');
           tRes = List<Map<String, dynamic>>.from(tr);
        } catch (_) {}

        if(mounted) {
           setState(() {
             profileData = res;
             playerStats = playRes;
             recentForms = forms;
             pendingTransfers = tRes;
             isLoading = false;
           });
        }
      } catch (e) {
        if(mounted) setState(() => isLoading = false);
      }
    } else {
      setState(() => isLoading = false);
    }
  }

  
  Future<void> _acceptTransfer(Map<String, dynamic> request) async {
    try {
       
       await supabase.from('transfer_requests').update({'status': 'accepted'}).eq('id', request['id']);
       
       
       final exists = await supabase.from('players').select('id').eq('profile_id', request['profile_id']).maybeSingle();
       if (exists != null) {
          await supabase.from('players').update({'team_id': request['team_id']}).eq('id', exists['id']);
       } else {
          await supabase.from('players').insert({
             'profile_id': request['profile_id'],
             'team_id': request['team_id'],
             'name': profileData?['username'] ?? profileData?['full_name'] ?? 'Yeni Oyuncu',
             'position': 'YEDEK',
             'number': 99
          });
       }
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Takıma Katıldınız!")));
       _fetchProfile(); 
    } catch(e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red));
    }
  }

  Future<void> _fetchSeasonStats() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      final player = await supabase
          .from('players')
          .select('id')
          .eq('profile_id', user.id)
          .maybeSingle();
      if (player == null) return;
      final playerId = player['id'] as String;

      
      final goals    = await supabase.from('match_goals').select('id').eq('player_id', playerId);
      final assists  = await supabase.from('match_goals').select('id').eq('assist_player_id', playerId);
      final cards    = await supabase.from('match_cards').select('card_type').eq('player_id', playerId);
      final ratings  = await supabase.from('match_player_stats').select('rating').eq('player_id', playerId);

      int yellow = 0, red = 0;
      for (final c in cards) {
        if (c['card_type'] == 'yellow') yellow++;
        else if (c['card_type'] == 'red') red++;
      }
      double totalRating = 0;
      for (final r in ratings) { totalRating += double.tryParse(r['rating'].toString()) ?? 0; }
      final avgRating = ratings.isNotEmpty ? totalRating / ratings.length : 0.0;

      
      String leagueName = 'Devler Ligi';
      try {
        final league = await supabase.from('leagues').select('name').order('created_at', ascending: false).limit(1).maybeSingle();
        if (league != null) leagueName = league['name'] as String? ?? 'Devler Ligi';
      } catch (_) {}

      if (mounted) {
        setState(() {
          _currentSeasonStats = {
            'matches': ratings.length,
            'goals': goals.length,
            'assists': assists.length,
            'yellow': yellow,
            'red': red,
          };
          _allTimeStats = {
            'matches': ratings.length,
            'goals': goals.length,
            'assists': assists.length,
            'yellow': yellow,
            'red': red,
          };
          _currentSeasonRating = avgRating;
          _allTimeRating = avgRating;
          _currentLeagueName = leagueName;
        });
      }
    } catch (e) {
      debugPrint('Season stats error: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.greenAccent)));
    }

    final String name = (profileData?['username'] as String?) ?? (profileData?['full_name'] as String?) ?? "FUTBOLCU";
    final String shortId = (profileData?['short_id'] as String?) ?? "#0000";
    final String position = (profileData?['preferred_position'] as String?) ?? (playerStats?['position'] as String?) ?? "FOR";
    final String teamName = (playerStats?['teams']?['name'] as String?) ?? "SERBEST";
    final String teamLogo = (playerStats?['teams']?['logo_url'] as String?) ?? "";
    final String number = playerStats?['number']?.toString() ?? "99";
    
    
    final String height = profileData?['height']?.toString() ?? "Bilinmiyor";
    final String weight = profileData?['weight']?.toString() ?? "Bilinmiyor";
    final String age = profileData?['age']?.toString() ?? "Bilinmiyor";
    final String foot = profileData?['dominant_foot']?.toString() ?? "Bilinmiyor";

    
    final String? futPhotoUrl = profileData?['fut_photo_url'] as String?;
    final int futPac = (profileData?['fut_pac'] as int?) ?? 75;
    final int futSho = (profileData?['fut_sho'] as int?) ?? 75;
    final int futPas = (profileData?['fut_pas'] as int?) ?? 75;
    final int futDri = (profileData?['fut_dri'] as int?) ?? 75;
    final int futDef = (profileData?['fut_def'] as int?) ?? 75;
    final int futPhy = (profileData?['fut_phy'] as int?) ?? 75;
    final int ovr = ((futPac + futSho + futPas + futDri + futDef + futPhy) / 6).round();

    return Scaffold(
      backgroundColor: const Color(0xFF0B101E),
      body: Column(
        children: [
          const CustomNavBar(showBackButton: true),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    const Text(
                      "OYUNCU KARTI",
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 3,
                        shadows: [Shadow(color: Color(0xFF00FF7F), blurRadius: 15)],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      teamName.toUpperCase(),
                      style: const TextStyle(fontSize: 16, color: Colors.white54, letterSpacing: 2),
                    ),
                    const SizedBox(height: 6),
                    
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.greenAccent.withOpacity(0.5)),
                      ),
                      child: Text(
                        shortId,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.greenAccent, letterSpacing: 3),
                      ),
                    ),
                    const SizedBox(height: 20),

                    
                    if (pendingTransfers.isNotEmpty) _buildPendingTransfers(),

                    const SizedBox(height: 30),
                    
                    
                    _buildFutCard(name, position, number, ovr, teamLogo, futPhotoUrl, futPac, futSho, futPas, futDri, futDef, futPhy),

                    const SizedBox(height: 30),
                    
                    
                    _buildPhysicalAttributes(height, weight, age, foot),

                    const SizedBox(height: 40),
                    
                    
                    _buildFormTracker(),

                    const SizedBox(height: 40),

                    
                    _buildSeasonPerformance(),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  
  Widget _buildSeasonPerformance() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          
          Row(
            children: [
              Container(width: 4, height: 24, decoration: BoxDecoration(color: const Color(0xFF00FF7F), borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 10),
              const Text('SEZON PERFORMANSI',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            ],
          ),
          const SizedBox(height: 16),

          
          LayoutBuilder(builder: (context, constraints) {
            final isWide = constraints.maxWidth > 500;
            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildStatCard(isCurrent: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildStatCard(isCurrent: false)),
                ],
              );
            }
            return Column(children: [
              _buildStatCard(isCurrent: true),
              const SizedBox(height: 12),
              _buildStatCard(isCurrent: false),
            ]);
          }),
        ],
      ),
    );
  }

  Widget _buildStatCard({required bool isCurrent}) {
    final stats = isCurrent ? _currentSeasonStats : _allTimeStats;
    final rating = isCurrent ? _currentSeasonRating : _allTimeRating;
    final Color accentColor = isCurrent ? const Color(0xFF00FF7F) : Colors.white54;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withOpacity(0.3), width: 1.5),
        boxShadow: [BoxShadow(color: accentColor.withOpacity(0.05), blurRadius: 12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          
          Row(
            children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isCurrent ? 'Mevcut Sezon' : 'Tüm Sezonlar',
                  style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
          if (isCurrent && _currentLeagueName.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF00FF7F).withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF00FF7F).withOpacity(0.4)),
              ),
              child: Text(_currentLeagueName,
                  style: const TextStyle(color: Color(0xFF00FF7F), fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
          const SizedBox(height: 14),

          
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.2,
            children: [
              _buildStatTile('Maç Sayısı', stats['matches']!.toString(), Colors.white, isCurrent),
              _buildStatTile('Gol', stats['goals']!.toString(), Colors.greenAccent, isCurrent),
              _buildStatTile('Asist', stats['assists']!.toString(), Colors.white70, isCurrent),
              _buildStatTile('Sarı Kart', stats['yellow']!.toString(), Colors.amber, isCurrent),
              _buildStatTile('Kırmızı Kart', stats['red']!.toString(), Colors.redAccent, isCurrent),
              _buildStatTile('Rating', rating.toStringAsFixed(1), Colors.blueAccent, isCurrent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile(String label, String value, Color valueColor, bool isCurrent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isCurrent ? const Color(0xFF0B101E) : const Color(0xFF111827),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value,
              style: TextStyle(color: valueColor, fontWeight: FontWeight.bold, fontSize: 20, height: 1.1)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Future<void> _rejectTransfer(Map<String, dynamic> request) async {
    try {
       await supabase.from('transfer_requests').update({'status': 'rejected'}).eq('id', request['id']);
       _fetchProfile();
    } catch(e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red));
    }
  }

  Widget _buildFutCard(String name, String position, String number, int ovr, String teamLogo, String? futPhotoUrl, int pac, int sho, int pas, int dri, int def, int phy) {
    
    final List<Color> cardColors;
    if (ovr >= 90) {
      cardColors = [const Color(0xFFB8860B), const Color(0xFF8B6914), const Color(0xFF4A3000)];
    } else if (ovr >= 85) {
      cardColors = [const Color(0xFF6A1B9A), const Color(0xFF4A148C), const Color(0xFF1A0040)];
    } else if (ovr >= 80) {
      cardColors = [const Color(0xFF0D47A1), const Color(0xFF1565C0), const Color(0xFF002171)];
    } else {
      cardColors = [const Color(0xFF1B5E20), const Color(0xFF2E7D32), const Color(0xFF003300)];
    }

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          width: 300,
          height: 490,
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD700).withOpacity(_glowAnimation.value * 0.4),
                blurRadius: 40,
                spreadRadius: 5,
              ),
              const BoxShadow(
                color: Colors.black54,
                blurRadius: 15,
                offset: Offset(0, 10),
              )
            ],
          ),
          child: Stack(
            children: [
              
              ClipPath(
                clipper: FutCardClipper(),
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFFFDF00), Color(0xFFD4AF37), Color(0xFF996515)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),

              
              Positioned.fill(
                left: 4, top: 4, right: 4, bottom: 4,
                child: ClipPath(
                  clipper: FutCardClipper(),
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF141414), Color(0xFF0A0A0A)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Stack(
                      children: [
                        
                        Positioned(
                          top: 36,
                          left: 26,
                          child: Column(
                            children: [
                              Text(
                                ovr.toString(),
                                style: const TextStyle(color: Color(0xFFFFD700), fontSize: 44, fontWeight: FontWeight.bold, height: 1.0),
                              ),
                              Text(
                                position,
                                style: const TextStyle(color: Color(0xFFFFD700), fontSize: 22, fontWeight: FontWeight.normal, height: 1.0),
                              ),
                              const SizedBox(height: 5),
                              teamLogo.isNotEmpty 
                                  ? Image.network(teamLogo, width: 35, height: 35, fit: BoxFit.contain, errorBuilder: (c,e,s) => const Icon(Icons.shield, color: Colors.white, size: 28))
                                  : const Icon(Icons.shield, color: Colors.white, size: 28), 
                            ],
                          ),
                        ),

                        
                        Positioned(
                          top: 46,
                          right: -24,
                          child: ShaderMask(
                            shaderCallback: (Rect bounds) {
                              return const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.black, Colors.black, Colors.transparent],
                                stops: [0.0, 0.75, 1.0],
                              ).createShader(bounds);
                            },
                            blendMode: BlendMode.dstIn,
                            child: ShaderMask(
                              shaderCallback: (Rect bounds) {
                                return const LinearGradient(
                                  begin: Alignment.centerRight,
                                  end: Alignment.centerLeft,
                                  colors: [Colors.black, Colors.black, Colors.transparent],
                                  stops: [0.0, 0.7, 1.0],
                                ).createShader(bounds);
                              },
                              blendMode: BlendMode.dstIn,
                              child: futPhotoUrl != null && futPhotoUrl.isNotEmpty
                                  ? Image.network(
                                      futPhotoUrl,
                                      height: 200,
                                      width: 200,
                                      fit: BoxFit.cover,
                                      alignment: Alignment.topCenter,
                                      errorBuilder: (context, error, stackTrace) =>
                                          const Icon(Icons.person, size: 200, color: Colors.white24),
                                    )
                                  : Image.network(
                                      'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/448.png',
                                      height: 200,
                                      width: 200,
                                      fit: BoxFit.cover,
                                      alignment: Alignment.topCenter,
                                      errorBuilder: (context, error, stackTrace) =>
                                          const Icon(Icons.person, size: 200, color: Colors.white24),
                                    ),
                            ),
                          ),
                        ),

                        
                        Positioned(
                          bottom: 26,
                          left: 0,
                          right: 0,
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    name.toUpperCase(),
                                    style: const TextStyle(
                                      fontFamily: 'Impact',
                                      color: Color(0xFFFFD700),
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                margin: const EdgeInsets.symmetric(horizontal: 36, vertical: 8),
                                height: 1,
                                color: const Color(0xFFFFDF00).withOpacity(0.5),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 36),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    _buildStatColumn(pac.toString(), sho.toString(), pas.toString()),
                                    Container(width: 1, height: 70, color: const Color(0xFFFFDF00).withOpacity(0.5)),
                                    _buildStatColumn(dri.toString(), def.toString(), phy.toString()),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                margin: const EdgeInsets.symmetric(horizontal: 76),
                                height: 1,
                                color: const Color(0xFFFFDF00).withOpacity(0.5),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                "#$number | AMATÖR LİG GURURU",
                                style: const TextStyle(color: Color(0xFFFFD700), fontSize: 12, letterSpacing: 1, fontWeight: FontWeight.bold),
                              )
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatColumn(String v1, String v2, String v3) {
    final labels = ['HIZ', 'ŞUT', 'PAS', 'DRI', 'DEF', 'FİZ'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _statRow(v1, labels[0]),
        _statRow(v2, labels[1]),
        _statRow(v3, labels[2]),
      ],
    );
  }

  Widget _statRow(String val, String label) {
    return Row(
      children: [
        SizedBox(width: 30, child: Text(val, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 16)),
      ],
    );
  }

  
  Widget _buildPhysicalAttributes(String height, String weight, String age, String foot) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
         color: const Color(0xFF131B2F),
         borderRadius: BorderRadius.circular(15),
         border: Border.all(color: Colors.white12),
         boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10)]
      ),
      child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("OYUNCU DETAYLARI", style: TextStyle(color: Color(0xFF00FF7F), fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                TextButton.icon(
                  onPressed: () {
                    context.push('/edit-profile').then((_) => _fetchProfile());
                  }, 
                  icon: const Icon(Icons.edit, color: Colors.white70, size: 16), 
                  label: const Text("Düzenle", style: TextStyle(color: Colors.white70))
                )
              ],
            ),
            const Divider(color: Colors.white24, height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildAttrItem(Icons.height, "Boy", height),
                _buildAttrItem(Icons.monitor_weight, "Kilo", weight),
                _buildAttrItem(Icons.calendar_month, "Yaş", age),
                _buildAttrItem(Icons.sports_soccer, "Ayak", foot),
              ],
            )
         ],
      ),
    );
  }

  Widget _buildAttrItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.white54, size: 28),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
      ],
    );
  }

  
  Widget _buildFormTracker() {
    if (recentForms.isEmpty) {
      return const Column(
        children: [
          Text("FORM DURUMU", style: TextStyle(color: Colors.white54, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2)),
          SizedBox(height: 10),
          Text("Henüz maç verisi bulunmuyor.", style: TextStyle(color: Colors.white38)),
        ],
      );
    }
    
    return Column(
      children: [
        const Text("FORM DURUMU", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2)),
        const SizedBox(height: 15),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: recentForms.map((f) {
            double r = double.tryParse(f['rating'].toString()) ?? 0.0;
            Color c = r >= 8 ? Colors.greenAccent : (r >= 6 ? Colors.orangeAccent : Colors.redAccent);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: c.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(color: c, width: 2),
                boxShadow: [
                  BoxShadow(color: c.withOpacity(0.3), blurRadius: 10, spreadRadius: 1)
                ],
              ),
              alignment: Alignment.center,
              child: Text(r.toStringAsFixed(1), style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 16)),
            );
          }).toList(),
        )
      ],
    );
  }

  
  Widget _buildPendingTransfers() {
    return Container(
      width: 300,
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent, width: 2),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.redAccent,
              borderRadius: BorderRadius.vertical(top: Radius.circular(10))
            ),
            child: const Text("GELEN TRANSFER TEKLİFİ", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          ...pendingTransfers.map((req) {
            String team = req['teams']['name'];
            return Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Text("$team seni takımına katmak istiyor!", textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () => _rejectTransfer(req),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.black45, foregroundColor: Colors.white),
                        child: const Text("REDDET"),
                      ),
                      ElevatedButton(
                        onPressed: () => _acceptTransfer(req),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black),
                        child: const Text("ONAYLA", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  )
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}


class FutCardClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.moveTo(size.width * 0.1, 0);
    path.lineTo(size.width * 0.9, 0);
    path.lineTo(size.width, size.height * 0.1);
    path.lineTo(size.width, size.height * 0.9);
    path.lineTo(size.width * 0.5, size.height);
    path.lineTo(0, size.height * 0.9);
    path.lineTo(0, size.height * 0.1);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

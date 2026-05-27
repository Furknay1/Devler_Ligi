import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:devler_ligi/main.dart';
import 'package:devler_ligi/widgets/team_logo.dart';


const _lineupSlots = [
  {'key': 'FOR_SOL',  'label': 'Sol Kanat',  'x': 0.20, 'y': 0.10},
  {'key': 'FOR_SAĞ',  'label': 'Sağ Kanat',  'x': 0.80, 'y': 0.10},
  {'key': 'ORT_SOL',  'label': 'Sol Orta',   'x': 0.25, 'y': 0.35},
  {'key': 'ORT_SAĞ',  'label': 'Sağ Orta',   'x': 0.75, 'y': 0.35},
  {'key': 'DEF_SOL',  'label': 'Sol Bek',    'x': 0.22, 'y': 0.62},
  {'key': 'DEF_SAĞ',  'label': 'Sağ Bek',    'x': 0.78, 'y': 0.62},
  {'key': 'KALECİ',   'label': 'Kaleci',     'x': 0.50, 'y': 0.88},
];

const _subSlots = [
  {'key': 'YEDEK_1', 'label': 'Yedek'},
  {'key': 'YEDEK_2', 'label': 'Yedek'},
  {'key': 'YEDEK_3', 'label': 'Yedek'},
  {'key': 'YEDEK_4', 'label': 'Yedek'},
];

class TeamDetailPage extends StatefulWidget {
  final String teamId;
  const TeamDetailPage({super.key, required this.teamId});

  @override
  State<TeamDetailPage> createState() => _TeamDetailPageState();
}

class _TeamDetailPageState extends State<TeamDetailPage> {
  bool _isLoading = true;
  String _error = '';

  Map<String, dynamic>? _team;
  String _captainName = 'Belirtilmedi';
  List<Map<String, dynamic>> _players = [];
  List<Map<String, dynamic>> _lastMatches = [];
  Map<String, dynamic>? _topScorer;
  Map<String, dynamic>? _topAssister;
  Map<String, dynamic>? _goalkeeper;
  Map<String, dynamic>? _starPlayer; 
  Map<String, String> _lineup = {};
  Map<String, Map<String, dynamic>> _playerMap = {};

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    try {
      
      final teamData = await supabase
          .from('teams')
          .select('id, name, short_name, logo_url, owner_id, created_at, lineup')
          .eq('id', widget.teamId)
          .maybeSingle();

      if (teamData == null) {
        if (mounted) setState(() { _error = 'Takım bulunamadı (id: ${widget.teamId})'; _isLoading = false; });
        return;
      }
      _team = teamData;

      
      try {
        final rawLineup = teamData['lineup'];
        if (rawLineup is Map) {
          _lineup = Map<String, String>.from(
            rawLineup.map((k, v) => MapEntry(k.toString(), v.toString())),
          );
        } else if (rawLineup is String) {
          final decoded = jsonDecode(rawLineup);
          if (decoded is Map) {
            _lineup = Map<String, String>.from(
              decoded.map((k, v) => MapEntry(k.toString(), v.toString())),
            );
          }
        }
      } catch (_) {}

      
      try {
        final prof = await supabase
            .from('profiles')
            .select('username, full_name')
            .eq('id', teamData['owner_id'])
            .maybeSingle();
        if (prof != null) {
          _captainName = (prof['username'] ?? prof['full_name'] ?? 'Belirtilmedi') as String;
        }
      } catch (_) {}

      
      final playersRaw = await supabase
          .from('players')
          .select('id, name, position, number, profile_id')
          .eq('team_id', widget.teamId)
          .order('number', ascending: true);
      _players = List<Map<String, dynamic>>.from(playersRaw);
      _playerMap = {for (final p in _players) p['id'].toString(): p};

      
      for (final p in _players) {
        if (p['profile_id'] != null) {
          try {
            final prof = await supabase
                .from('profiles')
                .select('preferred_position')
                .eq('id', p['profile_id'])
                .maybeSingle();
            p['preferred_position'] = prof?['preferred_position'];
          } catch (_) {}
        }
      }

      
      final goals = await supabase
          .from('match_goals')
          .select('player_id, assist_player_id')
          .eq('team_id', widget.teamId);

      final ratings = await supabase
          .from('match_player_stats')
          .select('player_id, rating');

      Map<String, int> goalMap = {};
      Map<String, int> assistMap = {};
      for (final g in goals) {
        final pid = g['player_id']?.toString() ?? '';
        final aid = g['assist_player_id']?.toString() ?? '';
        goalMap[pid] = (goalMap[pid] ?? 0) + 1;
        if (aid.isNotEmpty) assistMap[aid] = (assistMap[aid] ?? 0) + 1;
      }

      Map<String, double> ratingSum = {};
      Map<String, int> ratingCount = {};
      for (final r in ratings) {
        final pid = r['player_id']?.toString() ?? '';
        final val = double.tryParse(r['rating'].toString()) ?? 0;
        ratingSum[pid] = (ratingSum[pid] ?? 0) + val;
        ratingCount[pid] = (ratingCount[pid] ?? 0) + 1;
      }

      for (final p in _players) {
        final pid = p['id'].toString();
        p['goals'] = goalMap[pid] ?? 0;
        p['assists'] = assistMap[pid] ?? 0;
        final rc = ratingCount[pid] ?? 0;
        p['avgRating'] = rc > 0 ? (ratingSum[pid]! / rc) : 0.0;
        p['matchCount'] = rc;
      }

      
      final byGoal = [..._players]..sort((a, b) => (b['goals'] as int).compareTo(a['goals'] as int));
      final byAssist = [..._players]..sort((a, b) => (b['assists'] as int).compareTo(a['assists'] as int));
      final byRating = [..._players]..sort((a, b) => (b['avgRating'] as double).compareTo(a['avgRating'] as double));
      _topScorer = byGoal.isNotEmpty ? byGoal.first : null;
      _topAssister = byAssist.isNotEmpty ? byAssist.first : null;
      _starPlayer = byRating.isNotEmpty && (byRating.first['matchCount'] as int) > 0 ? byRating.first : null;

      
      _goalkeeper = _players.where((p) {
        final pos = ((p['preferred_position'] ?? p['position']) ?? '').toString().toUpperCase();
        return pos.contains('KAL') || pos.contains('GK') || pos.contains('GOALKEEPER');
      }).firstOrNull;

      
      try {
        final matchData = await supabase
            .from('matches')
            .select('id, home_team_id, away_team_id, home_score, away_score, match_date, status')
            .or('home_team_id.eq.${widget.teamId},away_team_id.eq.${widget.teamId}')
            .eq('status', 'finished')
            .order('match_date', ascending: false)
            .limit(5);

        
        for (final m in matchData) {
          final homeTeam = await supabase.from('teams').select('name, logo_url').eq('id', m['home_team_id']).maybeSingle();
          final awayTeam = await supabase.from('teams').select('name, logo_url').eq('id', m['away_team_id']).maybeSingle();
          m['home_team'] = homeTeam;
          m['away_team'] = awayTeam;
        }
        _lastMatches = List<Map<String, dynamic>>.from(matchData);
      } catch (_) {}

    } catch (e) {
      debugPrint('TeamDetail HATA: $e');
      if (mounted) setState(() { _error = 'Bir hata oluştu: $e'; });
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFF00FF7F))),
      );
    }

    if (_team == null || _error.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white), onPressed: () => Navigator.pop(context)),
          title: const Text('Takım', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 60, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(_error.isNotEmpty ? _error : 'Takım bulunamadı.', style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              Text('Team ID: ${widget.teamId}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(builder: (context, constraints) {
          final isWide = constraints.maxWidth > 700;
          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: constraints.maxWidth * 0.45,
                  child: Column(children: [
                    _buildTeamInfoCard(),
                    const SizedBox(height: 16),
                    _buildLineupCard(),
                  ]),
                ),
                const SizedBox(width: 16),
                Expanded(child: Column(children: [
                  _buildKeyPlayersCard(),
                  const SizedBox(height: 16),
                  _buildLastMatchesCard(),
                ])),
              ],
            );
          }
          
          return Column(children: [
            _buildTeamInfoCard(),
            const SizedBox(height: 16),
            _buildKeyPlayersCard(),
            const SizedBox(height: 16),
            _buildLineupCard(),
            const SizedBox(height: 16),
            _buildLastMatchesCard(),
            const SizedBox(height: 40),
          ]);
        }),
      ),
    );
  }

  
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          TeamLogo(url: _team!['logo_url'], size: 32),
          const SizedBox(width: 10),
          Text(
            (_team!['name'] as String).toUpperCase(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }

  
  Widget _buildTeamInfoCard() {
    final createdAt = DateTime.tryParse(_team!['created_at'] ?? '');
    final dateStr = createdAt != null
        ? '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}'
        : 'Bilinmiyor';

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle('TAKIM BİLGİLERİ'),
          const SizedBox(height: 14),
          Row(
            children: [
              TeamLogo(url: _team!['logo_url'], size: 80),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (_team!['name'] as String).toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                    ),
                    if (_team!['short_name'] != null) ...[
                      const SizedBox(height: 4),
                      Text(_team!['short_name'] as String,
                          style: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w500)),
                    ],
                    const SizedBox(height: 12),
                    _infoRow('KURULUŞ', dateStr),
                    const SizedBox(height: 6),
                    _infoRowGreen('KAPTAN', _captainName),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      children: [
        SizedBox(width: 72, child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.w600, letterSpacing: 0.5))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500))),
      ],
    );
  }

  Widget _infoRowGreen(String label, String value) {
    return Row(
      children: [
        SizedBox(width: 72, child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.w600, letterSpacing: 0.5))),
        Text(value, style: const TextStyle(fontSize: 13, color: Color(0xFF00FF7F), fontWeight: FontWeight.bold)),
      ],
    );
  }

  
  Widget _buildLineupCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle('İLK 11 KADROSU'),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 0.75,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CustomPaint(
                painter: _PitchPainter(),
                child: LayoutBuilder(builder: (ctx, c) {
                  return Stack(
                    children: [
                      for (final slot in _lineupSlots)
                        _buildPitchPin(slot, c.maxWidth, c.maxHeight),
                    ],
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Center(child: Text('YEDEKLER', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1))),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final slot in _subSlots)
                _buildSubSlot(slot),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPitchPin(Map<String, dynamic> slot, double w, double h) {
    final key = slot['key'] as String;
    final x = (slot['x'] as double) * w;
    final y = (slot['y'] as double) * h;
    final playerId = _lineup[key];
    final player = playerId != null ? _playerMap[playerId] : null;
    final hasPlayer = player != null;
    final name = hasPlayer ? (player['name'] as String) : '';

    return Positioned(
      left: x - 32,
      top: y - 38,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: hasPlayer ? const Color(0xFF00FF7F) : Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: hasPlayer ? Colors.white : Colors.white38, width: hasPlayer ? 2 : 1),
              boxShadow: hasPlayer ? [BoxShadow(color: const Color(0xFF00FF7F).withOpacity(0.5), blurRadius: 8)] : [],
            ),
            child: Center(
              child: hasPlayer
                  ? Text('${player['number'] ?? '?'}',
                      style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 13))
                  : const Icon(Icons.person_outline, color: Colors.white38, size: 18),
            ),
          ),
          if (name.isNotEmpty) ...[
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(5)),
              child: Text(
                name.split(' ').last.length > 9
                    ? name.split(' ').last.substring(0, 8).toUpperCase()
                    : name.split(' ').last.toUpperCase(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 8),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubSlot(Map<String, dynamic> slot) {
    final key = slot['key'] as String;
    final playerId = _lineup[key];
    final player = playerId != null ? _playerMap[playerId] : null;
    final hasPlayer = player != null;
    final name = hasPlayer ? (player['name'] as String) : '';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: hasPlayer ? const Color(0xFF00FF7F).withOpacity(0.8) : Colors.white.withOpacity(0.05),
            shape: BoxShape.circle,
            border: Border.all(color: hasPlayer ? Colors.white : Colors.white24, width: 1.5),
          ),
          child: Center(
            child: hasPlayer
                ? Text('${player['number'] ?? '?'}', style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 12))
                : const Icon(Icons.person_outline, color: Colors.white38, size: 16),
          ),
        ),
        if (name.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            name.split(' ').last.length > 7
                ? name.split(' ').last.substring(0, 6).toUpperCase()
                : name.split(' ').last.toUpperCase(),
            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 8),
          ),
        ],
      ],
    );
  }

  
  Widget _buildKeyPlayersCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle('ÖNEMLİ OYUNCULAR'),
          const SizedBox(height: 12),
          _keyPlayerRow(
            'ASİST KRALI',
            _topAssister,
            _topAssister != null ? '${_topAssister!['assists']} asist' : 'veri yok',
          ),
          _divider(),
          _keyPlayerRow(
            'KURTARIŞ KRALI',
            _goalkeeper,
            _goalkeeper != null
                ? 'Ort. ${(_goalkeeper!['avgRating'] as double).toStringAsFixed(1)} rating'
                : 'veri yok',
          ),
          _divider(),
          _keyPlayerRow(
            'GOLCÜ',
            _topScorer,
            _topScorer != null ? '${_topScorer!['goals']} gol' : 'veri yok',
          ),
          _divider(),
          _keyPlayerRow(
            'YILDIZ OYUNCU',
            _starPlayer,
            _starPlayer != null
                ? '${(_starPlayer!['avgRating'] as double).toStringAsFixed(1)} rating'
                : 'veri yok',
          ),
        ],
      ),
    );
  }

  Widget _keyPlayerRow(String role, Map<String, dynamic>? player, String detail) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(role,
                style: const TextStyle(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
          ),
          Container(
            width: 36, height: 36,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF131B2F),
            ),
            child: const Icon(Icons.person, color: Color(0xFF00FF7F), size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player != null ? (player['name'] as String) : '—',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF00FF7F)),
                ),
                Text(detail, style: const TextStyle(fontSize: 11, color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  
  Widget _buildLastMatchesCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _cardTitle('SON MAÇLAR')),
              if (_lastMatches.isNotEmpty)
                const Text('TÜM MAÇLAR ›', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          if (_lastMatches.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: Text('Henüz maç verisi yok.', style: TextStyle(color: Colors.white54))),
            )
          else
            ...(_lastMatches.map((m) => _buildMatchRow(m))),
        ],
      ),
    );
  }

  Widget _buildMatchRow(Map<String, dynamic> m) {
    final isHome = m['home_team_id'] == widget.teamId;
    final homeTeam = m['home_team'] as Map<String, dynamic>?;
    final awayTeam = m['away_team'] as Map<String, dynamic>?;
    final homeScore = m['home_score'] ?? 0;
    final awayScore = m['away_score'] ?? 0;

    final date = DateTime.tryParse(m['match_date'] ?? '');
    final months = ['', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
    final dateStr = date != null ? '${date.day} ${months[date.month]} ${date.year}' : '';

    return Column(
      children: [
        if (dateStr.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 4),
            child: Text(dateStr, style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ),
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF131B2F),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Row(
            children: [
              TeamLogo(url: homeTeam?['logo_url'], size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  homeTeam?['name'] ?? '?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isHome ? const Color(0xFF00FF7F) : Colors.white,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(color: const Color(0xFF0B101E), borderRadius: BorderRadius.circular(8)),
                child: Text(
                  '$homeScore  –  $awayScore',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white, letterSpacing: 1),
                ),
              ),
              Expanded(
                child: Text(
                  awayTeam?['name'] ?? '?',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: !isHome ? const Color(0xFF00FF7F) : Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TeamLogo(url: awayTeam?['logo_url'], size: 28),
            ],
          ),
        ),
      ],
    );
  }

  
  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: child,
    );
  }

  Widget _cardTitle(String text) {
    return Row(
      children: [
        Container(width: 4, height: 20, decoration: BoxDecoration(color: const Color(0xFF00FF7F), borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white, letterSpacing: 0.3)),
      ],
    );
  }

  Widget _divider() => const Divider(height: 1, color: Colors.white12);
}


class _PitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    
    for (int i = 0; i < 10; i++) {
      final x = i * w / 10;
      final paint = Paint()..color = i.isEven ? const Color(0xFF133621) : const Color(0xFF0F2B1A);
      canvas.drawRect(Rect.fromLTWH(x, 0, w / 10, h), paint);
    }

    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    
    canvas.drawRect(Rect.fromLTRB(w * 0.04, h * 0.015, w * 0.96, h * 0.985), linePaint);
    
    canvas.drawLine(Offset(w * 0.04, h * 0.5), Offset(w * 0.96, h * 0.5), linePaint);
    
    canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.16, linePaint);
    canvas.drawCircle(Offset(w * 0.5, h * 0.5), 3.5, Paint()..color = Colors.white.withOpacity(0.6));

    
    final penW = w * 0.62; final penH = h * 0.17;
    canvas.drawRect(Rect.fromLTWH((w - penW) / 2, h * 0.015, penW, penH), linePaint);
    
    final sW = w * 0.30; final sH = h * 0.07;
    canvas.drawRect(Rect.fromLTWH((w - sW) / 2, h * 0.015, sW, sH), linePaint);
    
    canvas.drawRect(Rect.fromLTWH((w - penW) / 2, h * 0.985 - penH, penW, penH), linePaint);
    
    canvas.drawRect(Rect.fromLTWH((w - sW) / 2, h * 0.985 - sH, sW, sH), linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

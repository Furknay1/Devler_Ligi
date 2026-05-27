import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:devler_ligi/main.dart';
import 'package:devler_ligi/widgets/team_logo.dart';
import 'package:devler_ligi/widgets/custom_nav_bar.dart';
import 'package:devler_ligi/widgets/player_profile_dialog.dart';

class MyTeamPage extends StatefulWidget {
  const MyTeamPage({super.key});

  @override
  State<MyTeamPage> createState() => _MyTeamPageState();
}

class _MyTeamPageState extends State<MyTeamPage> {
  bool isLoading = true;
  bool isUploading = false;
  Map<String, dynamic>? myTeam;
  Map<String, dynamic>? pendingRequest;
  List<Map<String, dynamic>> myPlayers = [];

  List<Map<String, dynamic>> availableLeagues = [];
  String? selectedLeagueId;

  
  Map<String, String> _lineup = {}; 

  static const _lineupSlots = [
    {'key': 'FOR_SOL',  'label': 'Sol Kanat',  'x': 0.20, 'y': 0.10},
    {'key': 'FOR_SAĞ',  'label': 'Sağ Kanat',  'x': 0.80, 'y': 0.10},
    {'key': 'ORT_SOL',  'label': 'Sol Orta',   'x': 0.25, 'y': 0.35},
    {'key': 'ORT_SAĞ',  'label': 'Sağ Orta',   'x': 0.75, 'y': 0.35},
    {'key': 'DEF_SOL',  'label': 'Sol Bek',    'x': 0.22, 'y': 0.62},
    {'key': 'DEF_SAĞ',  'label': 'Sağ Bek',    'x': 0.78, 'y': 0.62},
    {'key': 'KALECİ',   'label': 'Kaleci',     'x': 0.50, 'y': 0.88},
  ];

  static const _subSlots = [
    {'key': 'YEDEK_1', 'label': 'Yedek'},
    {'key': 'YEDEK_2', 'label': 'Yedek'},
    {'key': 'YEDEK_3', 'label': 'Yedek'},
    {'key': 'YEDEK_4', 'label': 'Yedek'},
  ];

  final _teamNameController = TextEditingController();
  final _teamShortNameController = TextEditingController();
  File? _logoFile;
  final ImagePicker _picker = ImagePicker();

  
  bool get _isOwner =>
      myTeam != null &&
      supabase.auth.currentUser != null &&
      myTeam!['owner_id'] == supabase.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    setState(() => isLoading = true);
    final userId = supabase.auth.currentUser!.id;
    try {
      final leaguesData =
          await supabase.from('leagues').select('id, name').order('name');
      final fetchedLeagues = List<Map<String, dynamic>>.from(leaguesData);
      availableLeagues = fetchedLeagues;
      if (fetchedLeagues.isNotEmpty && selectedLeagueId == null) {
        selectedLeagueId = fetchedLeagues.first['id'];
      }

      final teamData = await supabase
          .from('teams')
          .select()
          .eq('owner_id', userId)
          .limit(1)
          .maybeSingle();
      if (teamData != null) {
        myTeam = teamData;
        await _getMyPlayersWithStats(teamData['id']);
      } else {
        final requestData = await supabase
            .from('team_requests')
            .select()
            .eq('user_id', userId)
            .eq('status', 'pending')
            .limit(1)
            .maybeSingle();
        pendingRequest = requestData;
      }
    } catch (e) {
      debugPrint("Hata: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  
  Future<bool> _isPlayerInATeam() async {
    final userId = supabase.auth.currentUser!.id;
    final playerRecord = await supabase
        .from('players')
        .select('id, team_id')
        .eq('profile_id', userId)
        .maybeSingle();
    return playerRecord != null && playerRecord['team_id'] != null;
  }

  Future<void> _loadLineup() async {
    if (myTeam == null) return;
    try {
      final data = await supabase.from('teams').select('lineup').eq('id', myTeam!['id']).maybeSingle();
      final rawLineup = data?['lineup'];
      if (rawLineup is Map) {
        setState(() {
          _lineup = Map<String, String>.from(rawLineup.map((k, v) => MapEntry(k.toString(), v.toString())));
        });
      } else if (rawLineup is String) {
        final decoded = jsonDecode(rawLineup);
        if (decoded is Map) {
          setState(() {
            _lineup = Map<String, String>.from(decoded.map((k, v) => MapEntry(k.toString(), v.toString())));
          });
        }
      }
    } catch (e) {
      debugPrint('Lineup load error: $e');
    }
  }

  Future<void> _saveLineup() async {
    if (myTeam == null) return;
    
    if (_lineup.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ Kaydedilecek kadro boş! Lütfen oyuncu seçin.'), backgroundColor: Colors.orange));
      return;
    }

    try {
      final res = await supabase.from('teams').update({'lineup': _lineup}).eq('id', myTeam!['id']).select();
      if (res.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ Kadro kaydedilemedi! Yetki hatası olabilir.'), backgroundColor: Colors.red));
        return;
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Kadro kaydedildi!'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _getMyPlayersWithStats(String teamId) async {
    final playersData = await supabase
        .from('players')
        .select('*, profiles(preferred_position)')
        .eq('team_id', teamId)
        .order('number', ascending: true);
    List<Map<String, dynamic>> players =
        List<Map<String, dynamic>>.from(playersData);

    final goalsData = await supabase
        .from('match_goals')
        .select('player_id, assist_player_id')
        .eq('team_id', teamId);
    final cardsData = await supabase
        .from('match_cards')
        .select('player_id, card_type')
        .eq('team_id', teamId);

    for (var player in players) {
      final pid = player['id'];
      final goalCount = goalsData.where((g) => g['player_id'] == pid).length;
      final assistCount =
          goalsData.where((g) => g['assist_player_id'] == pid).length;
      final yellowCount = cardsData
          .where((c) => c['player_id'] == pid && c['card_type'] == 'yellow')
          .length;
      final redCount = cardsData
          .where((c) => c['player_id'] == pid && c['card_type'] == 'red')
          .length;

      player['stats'] = {
        'goals': goalCount,
        'assists': assistCount,
        'yellows': yellowCount,
        'reds': redCount,
        'isSuspended':
            redCount > 0 || (yellowCount > 0 && yellowCount % 3 == 0)
      };
    }
    setState(() => myPlayers = players);
    await _loadLineup();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) setState(() => _logoFile = File(image.path));
  }

  Future<void> _submitRequest() async {
    if (_teamNameController.text.isEmpty) return;
    if (selectedLeagueId == null) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Lütfen bir lig seçin!")));
      return;
    }

    
    final inTeam = await _isPlayerInATeam();
    if (inTeam) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("⛔ Zaten bir takımda oynuyorsunuz! Takım kurmak için mevcut takımınızdan ayrılmanız gerekir."),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      return;
    }

    setState(() => isUploading = true);
    String? uploadedLogoUrl;
    try {
      if (_logoFile != null) {
        final fileExt = _logoFile!.path.split('.').last;
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        final filePath = 'requests/$fileName';
        await supabase.storage.from('team_logos').upload(filePath, _logoFile!);
        uploadedLogoUrl =
            supabase.storage.from('team_logos').getPublicUrl(filePath);
      }
      await supabase.from('team_requests').insert({
        'user_id': supabase.auth.currentUser!.id,
        'team_name': _teamNameController.text.trim(),
        'short_name': _teamShortNameController.text.trim().toUpperCase(),
        'logo_url': uploadedLogoUrl,
        'league_id': selectedLeagueId,
        'status': 'pending'
      });
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("✅ Başvuru gönderildi!")));
      _checkStatus();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Hata: $e")));
    } finally {
      if (mounted) setState(() => isUploading = false);
    }
  }

  Future<void> _addPlayerDialog() async {
    
    if (myPlayers.length >= 20) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("⛔ Takımınız maksimum 20 oyuncu limitine ulaştı! Yeni oyuncu ekleyemezsiniz."),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      return;
    }

    final nameCtrl = TextEditingController();
    final posCtrl = TextEditingController();
    final numCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text("Yeni Oyuncu Ekle", style: TextStyle(color: Colors.white)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Ad Soyad", labelStyle: TextStyle(color: Colors.grey))),
          TextField(
              controller: posCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Mevki", labelStyle: TextStyle(color: Colors.grey))),
          TextField(
              controller: numCtrl,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Forma No", labelStyle: TextStyle(color: Colors.grey))),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("İptal", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty) return;

              final name = nameCtrl.text.trim();
              final number = int.tryParse(numCtrl.text) ?? 0;
              final exists = myPlayers.any((p) =>
                  p['name'].toString().toLowerCase() == name.toLowerCase() ||
                  (number != 0 && p['number'] == number));

              if (exists) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("Bu oyuncu zaten var!"),
                    backgroundColor: Colors.orange));
                return;
              }

              try {
                await supabase.from('players').insert({
                  'team_id': myTeam!['id'],
                  'name': name,
                  'position': posCtrl.text,
                  'number': number,
                });
                if (mounted) Navigator.pop(context);
                _getMyPlayersWithStats(myTeam!['id']);
              } catch (e) {
                debugPrint("Ekleme hatası: $e");
              }
            },
            child: const Text("EKLE"),
          )
        ],
      ),
    );
  }

  
  Future<void> _editPlayerNumber(Map<String, dynamic> player) async {
    final numCtrl =
        TextEditingController(text: '${player['number'] ?? ''}');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.edit_outlined, color: Color(0xFF00FF7F)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "${player['name']} – Forma No",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        ),
        content: TextField(
          controller: numCtrl,
          style: const TextStyle(color: Colors.white),
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: "Yeni Forma Numarası",
            labelStyle: const TextStyle(color: Colors.grey),
            prefixIcon: const Icon(Icons.pin, color: Color(0xFF00FF7F)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("İptal", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00FF7F),
              foregroundColor: Colors.black87,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final newNum = int.tryParse(numCtrl.text.trim());
              if (newNum == null) return;
              
              final conflict = myPlayers.any(
                  (p) => p['number'] == newNum && p['id'] != player['id']);
              if (conflict) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                    content:
                        Text("Bu forma numarasını başka bir oyuncu kullanıyor!"),
                    backgroundColor: Colors.orange));
                return;
              }
              try {
                await supabase
                    .from('players')
                    .update({'number': newNum})
                    .eq('id', player['id']);
                if (mounted) Navigator.pop(ctx);
                _getMyPlayersWithStats(myTeam!['id']);
              } catch (e) {
                debugPrint("Numara güncelleme hatası: $e");
              }
            },
            child: const Text("KAYDET"),
          ),
        ],
      ),
    );
  }

  
  Future<void> _showDissolutionDialog() async {
    bool isSending = false;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => Dialog(
          backgroundColor: const Color(0xFF1E293B),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.warning_amber_rounded,
                          color: Colors.redAccent, size: 28),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text(
                        "Takım Fesih Talebi",
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                
                _buildDissolutionItem(
                    "Takım kaptanı, takım feshini talep eder ve yönetici onaylar."),
                _buildDissolutionItem(
                    "Onay sonrası kaptan dahil tüm üyeler takımdan düşer."),
                _buildDissolutionItem(
                    "Hiç maç yapmamış takım tamamen kaldırılır, oynanan maçlı takım pasife alınır."),
                _buildDissolutionItem(
                    "Tüm maçlar iptal edilir ve transfer teklifleri iptal olur."),
                _buildDissolutionItem(
                    "Serbest kalan oyuncular ve kaptan yeni takım kurabilir."),

                const SizedBox(height: 16),

                
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.error_outline,
                          color: Colors.redAccent, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Takım için yanlışlıkla fesih talebi verdiyseniz lütfen iletişim formundan bizimle irtibata geçin. "
                          "Yönetici onayı sonrası işlem geri döndürülemeyebilir.",
                          style: TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w600,
                              fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: isSending
                            ? null
                            : () => Navigator.pop(ctx),
                        child: const Text("VAZGEÇ",
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: isSending
                            ? null
                            : () async {
                                setStateDialog(() => isSending = true);
                                try {
                                  
                                  final existing = await supabase
                                      .from('dissolution_requests')
                                      .select()
                                      .eq('team_id', myTeam!['id'])
                                      .eq('status', 'pending')
                                      .limit(1)
                                      .maybeSingle();

                                  if (existing != null) {
                                    if (ctx.mounted) {
                                      Navigator.pop(ctx);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content: Text(
                                                  "⚠️ Zaten bekleyen bir fesih talebiniz var."),
                                              backgroundColor: Colors.orange));
                                    }
                                    return;
                                  }

                                  await supabase
                                      .from('dissolution_requests')
                                      .insert({
                                    'team_id': myTeam!['id'],
                                    'owner_id':
                                        supabase.auth.currentUser!.id,
                                    'status': 'pending',
                                  });

                                  if (ctx.mounted) {
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(const SnackBar(
                                            content: Text(
                                                "✅ Fesih talebiniz admin onayına gönderildi."),
                                            backgroundColor: Colors.green));
                                  }
                                } catch (e) {
                                  setStateDialog(() => isSending = false);
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(SnackBar(
                                            content: Text("Hata: $e"),
                                            backgroundColor: Colors.red));
                                  }
                                }
                              },
                        child: isSending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Text("FESİH TALEBİ GÖNDER",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDissolutionItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 5),
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
                color: Colors.white70, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 14, color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  
  Future<void> _showAddPlayerMenu() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131B2F),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text("Hangi yöntemle oyuncu eklemek istiyorsun?",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
              ),
              ListTile(
                leading: const CircleAvatar(
                    backgroundColor: Color(0xFF00FF7F),
                    child: Icon(Icons.verified, color: Colors.black87)),
                title: const Text("Kayıtlı Oyuncu Transfer Et",
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                subtitle: const Text(
                    "Oyuncunun kimliğini (#1234) girerek resmi davet gönder",
                    style: TextStyle(color: Colors.grey)),
                onTap: () {
                  Navigator.pop(ctx);
                  Future.delayed(const Duration(milliseconds: 150),
                      () => _transferPlayerByIdDialog());
                },
              ),
              const Divider(color: Colors.white24),
              ListTile(
                leading: const CircleAvatar(
                    backgroundColor: Colors.grey,
                    child: Icon(Icons.person_add, color: Colors.white)),
                title: const Text("Sanal (Bot) Oyuncu Ekle", style: TextStyle(color: Colors.white)),
                subtitle: const Text(
                    "Uygulamaya kayıtlı olmayan bir ismi geçici olarak listeye yaz",
                    style: TextStyle(color: Colors.grey)),
                onTap: () {
                  Navigator.pop(ctx);
                  Future.delayed(const Duration(milliseconds: 150),
                      () => _addPlayerDialog());
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Future<void> _transferPlayerByIdDialog() async {
    
    if (myPlayers.length >= 20) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("⛔ Takımınız 20 oyuncu limitine ulaştı! Transfer yapamazsınız."),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      return;
    }

    final idCtrl = TextEditingController(text: "#");
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text("Oyuncu Transfer Et", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                "Transfer etmek istediğiniz oyuncunun Eşsiz Kimliğini girin:",
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 15),
            TextField(
              controller: idCtrl,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: 2, color: Colors.white),
              decoration: const InputDecoration(
                  labelText: "Örn: #9432",
                  labelStyle: TextStyle(color: Colors.grey),
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.search, color: Colors.grey)),
            )
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("İptal", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () async {
              if (idCtrl.text.isEmpty || idCtrl.text.length < 2) return;

              final targetId = idCtrl.text.trim();

              final res = await supabase
                  .from('profiles')
                  .select('id, username')
                  .eq('short_id', targetId)
                  .maybeSingle();

              if (!mounted) return;

              if (res == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("Böyle bir oyuncu bulunamadı! ❌"),
                    backgroundColor: Colors.red));
                return;
              }

              final profileId = res['id'];

              if (profileId == supabase.auth.currentUser!.id) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text(
                        "Kendinizi takımınıza davet edemezsiniz, zaten takımdasınız! 🛑"),
                    backgroundColor: Colors.orange));
                return;
              }

              final existsInTeam =
                  myPlayers.any((p) => p['profile_id'] == profileId);
              if (existsInTeam) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("Bu oyuncu zaten takımınızda! 🛑"),
                    backgroundColor: Colors.orange));
                return;
              }

              try {
                await supabase.from('transfer_requests').insert({
                  'team_id': myTeam!['id'],
                  'profile_id': profileId,
                  'status': 'pending'
                });
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                          "✅ ${res['username'].toString().toUpperCase()} oyuncusuna davet gönderildi!"),
                      backgroundColor: Colors.green));
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text(
                        "Kurallar gereği bu kişiye zaten bekleyen bir teklifiniz var! 🛑"),
                    backgroundColor: Colors.orange));
              }
            },
            child: const Text("TEKLİF GÖNDER",
                style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (isLoading) {
      content = const Center(child: CircularProgressIndicator());
    } else if (pendingRequest != null) {
      content = _buildPendingState();
    } else if (myTeam == null) {
      content = _buildCreateTeamState();
    } else {
      content = _buildTeamViewState();
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          const CustomNavBar(showBackButton: true),
          Expanded(child: content),
        ],
      ),
      floatingActionButton: (myTeam != null && !isLoading && _isOwner)
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'lineup',
                  onPressed: _showLineupEditor,
                  backgroundColor: const Color(0xFF1B5E20),
                  icon: const Icon(Icons.sports_soccer, color: Colors.white),
                  label: const Text('11\'LİK KADRO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                const SizedBox(height: 12),
                FloatingActionButton(
                  heroTag: 'add',
                  onPressed: _showAddPlayerMenu,
                  backgroundColor: const Color(0xFF00FF7F),
                  child: const Icon(Icons.person_add, color: Colors.black87),
                ),
              ],
            )
          : (myTeam != null && !isLoading)
              ? FloatingActionButton(
                  onPressed: _showAddPlayerMenu,
                  backgroundColor: const Color(0xFF00FF7F),
                  child: const Icon(Icons.add, color: Colors.black87),
                )
              : null,
    );
  }

  
  
  
  void _showLineupEditor() {
    
    final editLineup = Map<String, String>.from(_lineup);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) {
          return Dialog(
            backgroundColor: const Color(0xFF0B101E),
            insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1B5E20),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.sports_soccer, color: Colors.white, size: 22),
                      const SizedBox(width: 10),
                      const Expanded(child: Text('11\'LİK KADRO OLUŞTUR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5))),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
                
                Flexible(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          LayoutBuilder(builder: (context, constraints) {
                            final w = constraints.maxWidth;
                            final h = w * 1.45;
                            return SizedBox(
                              width: w, height: h,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Stack(
                                  children: [
                                    
                                    CustomPaint(size: Size(w, h), painter: _PitchPainterLocal()),
                                    
                                    for (final slot in _lineupSlots)
                                      _buildEditableSlot(slot, w, h, editLineup, setStateDialog),
                                  ],
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 16),
                          const Text('YEDEKLER', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1)),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              for (final slot in _subSlots)
                                _buildEditableSubSlot(slot, editLineup, setStateDialog),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () { setStateDialog(() => editLineup.clear()); },
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.white54, side: const BorderSide(color: Colors.white24)),
                          child: const Text('TEMİZLE'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('KADROYU KAYDET', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2ECC71),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () async {
                            setState(() => _lineup = Map<String, String>.from(editLineup));
                            Navigator.pop(ctx);
                            await _saveLineup();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEditableSlot(Map<String, Object> slot, double w, double h,
      Map<String, String> editLineup, void Function(void Function()) setStateDialog) {
    final key = slot['key'] as String;
    final label = slot['label'] as String;
    final x = (slot['x'] as double) * w;
    final y = (slot['y'] as double) * h;
    final playerId = editLineup[key];
    final player = playerId != null
        ? myPlayers.firstWhere((p) => p['id'].toString() == playerId, orElse: () => {})
        : null;
    final hasPlayer = player != null && player.isNotEmpty;
    final name = hasPlayer ? (player['name'] as String) : '';

    return Positioned(
      left: x - 36,
      top: y - 42,
      child: GestureDetector(
        onTap: () => _pickPlayerForSlot(key, label, editLineup, setStateDialog),
        onLongPress: hasPlayer ? () { setStateDialog(() => editLineup.remove(key)); } : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: hasPlayer ? const Color(0xFF0E8A5F) : Colors.white.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: hasPlayer ? Colors.white : Colors.white38,
                  width: hasPlayer ? 2.5 : 1.5,
                ),
                boxShadow: hasPlayer ? [BoxShadow(color: Colors.greenAccent.withOpacity(0.25), blurRadius: 8, spreadRadius: 1)] : [],
              ),
              child: Center(
                child: hasPlayer
                    ? Column(mainAxisSize: MainAxisSize.min, children: [
                        Text('${player['number'] ?? '?'}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, height: 1)),
                      ])
                    : const Icon(Icons.add, color: Colors.white54, size: 22),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                hasPlayer
                    ? (name.length > 10 ? '${name.substring(0, 9)}.' : name).toUpperCase()
                    : label,
                style: TextStyle(
                  color: hasPlayer ? Colors.white : Colors.white54,
                  fontWeight: hasPlayer ? FontWeight.bold : FontWeight.normal,
                  fontSize: 8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableSubSlot(Map<String, Object> slot, Map<String, String> editLineup, void Function(void Function()) setStateDialog) {
    final key = slot['key'] as String;
    final label = slot['label'] as String;
    final playerId = editLineup[key];
    final player = playerId != null
        ? myPlayers.firstWhere((p) => p['id'].toString() == playerId, orElse: () => {})
        : null;
    final hasPlayer = player != null && player.isNotEmpty;
    final name = hasPlayer ? (player['name'] as String) : '';

    return GestureDetector(
      onTap: () => _pickPlayerForSlot(key, label, editLineup, setStateDialog),
      onLongPress: hasPlayer ? () { setStateDialog(() => editLineup.remove(key)); } : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: hasPlayer ? const Color(0xFF0E8A5F) : Colors.white.withOpacity(0.08),
              shape: BoxShape.circle,
              border: Border.all(
                color: hasPlayer ? Colors.white : Colors.white24,
                width: hasPlayer ? 2 : 1.5,
              ),
            ),
            child: Center(
              child: hasPlayer
                  ? Text('${player['number'] ?? '?'}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, height: 1))
                  : const Icon(Icons.add, color: Colors.white38, size: 20),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              hasPlayer
                  ? (name.length > 7 ? '${name.substring(0, 6)}.' : name).toUpperCase()
                  : label,
              style: TextStyle(
                color: hasPlayer ? Colors.white : Colors.white54,
                fontWeight: hasPlayer ? FontWeight.bold : FontWeight.normal,
                fontSize: 8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _pickPlayerForSlot(String slotKey, String slotLabel,
      Map<String, String> editLineup, void Function(void Function()) setStateDialog) {
    
    final usedIds = editLineup.entries
        .where((e) => e.key != slotKey)
        .map((e) => e.value)
        .toSet();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131B2F),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                const Icon(Icons.place, color: Color(0xFF00FF7F), size: 18),
                const SizedBox(width: 8),
                Text('$slotLabel için oyuncu seç', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                const Spacer(),
                if (editLineup.containsKey(slotKey))
                  TextButton(
                    onPressed: () { setStateDialog(() => editLineup.remove(slotKey)); Navigator.pop(ctx); },
                    child: const Text('Kaldır', style: TextStyle(color: Colors.redAccent)),
                  ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: myPlayers.length,
              itemBuilder: (ctx, i) {
                final p = myPlayers[i];
                final pid = p['id'].toString();
                final isAlreadyUsed = usedIds.contains(pid);
                final isSelected = editLineup[slotKey] == pid;
                return ListTile(
                  enabled: !isAlreadyUsed,
                  leading: CircleAvatar(
                    backgroundColor: isSelected
                        ? const Color(0xFF00FF7F).withOpacity(0.2)
                        : Colors.white12,
                    child: Text('${p['number'] ?? '?'}',
                        style: TextStyle(
                            color: isSelected ? const Color(0xFF00FF7F) : Colors.white70,
                            fontWeight: FontWeight.bold)),
                  ),
                  title: Text(p['name'] as String, style: TextStyle(color: isAlreadyUsed ? Colors.white30 : Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text((p['profiles'] != null ? p['profiles']['preferred_position'] : null) ?? p['position'] ?? 'Mevki yok', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: Color(0xFF00FF7F))
                      : isAlreadyUsed
                          ? const Text('Kullanımda', style: TextStyle(color: Colors.white24, fontSize: 11))
                          : null,
                  onTap: () {
                    setStateDialog(() => editLineup[slotKey] = pid);
                    Navigator.pop(ctx);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingState() {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(20),
        elevation: 4,
        color: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TeamLogo(url: pendingRequest!['logo_url'], size: 120),
              const SizedBox(height: 30),
              const Icon(Icons.hourglass_top, size: 50, color: Colors.orange),
              const SizedBox(height: 20),
              Text("'${pendingRequest!['team_name']}'",
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                  textAlign: TextAlign.center),
              const SizedBox(height: 10),
              const Text("Başvurusu Alındı. Admin onayı bekleniyor...",
                  style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreateTeamState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const SizedBox(height: 20),
          const Text("TAKIMINI KUR",
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.white)),
          const SizedBox(height: 40),
          GestureDetector(
            onTap: _pickImage,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                    radius: 60,
                    backgroundColor: const Color(0xFF1E293B),
                    backgroundImage:
                        _logoFile != null ? FileImage(_logoFile!) : null,
                    child: _logoFile == null
                        ? const Icon(Icons.shield, size: 60, color: Colors.grey)
                        : null),
                Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                        color: Color(0xFF00FF7F), shape: BoxShape.circle),
                    child: const Icon(Icons.camera_alt,
                        color: Colors.black87, size: 20)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Text("Logo Yükle",
              style:
                  TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 40),
          TextField(
              controller: _teamNameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                  labelText: "Takım Adı",
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.group, color: Colors.grey))),
          const SizedBox(height: 15),
          TextField(
              controller: _teamShortNameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                  labelText: "Kısaltma (3 Harf)",
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.short_text, color: Colors.grey))),
          const SizedBox(height: 15),
          if (availableLeagues.isNotEmpty)
            DropdownButtonFormField<String>(
              value: selectedLeagueId,
              dropdownColor: const Color(0xFF1E293B),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Katılınacak Lig",
                labelStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
                prefixIcon: const Icon(Icons.emoji_events, color: Colors.amber),
              ),
              items: availableLeagues.map((l) {
                return DropdownMenuItem<String>(
                  value: l['id'],
                  child: Text(l['name'].toString().toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                );
              }).toList(),
              onChanged: (val) {
                setState(() => selectedLeagueId = val);
              },
            )
          else
            const Text(
                "Sistemde aktif bir lig bulunmuyor. Yöneticiye başvurun.",
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isUploading ? null : _submitRequest,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FF7F),
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              child: isUploading
                  ? const CircularProgressIndicator(color: Colors.black87)
                  : const Text("BAŞVURU GÖNDER",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  
  static const _positionOrder = [
    'KALECİLER',
    'DEFANSİFLER',
    'MİDFİLDLER',
    'FORVETLER',
    'KAPTAN',
    'DİĞER',
  ];

  static const _positionEmojis = {
    'KALECİLER': '🧤',
    'DEFANSİFLER': '🛡️',
    'MİDFİLDLER': '⚡',
    'FORVETLER': '🎯',
    'KAPTAN': '⭐',
    'DİĞER': '👤',
  };

  String _getPositionGroup(String? position) {
    final pos = (position ?? '').trim().toUpperCase();
    if (pos.isEmpty) return 'DİĞER';
    if (pos == 'KAPTAN') return 'KAPTAN';
    if (pos.contains('KALEC') || pos == 'GK' || pos == 'GOALKEEPER') {
      return 'KALECİLER';
    }
    if (pos.contains('DEF') ||
        pos.contains('BEK') ||
        pos.contains('STOPER') ||
        pos == 'DF' ||
        pos.contains('BACK') ||
        pos.contains('LİBERO')) {
      return 'DEFANSİFLER';
    }
    if (pos.contains('MDF') ||
        pos.contains('MID') ||
        pos.contains('ORTA') ||
        pos == 'MF' ||
        pos.contains('PIVOT') ||
        pos.contains('BEKO')) {
      return 'MİDFİLDLER';
    }
    if (pos.contains('FOR') ||
        pos.contains('SANTR') ||
        pos == 'FW' ||
        pos.contains('SAĞKANAT') ||
        pos.contains('SOLKANAT') ||
        pos.contains('KANAT') ||
        pos.contains('ATAK')) {
      return 'FORVETLER';
    }
    return 'DİĞER';
  }

  
  Widget _buildTeamViewState() {
    
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final group in _positionOrder) {
      grouped[group] = [];
    }
    for (final player in myPlayers) {
      final prefPos = player['profiles'] != null ? player['profiles']['preferred_position'] : null;
      final group = _getPositionGroup((prefPos ?? player['position']) as String?);
      grouped[group]!.add(player);
    }

    
    final activeGroups =
        _positionOrder.where((g) => grouped[g]!.isNotEmpty).toList();

    return CustomScrollView(
      slivers: [
        
        SliverToBoxAdapter(child: _buildTeamHeader()),
        
        if (_lineup.isNotEmpty) SliverToBoxAdapter(child: _buildLineupDisplay()),
        
        for (final group in activeGroups) ...[
          SliverToBoxAdapter(child: _buildGroupHeader(group)),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, idx) {
                final p = grouped[group]![idx];
                return _buildPlayerTile(p);
              },
              childCount: grouped[group]!.length,
            ),
          ),
        ],
        
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  Widget _buildTeamHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 30, 16, 24),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Column(
        children: [
          TeamLogo(url: myTeam!['logo_url'], size: 100),
          const SizedBox(height: 15),
          Text(
            myTeam!['name'].toString().toUpperCase(),
            style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1.2),
          ),
          Text(
            myTeam!['short_name'],
            style: const TextStyle(
                fontSize: 16,
                color: Colors.white70,
                fontWeight: FontWeight.bold),
          ),
          
          if (_isOwner) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _showDissolutionDialog,
              icon: const Icon(Icons.gavel, color: Colors.redAccent, size: 18),
              label: const Text(
                "TAKIMI FESİH ET",
                style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
              ),
              style: TextButton.styleFrom(
                backgroundColor: Colors.red.withOpacity(0.1),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: Colors.redAccent, width: 1)),
              ),
            ),
          ]
        ],
      ),
    );
  }

  
  Widget _buildLineupDisplay() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 4, height: 20, decoration: BoxDecoration(color: const Color(0xFF00FF7F), borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 10),
                const Text('İLK 11 KADROSU', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white, letterSpacing: 0.3)),
              ],
            ),
            const SizedBox(height: 16),
            AspectRatio(
              aspectRatio: 0.75,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CustomPaint(
                  painter: _PitchPainterLocal(),
                  child: LayoutBuilder(builder: (ctx, c) {
                    return Stack(
                      children: [
                        for (final slot in _lineupSlots)
                          _buildDisplaySlot(slot, c.maxWidth, c.maxHeight),
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
                  _buildDisplaySubSlot(slot),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisplaySlot(Map<String, Object> slot, double w, double h) {
    final key = slot['key'] as String;
    final x = (slot['x'] as double) * w;
    final y = (slot['y'] as double) * h;
    final playerId = _lineup[key];
    final player = playerId != null
        ? myPlayers.firstWhere((p) => p['id'].toString() == playerId, orElse: () => {})
        : null;
    final hasPlayer = player != null && player.isNotEmpty;
    final name = hasPlayer ? (player['name'] as String) : '';

    return Positioned(
      left: x - 32,
      top: y - 38,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: hasPlayer ? const Color(0xFF00FF7F) : Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: hasPlayer ? Colors.white : Colors.white38, width: hasPlayer ? 2 : 1),
              boxShadow: hasPlayer ? [BoxShadow(color: const Color(0xFF00FF7F).withOpacity(0.5), blurRadius: 6)] : [],
            ),
            child: Center(
              child: hasPlayer
                  ? Text('${player['number'] ?? '?'}', style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 13))
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

  Widget _buildDisplaySubSlot(Map<String, Object> slot) {
    final key = slot['key'] as String;
    final playerId = _lineup[key];
    final player = playerId != null
        ? myPlayers.firstWhere((p) => p['id'].toString() == playerId, orElse: () => {})
        : null;
    final hasPlayer = player != null && player.isNotEmpty;
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

  Widget _buildGroupHeader(String group) {
    final emoji = _positionEmojis[group] ?? '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              "$emoji  $group",
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerTile(Map<String, dynamic> player) {
    final stats = player['stats'] as Map<String, dynamic>;
    return Card(
      elevation: 2,
      color: const Color(0xFF1E293B),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: () => PlayerProfileDialog.show(context, player['id']),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF00FF7F).withOpacity(0.15),
          child: Text(
            "${player['number'] ?? '?'}",
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Color(0xFF00FF7F)),
          ),
        ),
        title: Row(children: [
          Text(player['name'],
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.grey)),
          if (stats['isSuspended']) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(4)),
              child: const Text("CEZALI",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            )
          ]
        ]),
        subtitle: Text((player['profiles'] != null ? player['profiles']['preferred_position'] : null) ?? player['position'] ?? 'Mevki Belirtilmedi',
            style: TextStyle(color: Colors.grey.shade400)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatBadge("⚽", stats['goals'], Colors.greenAccent),
            const SizedBox(width: 4),
            _buildStatBadge("👟", stats['assists'], Colors.lightBlueAccent),
            const SizedBox(width: 4),
            _buildStatBadge("", stats['yellows'], Colors.yellow,
                isCard: true),
            const SizedBox(width: 4),
            _buildStatBadge("", stats['reds'], Colors.redAccent, isCard: true),
            
            if (_isOwner) ...[
              const SizedBox(width: 4),
              IconButton(
                tooltip: "Forma No Düzenle",
                icon: const Icon(Icons.edit_outlined,
                    color: Color(0xFF00FF7F), size: 20),
                onPressed: () => _editPlayerNumber(player),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
              ),
            ],
            const SizedBox(width: 2),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(4),
              onPressed: () async {
                await supabase.from('players').delete().eq('id', player['id']);
                _getMyPlayersWithStats(myTeam!['id']);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBadge(String icon, int count, Color color,
      {bool isCard = false}) {
    if (count == 0) return const SizedBox.shrink();
    if (isCard) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withOpacity(0.5))),
        child: Row(children: [
          Container(width: 7, height: 11, color: color),
          const SizedBox(width: 3),
          Text("$count",
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 11))
        ]),
      );
    }
    return Text("$icon $count",
        style:
            const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white));
  }
}


class _PitchPainterLocal extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final grassPaint = Paint()..color = const Color(0xFF1A7A3F);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), const Radius.circular(14)), grassPaint);

    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(w * 0.04, h * 0.02, w * 0.96, h * 0.98), const Radius.circular(4)), linePaint);
    canvas.drawLine(Offset(w * 0.04, h * 0.5), Offset(w * 0.96, h * 0.5), linePaint);
    canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.15, linePaint);
    canvas.drawCircle(Offset(w * 0.5, h * 0.5), 3, Paint()..color = Colors.white.withOpacity(0.5));

    final penW = w * 0.6;
    final penH = h * 0.18;
    final smallPenW = w * 0.3;
    final smallPenH = h * 0.08;

    canvas.drawRect(Rect.fromLTWH((w - penW) / 2, h * 0.02, penW, penH), linePaint);
    canvas.drawRect(Rect.fromLTWH((w - smallPenW) / 2, h * 0.02, smallPenW, smallPenH), linePaint);
    canvas.drawRect(Rect.fromLTWH((w - penW) / 2, h * 0.98 - penH, penW, penH), linePaint);
    canvas.drawRect(Rect.fromLTWH((w - smallPenW) / 2, h * 0.98 - smallPenH, smallPenW, smallPenH), linePaint);

    final stripePaint = Paint()..color = Colors.white.withOpacity(0.04);
    final stripeWidth = w / 8;
    for (int i = 0; i < 8; i++) {
      if (i.isOdd) canvas.drawRect(Rect.fromLTWH(i * stripeWidth, 0, stripeWidth, h), stripePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
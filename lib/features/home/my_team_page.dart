import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:devler_ligi/main.dart';
import 'package:devler_ligi/widgets/team_logo.dart';
import 'package:devler_ligi/widgets/custom_nav_bar.dart'; 

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

  final _teamNameController = TextEditingController();
  final _teamShortNameController = TextEditingController();
  File? _logoFile;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    setState(() => isLoading = true);
    final userId = supabase.auth.currentUser!.id;
    try {
      final teamData = await supabase.from('teams').select().eq('owner_id', userId).maybeSingle();
      if (teamData != null) {
        myTeam = teamData;
        await _getMyPlayersWithStats(teamData['id']); 
      } else {
        final requestData = await supabase.from('team_requests').select().eq('user_id', userId).eq('status', 'pending').maybeSingle();
        pendingRequest = requestData;
      }
    } catch (e) { debugPrint("Hata: $e"); } 
    finally { if(mounted) setState(() => isLoading = false); }
  }

  // --- İSTATİSTİKLERİ ÇEKME (ASİST EKLENDİ) ---
  Future<void> _getMyPlayersWithStats(String teamId) async {
    // 1. Oyuncuları çek
    final playersData = await supabase.from('players').select().eq('team_id', teamId).order('number', ascending: true);
    List<Map<String, dynamic>> players = List<Map<String, dynamic>>.from(playersData);

    // 2. İstatistikleri Çek (Gol + Asist)
    // Not: match_goals tablosundan hem gol atanı (player_id) hem asist yapanı (assist_player_id) çekiyoruz.
    final goalsData = await supabase.from('match_goals').select('player_id, assist_player_id').eq('team_id', teamId);
    
    // Kartları çek
    final cardsData = await supabase.from('match_cards').select('player_id, card_type').eq('team_id', teamId);

    // 3. Eşleştir
    for (var player in players) {
      final pid = player['id'];
      
      // İstatistik Hesaplama
      final goalCount = goalsData.where((g) => g['player_id'] == pid).length;
      final assistCount = goalsData.where((g) => g['assist_player_id'] == pid).length; // ASİST HESABI
      final yellowCount = cardsData.where((c) => c['player_id'] == pid && c['card_type'] == 'yellow').length;
      final redCount = cardsData.where((c) => c['player_id'] == pid && c['card_type'] == 'red').length;

      player['stats'] = {
        'goals': goalCount,
        'assists': assistCount, // Listeye eklendi
        'yellows': yellowCount,
        'reds': redCount,
        'isSuspended': redCount > 0 || (yellowCount > 0 && yellowCount % 3 == 0)
      };
    }
    setState(() => myPlayers = players);
  }

  // --- RESİM VE FORM İŞLEMLERİ ---
  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) setState(() => _logoFile = File(image.path));
  }

  Future<void> _submitRequest() async {
    if (_teamNameController.text.isEmpty) return;
    setState(() => isUploading = true);
    String? uploadedLogoUrl;
    try {
      if (_logoFile != null) {
        final fileExt = _logoFile!.path.split('.').last;
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        final filePath = 'requests/$fileName';
        await supabase.storage.from('team_logos').upload(filePath, _logoFile!);
        uploadedLogoUrl = supabase.storage.from('team_logos').getPublicUrl(filePath);
      }
      await supabase.from('team_requests').insert({
        'user_id': supabase.auth.currentUser!.id,
        'team_name': _teamNameController.text.trim(),
        'short_name': _teamShortNameController.text.trim().toUpperCase(),
        'logo_url': uploadedLogoUrl, 'status': 'pending'
      });
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Başvuru gönderildi!")));
      _checkStatus();
    } catch (e) { if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e"))); } 
    finally { if(mounted) setState(() => isUploading = false); }
  }

  Future<void> _addPlayerDialog() async {
    final nameCtrl = TextEditingController();
    final posCtrl = TextEditingController();
    final numCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Yeni Oyuncu Ekle"),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Ad Soyad")),
            TextField(controller: posCtrl, decoration: const InputDecoration(labelText: "Mevki")),
            TextField(controller: numCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Forma No")),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal")),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty) return;
              
              final name = nameCtrl.text.trim();
              final number = int.tryParse(numCtrl.text) ?? 0;
              final exists = myPlayers.any((p) => p['name'].toString().toLowerCase() == name.toLowerCase() || (number != 0 && p['number'] == number));

              if (exists) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bu oyuncu zaten var!"), backgroundColor: Colors.orange));
                return;
              }

              try {
                await supabase.from('players').insert({
                  'team_id': myTeam!['id'], 'name': name, 'position': posCtrl.text, 'number': number,
                });
                if(mounted) Navigator.pop(context);
                _getMyPlayersWithStats(myTeam!['id']);
              } catch (e) { debugPrint("Ekleme hatası: $e"); }
            },
            child: const Text("EKLE"),
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
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          const CustomNavBar(showBackButton: true),
          Expanded(child: content),
        ],
      ),
      floatingActionButton: (myTeam != null && !isLoading) 
          ? FloatingActionButton(
              onPressed: _addPlayerDialog,
              backgroundColor: const Color(0xFF1E88E5),
              child: const Icon(Icons.add, color: Colors.white),
            ) 
          : null,
    );
  }

  Widget _buildPendingState() {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(20),
        elevation: 4,
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
              Text("'${pendingRequest!['team_name']}'", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF06283D)), textAlign: TextAlign.center),
              const SizedBox(height: 10),
              const Text("Başvurusu Alındı. Admin onayı bekleniyor...", style: TextStyle(color: Colors.grey)),
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
          const Text("TAKIMINI KUR", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF06283D))),
          const SizedBox(height: 40),
          GestureDetector(
            onTap: _pickImage,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(radius: 60, backgroundColor: Colors.white, backgroundImage: _logoFile != null ? FileImage(_logoFile!) : null, child: _logoFile == null ? const Icon(Icons.shield, size: 60, color: Colors.grey) : null),
                Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: Color(0xFF1E88E5), shape: BoxShape.circle), child: const Icon(Icons.camera_alt, color: Colors.white, size: 20)),
              ],
            ),
          ),
          const SizedBox(height: 10), const Text("Logo Yükle", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)), const SizedBox(height: 40),
          TextField(controller: _teamNameController, decoration: InputDecoration(labelText: "Takım Adı", filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none), prefixIcon: const Icon(Icons.group))),
          const SizedBox(height: 15),
          TextField(controller: _teamShortNameController, decoration: InputDecoration(labelText: "Kısaltma (3 Harf)", filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none), prefixIcon: const Icon(Icons.short_text))),
          const SizedBox(height: 30),
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: isUploading ? null : _submitRequest, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF06283D), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: isUploading ? const CircularProgressIndicator(color: Colors.white) : const Text("BAŞVURU GÖNDER", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))))
        ],
      ),
    );
  }

  // --- ONAYLI TAKIM LİSTESİ (ASİST GÖSTERİMİ EKLENDİ) ---
  Widget _buildTeamViewState() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 30),
          decoration: const BoxDecoration(color: Color(0xFF06283D), borderRadius: BorderRadius.vertical(bottom: Radius.circular(30))),
          child: Column(
            children: [
              TeamLogo(url: myTeam!['logo_url'], size: 100),
              const SizedBox(height: 15),
              Text(myTeam!['name'].toString().toUpperCase(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.2)),
              Text(myTeam!['short_name'], style: const TextStyle(fontSize: 16, color: Colors.white70, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: myPlayers.isEmpty 
            ? const Center(child: Text("Henüz oyuncu eklenmedi.", style: TextStyle(fontSize: 16, color: Colors.grey)))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                itemCount: myPlayers.length,
                itemBuilder: (context, index) {
                  final p = myPlayers[index];
                  final stats = p['stats'];
                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(backgroundColor: const Color(0xFF1E88E5).withValues(alpha: 0.1), child: Text("${p['number']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E88E5)))),
                      title: Row(children: [Text(p['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), if (stats['isSuspended']) ...[const SizedBox(width: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)), child: const Text("CEZALI", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))]]),
                      subtitle: Text(p['position'] ?? 'Mevki Belirtilmedi', style: TextStyle(color: Colors.grey.shade600)),
                      
                      // --- İSTATİSTİK ROZETLERİ (ASİST EKLENDİ) ---
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildStatBadge("⚽", stats['goals'], Colors.green),
                          const SizedBox(width: 5),
                          _buildStatBadge("👟", stats['assists'], Colors.blue), // ASİST ROZETİ (MAVİ AYAKKABI)
                          const SizedBox(width: 5),
                          _buildStatBadge("", stats['yellows'], Colors.yellow, isCard: true),
                          const SizedBox(width: 5),
                          _buildStatBadge("", stats['reds'], Colors.red, isCard: true),
                          const SizedBox(width: 10),
                          IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () async { await supabase.from('players').delete().eq('id', p['id']); _getMyPlayersWithStats(myTeam!['id']); }),
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

  Widget _buildStatBadge(String icon, int count, Color color, {bool isCard = false}) {
    if (count == 0) return const SizedBox.shrink();
    if (isCard) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4), border: Border.all(color: color)),
        child: Row(children: [Container(width: 8, height: 12, color: color), const SizedBox(width: 4), Text("$count", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 12))]),
      );
    }
    return Text("$icon $count", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14));
  }
}
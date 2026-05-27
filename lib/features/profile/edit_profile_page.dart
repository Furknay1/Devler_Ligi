import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:devler_ligi/main.dart';
import 'package:devler_ligi/widgets/custom_nav_bar.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isFutSaving = false;

  
  Map<String, dynamic>? _myTeamInfo;
  Map<String, dynamic>? _myPlayerRecord;
  List<Map<String, dynamic>> _myTeammates = [];
  List<Map<String, dynamic>> _myPendingOffers = [];

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();

  String _dominantFoot = 'Sağ Ayak';
  String _preferredPosition = 'Forvet';

  final List<String> _footOptions = ['Sağ Ayak', 'Sol Ayak', 'İki Ayak'];
  final List<String> _positionOptions = ['Forvet', 'Kanat', 'Orta Saha', 'Defans', 'Bek', 'Kaleci'];

  
  String? _futPhotoUrl;
  File? _futPhotoFile;
  final ImagePicker _imagePicker = ImagePicker();
  int _futPac = 75;
  int _futSho = 75;
  int _futPas = 75;
  int _futDri = 75;
  int _futDef = 75;
  int _futPhy = 75;

  
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
    _loadTeamInfo();
  }

  Future<void> _loadProfileData() async {
    final user = supabase.auth.currentUser;
    if (user != null) {
      try {
        final res = await supabase.from('profiles').select().eq('id', user.id).maybeSingle();
        if (res != null) {
          _usernameController.text = (res['username'] as String?) ?? (res['full_name'] as String?) ?? '';
          _heightController.text = res['height']?.toString() ?? '';
          _weightController.text = res['weight']?.toString() ?? '';
          _ageController.text = res['age']?.toString() ?? '';
          
          if (res['dominant_foot'] != null && _footOptions.contains(res['dominant_foot'])) {
            _dominantFoot = res['dominant_foot'];
          }
          if (res['preferred_position'] != null && _positionOptions.contains(res['preferred_position'])) {
            _preferredPosition = res['preferred_position'];
          }

          
          _futPhotoUrl = res['fut_photo_url'] as String?;
          _futPac = (res['fut_pac'] as int?) ?? 75;
          _futSho = (res['fut_sho'] as int?) ?? 75;
          _futPas = (res['fut_pas'] as int?) ?? 75;
          _futDri = (res['fut_dri'] as int?) ?? 75;
          _futDef = (res['fut_def'] as int?) ?? 75;
          _futPhy = (res['fut_phy'] as int?) ?? 75;
        }
      } catch (e) {
        debugPrint("Profil yüklenemedi: $e");
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _pickFutPhoto() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (image != null) {
      setState(() => _futPhotoFile = File(image.path));
    }
  }

  Future<void> _saveFutCard() async {
    setState(() => _isFutSaving = true);
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      String? photoUrl = _futPhotoUrl;

      
      if (_futPhotoFile != null) {
        final ext = _futPhotoFile!.path.split('.').last.toLowerCase();
        final fileName = 'fut_${user.id}_${DateTime.now().millisecondsSinceEpoch}.$ext';
        await supabase.storage.from('player_photos').upload(
          fileName,
          _futPhotoFile!,
          fileOptions: const FileOptions(upsert: true),
        );
        photoUrl = supabase.storage.from('player_photos').getPublicUrl(fileName);
      }

      await supabase.from('profiles').update({
        'fut_photo_url': photoUrl,
        'fut_pac': _futPac,
        'fut_sho': _futSho,
        'fut_pas': _futPas,
        'fut_dri': _futDri,
        'fut_def': _futDef,
        'fut_phy': _futPhy,
      }).eq('id', user.id);

      setState(() => _futPhotoUrl = photoUrl);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ FUT Kartınız güncellendi!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isFutSaving = false);
    }
  }

  
  Future<void> _loadTeamInfo() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      
      final playerRecord = await supabase
          .from('players')
          .select('id, name, position, number, team_id, teams(id, name, logo_url, short_name, owner_id)')
          .eq('profile_id', userId)
          .maybeSingle();

      if (playerRecord != null && playerRecord['team_id'] != null) {
        final teamId = playerRecord['team_id'].toString();
        final teamMap = playerRecord['teams'] as Map<String, dynamic>?;
        _myPlayerRecord = playerRecord;
        _myTeamInfo = teamMap;

        
        final teammatesData = await supabase
            .from('players')
            .select('id, name, position, number, profile_id, profiles(preferred_position)')
            .eq('team_id', teamId)
            .neq('profile_id', userId)
            .order('number', ascending: true);
        _myTeammates = List<Map<String, dynamic>>.from(teammatesData);
      }

      
      final offersData = await supabase
          .from('transfer_requests')
          .select('*, teams(name, logo_url)')
          .eq('profile_id', userId)
          .eq('status', 'pending');
      _myPendingOffers = List<Map<String, dynamic>>.from(offersData);

    } catch (e) {
      debugPrint('Team info load error: $e');
    }
    if (mounted) setState(() {});
  }

  Future<void> _respondToOffer(String offerId, String teamId, {required bool accepted}) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      if (accepted) {
        final existing = await supabase.from('players').select('id').eq('profile_id', userId).maybeSingle();
        if (existing != null) {
          await supabase.from('players').update({'team_id': teamId}).eq('id', existing['id']);
        } else {
          final profile = await supabase.from('profiles').select('username, full_name, preferred_position').eq('id', userId).maybeSingle();
          final name = (profile?['username'] as String?) ?? (profile?['full_name'] as String?) ?? 'Oyuncu';
          final pos = (profile?['preferred_position'] as String?) ?? 'Orta Saha';
          await supabase.from('players').insert({'profile_id': userId, 'team_id': teamId, 'name': name, 'position': pos, 'number': 0});
        }
      }
      await supabase.from('transfer_requests').update({'status': accepted ? 'accepted' : 'rejected'}).eq('id', offerId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(accepted ? '✅ Transfer kabul edildi! Artık yeni takımındasın.' : '❌ Teklif reddedildi.'),
          backgroundColor: accepted ? Colors.green : Colors.orange,
        ));
        await _loadTeamInfo();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    final user = supabase.auth.currentUser;
    if (user != null) {
      try {
         final updateResponse = await supabase.from('profiles').update({
            'username': _usernameController.text.trim(),
            'full_name': _usernameController.text.trim(),
            'height': _heightController.text.trim(),
            'weight': _weightController.text.trim(),
            'age': _ageController.text.trim(),
            'dominant_foot': _dominantFoot,
            'preferred_position': _preferredPosition,
         }).eq('id', user.id).select();
         
         if (updateResponse.isEmpty) {
             throw "Veritabanı güncelleme izniniz yok (Supabase RLS engeli). Lütfen fix_profiles_rls.sql komutunu çalıştırın.";
         }
         
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Profiliniz güncellendi!", style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.green));
           context.pop();
         }
      } catch (e) {
         if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red));
      } finally {
         if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
       return const Scaffold(backgroundColor: Color(0xFF0B101E), body: Center(child: CircularProgressIndicator(color: Color(0xFF00FF7F))));
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1A),
      body: Column(
        children: [
          const CustomNavBar(showBackButton: true),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: _buildTabButton(
                    label: 'PROFİL DÜZENLE',
                    icon: Icons.person_outline,
                    isSelected: _selectedTab == 0,
                    onTap: () => setState(() => _selectedTab = 0),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTabButton(
                    label: 'FUT KART',
                    icon: Icons.sports_soccer,
                    isSelected: _selectedTab == 1,
                    onTap: () => setState(() => _selectedTab = 1),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _selectedTab == 0 ? _buildProfileTab() : _buildFutCardTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({required String label, required IconData icon, required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00FF7F) : const Color(0xFF131B2F),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF00FF7F) : Colors.white12,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? Colors.black : Colors.white54, size: 18),
            const SizedBox(width: 8),
            Text(label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white54,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF131B2F),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF00FF7F).withOpacity(0.3), width: 1.5),
            boxShadow: [
              BoxShadow(color: const Color(0xFF00FF7F).withOpacity(0.1), blurRadius: 25, spreadRadius: 5)
            ]
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                 child: Text("PROFİLİ DÜZENLE", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF00FF7F), letterSpacing: 2, shadows: [Shadow(color: Color(0xFF00FF7F), blurRadius: 10)])),
              ),
              const SizedBox(height: 30),
                      
                      _buildTextField("Kullanıcı Adı / Forma Adı", _usernameController, Icons.person),
                      const SizedBox(height: 20),
                      
                      Row(
                        children: [
                          Expanded(child: _buildTextField("Boy (cm)", _heightController, Icons.height, isNumber: true)),
                          const SizedBox(width: 20),
                          Expanded(child: _buildTextField("Kilo (kg)", _weightController, Icons.monitor_weight, isNumber: true)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      _buildTextField("Yaş", _ageController, Icons.calendar_today, isNumber: true),
                      const SizedBox(height: 20),
                      
                      const Text("Baskın Ayak", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(color: const Color(0xFF0B101E), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white12)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _dominantFoot,
                            dropdownColor: const Color(0xFF131B2F),
                            isExpanded: true,
                            icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF00FF7F)),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            items: _footOptions.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                            onChanged: (val) { if (val != null) setState(() => _dominantFoot = val); },
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      const Text("En İyi Oynadığın Mevki", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(color: const Color(0xFF0B101E), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white12)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _preferredPosition,
                            dropdownColor: const Color(0xFF131B2F),
                            isExpanded: true,
                            icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF00FF7F)),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            items: _positionOptions.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                            onChanged: (val) { if (val != null) setState(() => _preferredPosition = val); },
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 40),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                           onPressed: _isSaving ? null : _saveProfile,
                           style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00FF7F),
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 10,
                              shadowColor: const Color(0xFF00FF7F).withOpacity(0.5)
                           ),
                           child: _isSaving 
                              ? const CircularProgressIndicator(color: Colors.black)
                              : const Text("GÜNCELLE", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2)),
                        ),
                      ),

                      
                      if (_myPendingOffers.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.notifications_active, color: Colors.white, size: 18),
                                  const SizedBox(width: 8),
                                  Text('Transfer Tekliflerin (${_myPendingOffers.length})',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ..._myPendingOffers.map((offer) {
                                final team = offer['teams'] as Map<String, dynamic>? ?? {};
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.shield, color: Colors.white70, size: 16),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              team['name']?.toString().toUpperCase() ?? 'Bilinmeyen Takım',
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      const Text('seni transfer etmek istiyor.',
                                          style: TextStyle(color: Colors.white60, fontSize: 12)),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF2ECC71),
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(vertical: 8),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                              onPressed: () => _respondToOffer(offer['id'], offer['team_id'], accepted: true),
                                              child: const Text('KABUL ET', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: OutlinedButton(
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: Colors.white,
                                                side: const BorderSide(color: Colors.white54),
                                                padding: const EdgeInsets.symmetric(vertical: 8),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                              onPressed: () => _respondToOffer(offer['id'], offer['team_id'], accepted: false),
                                              child: const Text('REDDET', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ],

                      
                      if (_myTeamInfo != null) ...[
                        const SizedBox(height: 28),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0B101E),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF00FF7F).withOpacity(0.25), width: 1.5),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.shield_outlined, color: Color(0xFF00FF7F), size: 20),
                                  const SizedBox(width: 8),
                                  const Text('TAKIMIM',
                                      style: TextStyle(color: Color(0xFF00FF7F), fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1)),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1A3A2A),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: const Color(0xFF00FF7F).withOpacity(0.4)),
                                    ),
                                    child: Text(
                                      _myTeamInfo!['short_name']?.toString() ?? '',
                                      style: const TextStyle(color: Color(0xFF00FF7F), fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Container(
                                    width: 60, height: 60,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFF1E293B),
                                      border: Border.all(color: const Color(0xFF00FF7F).withOpacity(0.3)),
                                      image: _myTeamInfo!['logo_url'] != null
                                          ? DecorationImage(
                                              image: NetworkImage(_myTeamInfo!['logo_url'] as String),
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                    ),
                                    child: _myTeamInfo!['logo_url'] == null
                                        ? const Icon(Icons.shield, color: Colors.white54, size: 30)
                                        : null,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _myTeamInfo!['name']?.toString().toUpperCase() ?? '',
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            _buildInfoChip(Icons.sports_soccer, '#${_myPlayerRecord?['number'] ?? '?'}'),
                                            const SizedBox(width: 8),
                                            _buildInfoChip(Icons.place, _myPlayerRecord?['position'] ?? 'Belirtilmedi'),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (_myTeammates.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                const Divider(color: Colors.white12),
                                const SizedBox(height: 8),
                                const Text('TAKIM ARKADAŞLARI',
                                    style: TextStyle(color: Colors.white38, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1)),
                                const SizedBox(height: 8),
                                ..._myTeammates.map((tm) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 32, height: 32,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1E293B),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white12),
                                        ),
                                        child: Center(
                                          child: Text('${tm['number'] ?? '?'}',
                                              style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12)),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(tm['name'] ?? 'Oyuncu',
                                            style: const TextStyle(color: Colors.white, fontSize: 13)),
                                      ),
                                      Text(
                                        (tm['profiles']?['preferred_position'] as String?)
                                            ?? tm['position']
                                            ?? '',
                                        style: const TextStyle(color: Colors.white38, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                )),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }

  
  
  
  Widget _buildFutCardTab() {
    final int ovr = ((_futPac + _futSho + _futPas + _futDri + _futDef + _futPhy) / 6).round();
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          
          _buildFutPreviewCard(ovr),
          const SizedBox(height: 28),

          
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF131B2F),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.photo_camera, color: Color(0xFFFFD700), size: 20),
                    SizedBox(width: 8),
                    Text('OYUNCU FOTOĞRAFI',
                        style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)),
                  ],
                ),
                const SizedBox(height: 4),
                const Text('Kartınızda görünecek fotoğrafı seçin',
                    style: TextStyle(color: Colors.white38, fontSize: 12)),
                const SizedBox(height: 16),
                Center(
                  child: GestureDetector(
                    onTap: _pickFutPhoto,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF0B101E),
                            border: Border.all(
                              color: _futPhotoFile != null || _futPhotoUrl != null
                                  ? const Color(0xFFFFD700)
                                  : Colors.white24,
                              width: 2.5,
                            ),
                            image: _futPhotoFile != null
                                ? DecorationImage(image: FileImage(_futPhotoFile!), fit: BoxFit.cover)
                                : (_futPhotoUrl != null && _futPhotoUrl!.isNotEmpty)
                                    ? DecorationImage(image: NetworkImage(_futPhotoUrl!), fit: BoxFit.cover)
                                    : null,
                            boxShadow: [
                              BoxShadow(color: const Color(0xFFFFD700).withOpacity(0.2), blurRadius: 15, spreadRadius: 2)
                            ],
                          ),
                          child: (_futPhotoFile == null && (_futPhotoUrl == null || _futPhotoUrl!.isEmpty))
                              ? const Icon(Icons.person, color: Colors.white38, size: 60)
                              : null,
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFD700),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt, color: Colors.black, size: 18),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Center(
                  child: Text('Fotoğrafa tıkla ve seç',
                      style: TextStyle(color: Colors.white38, fontSize: 12)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF131B2F),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.bar_chart, color: Color(0xFFFFD700), size: 20),
                    SizedBox(width: 8),
                    Text('STAT DEĞELLERİ',
                        style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)),
                  ],
                ),
                const SizedBox(height: 4),
                const Text('Her stat için 1-99 arasında bir değer belirleyebilirsin',
                    style: TextStyle(color: Colors.white38, fontSize: 12)),
                const SizedBox(height: 20),
                _buildStatSlider('HIZ (PAC)', _futPac, Colors.greenAccent, (v) => setState(() => _futPac = v)),
                _buildStatSlider('ŞUT (SHO)', _futSho, Colors.redAccent, (v) => setState(() => _futSho = v)),
                _buildStatSlider('PAS (PAS)', _futPas, Colors.blueAccent, (v) => setState(() => _futPas = v)),
                _buildStatSlider('DRIBİLLİNG (DRI)', _futDri, Colors.orangeAccent, (v) => setState(() => _futDri = v)),
                _buildStatSlider('DEFANS (DEF)', _futDef, Colors.purpleAccent, (v) => setState(() => _futDef = v)),
                _buildStatSlider('FİZİKSEL (PHY)', _futPhy, Colors.cyanAccent, (v) => setState(() => _futPhy = v)),
              ],
            ),
          ),

          const SizedBox(height: 24),

          
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton.icon(
              onPressed: _isFutSaving ? null : _saveFutCard,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD700),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 10,
                shadowColor: const Color(0xFFFFD700).withOpacity(0.5),
              ),
              icon: _isFutSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                  : const Icon(Icons.save_outlined),
              label: Text(
                _isFutSaving ? 'KAYDEDILIYOR...' : 'FUT KARTI KAYDET',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildStatSlider(String label, int value, Color color, ValueChanged<int> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                alignment: Alignment.center,
                child: Text(
                  value.toString(),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(label, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 4),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: color,
              inactiveTrackColor: color.withOpacity(0.15),
              thumbColor: color,
              overlayColor: color.withOpacity(0.2),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: value.toDouble(),
              min: 1,
              max: 99,
              divisions: 98,
              onChanged: (v) => onChanged(v.round()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFutPreviewCard(int ovr) {
    final position = _preferredPosition.toUpperCase().substring(0, _preferredPosition.length.clamp(0, 3));
    final String teamLogo = _myTeamInfo?['logo_url'] as String? ?? "";
    final String name = _usernameController.text.isNotEmpty ? _usernameController.text : 'OYUNCU';
    final String number = _myPlayerRecord?['number']?.toString() ?? "99";

    return Center(
      child: Container(
        width: 300,
        height: 490,
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD700).withOpacity(0.4),
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
                clipper: EditFutCardClipper(),
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
                  clipper: EditFutCardClipper(),
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
                              child: _futPhotoFile != null
                                  ? Image.file(
                                      _futPhotoFile!,
                                      height: 200,
                                      width: 200,
                                      fit: BoxFit.cover,
                                      alignment: Alignment.topCenter,
                                    )
                                  : (_futPhotoUrl != null && _futPhotoUrl!.isNotEmpty)
                                      ? Image.network(
                                          _futPhotoUrl!,
                                          height: 200,
                                          width: 200,
                                          fit: BoxFit.cover,
                                          alignment: Alignment.topCenter,
                                          errorBuilder: (context, error, stackTrace) =>
                                              const Icon(Icons.person, size: 200, color: Colors.white24),
                                        )
                                      : const Icon(Icons.person, size: 200, color: Colors.white24),
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
                                    _buildStatColumn(_futPac.toString(), _futSho.toString(), _futPas.toString()),
                                    Container(width: 1, height: 70, color: const Color(0xFFFFDF00).withOpacity(0.5)),
                                    _buildStatColumn(_futDri.toString(), _futDef.toString(), _futPhy.toString()),
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
        ),
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

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {bool isNumber = false}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: const Color(0xFF00FF7F)),
        filled: true,
        fillColor: const Color(0xFF0B101E),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white12)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF00FF7F), width: 2)),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1A3A2A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF00FF7F).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF00FF7F), size: 13),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}


class EditFutCardClipper extends CustomClipper<Path> {
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

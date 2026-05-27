import 'package:flutter/material.dart';
import 'package:devler_ligi/main.dart'; 

class PlayerProfileDialog {
  static void show(BuildContext context, String playerId) {
    showDialog(
      context: context,
      builder: (context) => _PlayerProfileDialogWidget(playerId: playerId),
    );
  }
}

class _PlayerProfileDialogWidget extends StatefulWidget {
  final String playerId;
  const _PlayerProfileDialogWidget({required this.playerId});

  @override
  State<_PlayerProfileDialogWidget> createState() => _PlayerProfileDialogWidgetState();
}

class _PlayerProfileDialogWidgetState extends State<_PlayerProfileDialogWidget> {
  Map<String, dynamic>? playerStats;
  List<Map<String, dynamic>> recentForms = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final playRes = await supabase.from('players').select('*, teams(name), profiles(username, short_id)').eq('id', widget.playerId).maybeSingle();
      if (playRes != null) {
        final formsRes = await supabase
            .from('match_player_stats')
            .select('rating')
            .eq('player_id', widget.playerId)
            .order('created_at', ascending: false)
            .limit(5);
            
        if (mounted) {
          setState(() {
            playerStats = playRes;
            recentForms = List<Map<String, dynamic>>.from(formsRes);
            isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (playerStats == null) return const AlertDialog(content: Text("Bu oyuncu bilgisine ulaşılamadı. Muhtemelen Sanal (Bot) Liste Oyuncusu."));

    final String name = playerStats?['profiles']?['username'] ?? playerStats?['name'] ?? "Bilinmiyor";
    final String shortId = playerStats?['profiles']?['short_id'] ?? "#MNC";
    final String position = playerStats?['position'] ?? "OS";
    final String number = playerStats?['number']?.toString() ?? "99";
    final String teamName = playerStats?['teams']?['name'] ?? "Bilinmeyen Takım";
    final int ovr = 85 + (name.length % 10);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF06283D).withOpacity(0.95),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.amberAccent.withOpacity(0.5), width: 2),
          boxShadow: [
            BoxShadow(color: Colors.amberAccent.withOpacity(0.2), blurRadius: 20, spreadRadius: 5)
          ]
        ),
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                    child: Text(shortId, style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => Navigator.pop(context)),
               ]
            ),
            const SizedBox(height: 10),
            
            
            _buildMiniFutCard(name, position, number, ovr),
            
            const SizedBox(height: 20),
            Text(teamName.toUpperCase(), style: const TextStyle(color: Colors.white70, letterSpacing: 1.5, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            
            
            const Text("SON OYNADIĞI MAÇLAR", style: TextStyle(color: Colors.white38, fontSize: 12, letterSpacing: 1)),
            const SizedBox(height: 10),
            _buildFormTracker(),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniFutCard(String name, String position, String number, int ovr) {
    return Container(
      width: 150,
      height: 220,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.amber.shade300, Colors.amber.shade700], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.amber.shade700.withOpacity(0.4), blurRadius: 15, spreadRadius: 2)],
      ),
      child: Stack(
        children: [
          Positioned(top: 15, left: 15, child: Column(children: [Text("$ovr", style: const TextStyle(color: Colors.black87, fontSize: 28, fontWeight: FontWeight.w900)), Text(position, style: const TextStyle(color: Colors.black54, fontSize: 16, fontWeight: FontWeight.bold))])),
          Positioned(top: 80, left: 0, right: 0, child: Icon(Icons.person, size: 85, color: Colors.black.withOpacity(0.4))),
          Positioned(bottom: 25, left: 0, right: 0, child: Column(children: [Text(name.toUpperCase(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 15, overflow: TextOverflow.ellipsis)), const SizedBox(height: 5), const Divider(color: Colors.black26, indent: 20, endIndent: 20)])),
        ]
      )
    );
  }

  Widget _buildFormTracker() {
    if (recentForms.isEmpty) return const Text("Form verisi yok", style: TextStyle(color: Colors.white54));
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: recentForms.map((f) {
        double r = double.tryParse(f['rating'].toString()) ?? 0.0;
        Color c = r >= 8 ? Colors.greenAccent : (r >= 6 ? Colors.orangeAccent : Colors.redAccent);
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: c.withOpacity(0.2), shape: BoxShape.circle, border: Border.all(color: c, width: 2)),
          alignment: Alignment.center,
          child: Text(r.toStringAsFixed(1), style: TextStyle(color: c, fontSize: 14, fontWeight: FontWeight.bold)),
        );
      }).toList(),
    );
  }
}

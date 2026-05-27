import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:devler_ligi/main.dart';

class AddMatchPage extends StatefulWidget {
  const AddMatchPage({super.key});

  @override
  State<AddMatchPage> createState() => _AddMatchPageState();
}

class _AddMatchPageState extends State<AddMatchPage> {
  
  String? selectedLeagueId;
  String? selectedHomeTeamId;
  String? selectedAwayTeamId;
  
  
  DateTime selectedDate = DateTime.now(); 
  TimeOfDay selectedTime = const TimeOfDay(hour: 20, minute: 0); 

  
  final TextEditingController _weekController = TextEditingController(text: "1");

  List<Map<String, dynamic>> leagues = [];
  List<Map<String, dynamic>> teams = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final leagueData = await supabase.from('leagues').select('id, name');
      if (leagueData.isNotEmpty) {
        selectedLeagueId = leagueData[0]['id'];
        await _loadTeams(selectedLeagueId!);
      }
      setState(() {
        leagues = List<Map<String, dynamic>>.from(leagueData);
        isLoading = false;
      });
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Veri hatası: $e")));
    }
  }

  Future<void> _loadTeams(String leagueId) async {
    final teamData = await supabase.from('teams').select('id, name').eq('league_id', leagueId);
    setState(() {
      teams = List<Map<String, dynamic>>.from(teamData);
      selectedHomeTeamId = null;
      selectedAwayTeamId = null;
    });
  }

  
  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != selectedDate) {
      setState(() => selectedDate = picked);
    }
  }

  
  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: selectedTime,
    );
    if (picked != null && picked != selectedTime) {
      setState(() => selectedTime = picked);
    }
  }

  Future<void> _saveMatch() async {
    if (selectedLeagueId == null || selectedHomeTeamId == null || selectedAwayTeamId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen takımları seçin")));
      return;
    }

    if (selectedHomeTeamId == selectedAwayTeamId) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Aynı takımı seçemezsin!"), backgroundColor: Colors.orange));
      return;
    }

    if (_weekController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen hafta girin!"), backgroundColor: Colors.orange));
      return;
    }

    
    final finalDateTime = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    try {
      await supabase.from('matches').insert({
        'league_id': selectedLeagueId,
        'home_team_id': selectedHomeTeamId,
        'away_team_id': selectedAwayTeamId,
        'match_date': finalDateTime.toIso8601String(),
        'match_week': int.parse(_weekController.text), 
        'status': 'scheduled', 
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Maç Planlandı!"), backgroundColor: Colors.green));
        context.pop(true);
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Yeni Maç Planla"), backgroundColor: const Color(0xFF06283D), foregroundColor: Colors.white),
      body: isLoading 
          ? const Center(child: CircularProgressIndicator()) 
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  
                  DropdownButtonFormField<String>(
                    value: selectedLeagueId,
                    decoration: const InputDecoration(labelText: "Lig", border: OutlineInputBorder()),
                    items: leagues.map((l) => DropdownMenuItem(value: l['id'] as String, child: Text(l['name']))).toList(),
                    onChanged: (val) {
                      setState(() { selectedLeagueId = val; });
                      if (val != null) _loadTeams(val);
                    },
                  ),
                  const SizedBox(height: 20),

                  
                  TextField(
                    controller: _weekController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Kaçıncı Hafta? (Örn: 1)",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_view_week),
                    ),
                  ),
                  const SizedBox(height: 20),

                  
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedHomeTeamId,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: "Ev Sahibi", border: OutlineInputBorder()),
                          items: teams.map((t) => DropdownMenuItem(value: t['id'] as String, child: Text(t['name'], overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (val) => setState(() => selectedHomeTeamId = val),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text("VS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      ),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedAwayTeamId,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: "Deplasman", border: OutlineInputBorder()),
                          items: teams.map((t) => DropdownMenuItem(value: t['id'] as String, child: Text(t['name'], overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (val) => setState(() => selectedAwayTeamId = val),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  const Text("Maç Zamanı", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  const SizedBox(height: 10),
                  
                  
                  Row(
                    children: [
                      
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickDate,
                          icon: const Icon(Icons.calendar_today),
                          label: Text("${selectedDate.day}.${selectedDate.month}.${selectedDate.year}"),
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickTime,
                          icon: const Icon(Icons.access_time),
                          label: Text(selectedTime.format(context)), 
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saveMatch,
                      icon: const Icon(Icons.save),
                      label: const Text("MAÇI PLANLA"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E88E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  )
                ],
              ),
            ),
    );
  }
}
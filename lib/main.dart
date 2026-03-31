import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // 1. Eklendi
import 'package:devler_ligi/features/auth/welcome_dashboard.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://xyrphhcphyrdhkahbwzi.supabase.co', 
    anonKey: 'sb_publishable_DZea2mfML4mezPRC69FrBA_19SEVPcn', 
  );

  // 2. ProviderScope ile sarmaladık
  runApp(const ProviderScope(child: MyApp()));
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Devler Ligi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E88E5)),
        useMaterial3: true,
      ),
      home: const WelcomeDashboard(), 
    );
  }
}
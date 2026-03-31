import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:devler_ligi/main.dart';
import 'package:devler_ligi/features/auth/register_page.dart';
import 'package:devler_ligi/features/home/home_page.dart';
import 'package:devler_ligi/features/admin/admin_panel.dart';
import 'package:devler_ligi/widgets/custom_nav_bar.dart'; // YENİ WIDGET'I IMPORT ETTİK

class WelcomeDashboard extends StatefulWidget {
  const WelcomeDashboard({super.key});

  @override
  State<WelcomeDashboard> createState() => _WelcomeDashboardState();
}

class _WelcomeDashboardState extends State<WelcomeDashboard> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _signIn() async {
    // ... (Giriş kodları aynen kalacak, burayı kısaltıyorum) ...
    // Mevcut kodunuzdaki _signIn fonksiyonunun aynısı buraya gelecek.
     setState(() => _isLoading = true);
    try {
      final authResponse = await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final userId = authResponse.user?.id;
      if (userId == null) throw "Giriş yapılamadı.";

      final data = await supabase.from('profiles').select('role').eq('id', userId).single();
      final role = data['role'] as String;

      if (mounted) {
        if (role == 'admin') {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminPanel()));
        } else {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomePage()));
        }
      }
    } on AuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: ${e.message}"), backgroundColor: Colors.red));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      // Scaffold background'ı genel koyu renk yapalım
      backgroundColor: Colors.black, 
      body: Column(
        children: [
          // 1. ADIM: SABİT ÜST MENÜ (Lacivert Arkaplanlı)
          const CustomNavBar(),

          // 2. ADIM: SAYFA İÇERİĞİ (Resim ve Login Alanı)
          // Expanded kullanıyoruz ki kalan tüm alanı kaplasın
          Expanded(
            child: Stack(
              children: [
                // A. ARKA PLAN RESMİ (Artık Navbar'ın altında)
                Container(
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: NetworkImage('https://images.unsplash.com/photo-1517466787929-bc90951d0974?q=80&w=1920&auto=format&fit=crop'), 
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                // Resmin üzerine hafif karartma
                Container(color: Colors.black.withOpacity(0.7)),

                // B. İÇERİK (Hero Text ve Login Kartı)
                SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                  child: Center( // İçeriği ortalamak için
                    child: isMobile 
                    ? Column(
                        children: [
                          _buildHeroText(), 
                          const SizedBox(height: 40), 
                          _buildLoginCard(context)
                        ]
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(child: _buildHeroText()),
                          const SizedBox(width: 50),
                          SizedBox(width: 400, child: _buildLoginCard(context)),
                        ],
                      ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min, // İçerik kadar yer kaplasın
      children: [
        const Text(
          "TÜRKİYE'NİN EN REKABETÇİ",
          style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
        ),
        Text(
          "HALI SAHA LİGİ",
          style: TextStyle(color: Colors.greenAccent[400], fontSize: 40, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 20),
        const Text(
          "Takımını kur, yeteneklerini sergile ve Devler Ligi'nde şampiyonluk için mücadele et.",
          style: TextStyle(color: Colors.white70, fontSize: 18),
        ),
        const SizedBox(height: 30),
        Row(
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterPage()));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
              child: const Text("HEMEN KATIL", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildLoginCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, spreadRadius: 5),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("HIZLI GİRİŞ", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          
          TextField(
            controller: _emailController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "E-posta Adresi",
              hintStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: Colors.white10,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              prefixIcon: const Icon(Icons.email, color: Colors.white54),
            ),
          ),
          const SizedBox(height: 15),

          TextField(
            controller: _passwordController,
            obscureText: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Şifre",
              hintStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: Colors.white10,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              prefixIcon: const Icon(Icons.lock, color: Colors.white54),
            ),
          ),
          const SizedBox(height: 25),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _signIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("GİRİŞ YAP", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          
          const SizedBox(height: 15),
          Center(
            child: TextButton(
              onPressed: () {
                 Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterPage()));
              },
              child: const Text("Hesabın yok mu? Hemen Kayıt Ol", style: TextStyle(color: Colors.greenAccent)),
            ),
          )
        ],
      ),
    );
  }
}
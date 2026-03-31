import 'package:flutter/material.dart';
import 'package:devler_ligi/main.dart'; // supabase erişimi
import 'package:devler_ligi/features/home/contact_page.dart';
import 'package:devler_ligi/features/home/home_page.dart';
import 'package:devler_ligi/features/auth/welcome_dashboard.dart';
import 'package:devler_ligi/features/home/my_team_page.dart'; // Takım işlemleri için

class CustomNavBar extends StatefulWidget {
  final bool showBackButton;

  const CustomNavBar({super.key, this.showBackButton = false});

  @override
  State<CustomNavBar> createState() => _CustomNavBarState();
}

class _CustomNavBarState extends State<CustomNavBar> {
  // Kurumsal Renkler
  final Color lacivert = const Color(0xFF06283D);
  final Color gold = const Color(0xFFFFD700);

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    final user = supabase.auth.currentUser; // Kullanıcı kontrolü

    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: lacivert,
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // SOL TARAFTAKİ LOGO
          Row(
            children: [
              if (widget.showBackButton)
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              InkWell(
                onTap: () => _handleHomeNavigation(context),
                child: Row(
                  children: [
                    Icon(Icons.emoji_events, color: gold, size: 36),
                    const SizedBox(width: 10),
                    const Text(
                      "DEVLER LİGİ",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // SAĞ MENÜ (PC İÇİN)
          if (!isMobile)
            Row(
              children: [
                _navButton(context, "ANA SAYFA"),
                _navButton(context, "KURAL KİTABI"),
                _navButton(context, "İLETİŞİM"),
                
                // --- PROFİL MENÜSÜ ---
                if (user != null) ...[
                  const SizedBox(width: 20), // İletişimden biraz ayır
                  _buildProfileMenu(context),
                ]
              ],
            )
        ],
      ),
    );
  }

  // --- GÖRSELDEKİ PROFİL MENÜSÜ TASARIMI ---
  Widget _buildProfileMenu(BuildContext context) {
    return PopupMenuButton<String>(
      offset: const Offset(0, 60), // Menüyü biraz aşağı kaydır
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tooltip: "Profil İşlemleri",
      // MENÜ TETİKLEYİCİSİ (ÜST BARDAKİ GÖRÜNÜM)
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white24),
        ),
        child: const Row(
          children: [
            Icon(Icons.person, color: Colors.white),
            SizedBox(width: 8),
            Text("HESABIM", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            Icon(Icons.arrow_drop_down, color: Colors.white),
          ],
        ),
      ),
      // AÇILAN MENÜNÜN İÇERİĞİ
      itemBuilder: (context) => [
        // 1. PROFİLE GİT
        _buildPopupMenuItem("profile", "PROFİLE GİT", Icons.person_outline, false),
        // 2. PROFİL GÜNCELLE
        _buildPopupMenuItem("update", "PROFİL GÜNCELLE", Icons.edit_outlined, false),
        // 3. TAKIM İŞLEMLERİ
        _buildPopupMenuItem("team", "TAKIM İŞLEMLERİ", Icons.groups_outlined, false),
        // 4. TRANSFER TEKLİFLERİ
        _buildPopupMenuItem("transfer", "TRANSFER TEKLİFLERİ", Icons.swap_horiz, false),
        // 5. ÇIKIŞ (Kırmızı)
        _buildPopupMenuItem("logout", "ÇIKIŞ", Icons.logout, true),
      ],
      // SEÇİM YAPILINCA ÇALIŞACAK FONKSİYON
      onSelected: (value) async {
        if (value == "logout") {
          await supabase.auth.signOut();
          if (context.mounted) {
            Navigator.pushAndRemoveUntil(
              context, 
              MaterialPageRoute(builder: (_) => const WelcomeDashboard()), 
              (route) => false
            );
          }
        } else if (value == "team") {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const MyTeamPage()));
        } else if (value == "profile" || value == "update" || value == "transfer") {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bu özellik yakında eklenecek!")));
        }
      },
    );
  }

  // --- ÖZEL MENÜ ELEMANI TASARIMI (GÖRSELE UYGUN) ---
  PopupMenuItem<String> _buildPopupMenuItem(String value, String text, IconData icon, bool isDestructive) {
    final color = isDestructive ? Colors.red : const Color(0xFF2E7D32); // Kırmızı veya Yeşil

    return PopupMenuItem<String>(
      value: value,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4), // Butonlar arası boşluk
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        width: double.infinity, // Genişliği doldur
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color, width: 1.5), // Çerçeve rengi
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center, // Ortala
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Text(
              text,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- YÖNLENDİRME MANTIĞI ---
  void _handleHomeNavigation(BuildContext context) {
    final user = supabase.auth.currentUser;
    if (user != null) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomePage()));
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const WelcomeDashboard()));
    }
  }

  Widget _navButton(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: TextButton(
        onPressed: () {
          if (title == "İLETİŞİM") {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactPage()));
          } else if (title == "ANA SAYFA") {
            _handleHomeNavigation(context);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$title yakında eklenecek!")));
          }
        },
        child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
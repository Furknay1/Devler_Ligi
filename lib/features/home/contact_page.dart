import 'package:flutter/material.dart';
import 'package:devler_ligi/widgets/custom_nav_bar.dart'; // CustomNavBar Importu

class ContactPage extends StatelessWidget {
  const ContactPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5), // Hafif gri arka plan
      body: Column(
        children: [
          // 1. KURUMSAL ÜST BAR (Geri butonu açık)
          const CustomNavBar(showBackButton: true),

          // 2. SAYFA İÇERİĞİ
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600), // PC'de çok yayılmasın
                  child: Column(
                    children: [
                      // Başlık
                      const Icon(Icons.support_agent, size: 80, color: Color(0xFF06283D)),
                      const SizedBox(height: 20),
                      const Text(
                        "BİZE ULAŞIN",
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF06283D), // Lacivert
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "Sorularınız, önerileriniz veya sponsorluk görüşmeleri için aşağıdaki kanallardan bize ulaşabilirsiniz.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 40),

                      // İletişim Kartları
                      _buildContactCard(Icons.email, "E-posta", "info@devlerligi.com"),
                      _buildContactCard(Icons.phone, "Telefon & WhatsApp", "+90 555 123 45 67"),
                      _buildContactCard(Icons.location_on, "Adres", "Levent, Büyükdere Cd. No:1, İstanbul"),
                      _buildContactCard(Icons.access_time, "Çalışma Saatleri", "Hafta içi: 09:00 - 18:00"),

                      const SizedBox(height: 40),
                      
                      // Sosyal Medya (Görsel Temsili)
                      const Text("BİZİ TAKİP EDİN", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF06283D))),
                      const SizedBox(height: 15),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildSocialIcon(Icons.camera_alt), // Instagram
                          const SizedBox(width: 20),
                          _buildSocialIcon(Icons.alternate_email), // Twitter/X
                          const SizedBox(width: 20),
                          _buildSocialIcon(Icons.video_library), // YouTube
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // İletişim Bilgisi Kartı Tasarımı
  Widget _buildContactCard(IconData icon, String title, String detail) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: const Color(0xFF06283D), // Lacivert Arka Plan
          child: Icon(icon, color: const Color(0xFFFFD700)), // Gold İkon
        ),
        title: Text(
          title, 
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
        ),
        subtitle: Text(
          detail,
          style: const TextStyle(fontSize: 15, color: Colors.black87),
        ),
      ),
    );
  }

  // Sosyal Medya İkonu Tasarımı
  Widget _buildSocialIcon(IconData icon) {
    return CircleAvatar(
      radius: 25,
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF06283D),
      child: Icon(icon, size: 30),
    );
  }
}
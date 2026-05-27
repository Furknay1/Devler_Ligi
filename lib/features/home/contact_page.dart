import 'package:flutter/material.dart';
import 'package:devler_ligi/widgets/custom_nav_bar.dart'; 

class ContactPage extends StatelessWidget {
  const ContactPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B101E), 
      body: Column(
        children: [
          
          const CustomNavBar(showBackButton: true),

          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600), 
                  child: Column(
                    children: [
                      
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF131B2F),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF00FF7F).withOpacity(0.3), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00FF7F).withOpacity(0.1),
                              blurRadius: 20,
                              spreadRadius: 5,
                            )
                          ],
                        ),
                        child: const Icon(Icons.support_agent, size: 60, color: Color(0xFF00FF7F)),
                      ),
                      const SizedBox(height: 30),
                      const Text(
                        "BİZE ULAŞIN",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Sorularınız, önerileriniz veya sponsorluk görüşmeleri için aşağıdaki kanallardan bize ulaşabilirsiniz.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 15, color: Colors.white70, height: 1.5),
                      ),
                      const SizedBox(height: 40),

                      
                      _buildContactCard(Icons.email_outlined, "E-posta", "info@devlerligi.com"),
                      _buildContactCard(Icons.phone_outlined, "Telefon & WhatsApp", "+90 555 123 45 67"),
                      _buildContactCard(Icons.location_on_outlined, "Adres", "Levent, Büyükdere Cd. No:1, İstanbul"),
                      _buildContactCard(Icons.access_time, "Çalışma Saatleri", "Hafta içi: 09:00 - 18:00"),

                      const SizedBox(height: 50),
                      
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 30,
                            height: 2,
                            color: const Color(0xFF00FF7F).withOpacity(0.5),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              "BİZİ TAKİP EDİN", 
                              style: TextStyle(
                                fontWeight: FontWeight.bold, 
                                color: Colors.white,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          Container(
                            width: 30,
                            height: 2,
                            color: const Color(0xFF00FF7F).withOpacity(0.5),
                          ),
                        ],
                      ),
                      const SizedBox(height: 25),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildSocialIcon(Icons.camera_alt_outlined), 
                          const SizedBox(width: 24),
                          _buildSocialIcon(Icons.alternate_email), 
                          const SizedBox(width: 24),
                          _buildSocialIcon(Icons.video_library_outlined), 
                        ],
                      ),
                      const SizedBox(height: 40),
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

  
  Widget _buildContactCard(IconData icon, String title, String detail) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0B101E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF00FF7F).withOpacity(0.2)),
          ),
          child: Icon(icon, color: const Color(0xFF00FF7F), size: 24),
        ),
        title: Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            title, 
            style: const TextStyle(
              fontWeight: FontWeight.bold, 
              fontSize: 13,
              color: Colors.white54,
              letterSpacing: 0.5,
            )
          ),
        ),
        subtitle: Text(
          detail,
          style: const TextStyle(
            fontSize: 15, 
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  
  Widget _buildSocialIcon(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2F),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Icon(icon, size: 24, color: Colors.white),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CustomFooter extends StatelessWidget {
  const CustomFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Container(
      width: double.infinity,
      color: const Color(0xFF0B101E), 
      padding: const EdgeInsets.only(top: 60, bottom: 20, left: 40, right: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min, 
        children: [
          isMobile ? _buildMobileColumns(context) : _buildDesktopColumns(context),
          
          const SizedBox(height: 40),
          Divider(color: Colors.white.withOpacity(0.1), height: 1),
          const SizedBox(height: 20),
          
          isMobile
              ? Column(
                  children: [
                    Text(
                      "© 2026 İstanbul Devler Ligi. Tüm hakları saklıdır.",
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _footerBottomLink("Kural Kitabı", context),
                        const Text("  ·  ", style: TextStyle(color: Colors.white54, fontSize: 12)),
                        _footerBottomLink("İletişim", context),
                      ],
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "© 2026 İstanbul Devler Ligi. Tüm hakları saklıdır.",
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                    ),
                    Row(
                      children: [
                        _footerBottomLink("Kural Kitabı", context),
                        const Text("  ·  ", style: TextStyle(color: Colors.white54, fontSize: 12)),
                        _footerBottomLink("İletişim", context),
                      ],
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildDesktopColumns(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Image.asset('assets/images/logo.jpeg', width: 40, height: 40, fit: BoxFit.contain, filterQuality: FilterQuality.high),
                  const SizedBox(width: 12),
                  const Text("İSTANBUL DEVLER LİGİ", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                "Türkiye'nin en rekabetçi halı saha ligi. Sahadaki yetenek, tribündeki heyecan.",
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.location_on, color: Color(0xFF00FF7F), size: 18),
                  const SizedBox(width: 8),
                  Text("İstanbul, Türkiye", style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 40),

        Expanded(
          flex: 1,
          child: _buildLinkColumn("Hızlı Erişim", [
            {"label": "Ana Sayfa", "route": "/"},
            {"label": "Puan Durumu", "route": "/home"},
            {"label": "Giriş Yap", "route": "/login"}, 
            {"label": "Kayıt Ol", "route": "/register"},
          ], context),
        ),

        Expanded(
          flex: 1,
          child: _buildLinkColumn("Yasal", [
            {"label": "Kural Kitabı", "route": "/rules"},
          ], context),
        ),

        Expanded(
          flex: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Bizi Takip Edin", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _socialIcon(Icons.facebook),
                  _socialIcon(Icons.video_library),
                  _socialIcon(Icons.camera_alt),
                  _socialIcon(Icons.alternate_email), 
                ],
              )
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileColumns(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Image.asset('assets/images/logo.jpeg', width: 40, height: 40, fit: BoxFit.contain, filterQuality: FilterQuality.high),
            const SizedBox(width: 12),
            const Text("İSTANBUL DEVLER LİGİ", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          "Türkiye'nin en rekabetçi halı saha ligi. Sahadaki yetenek, tribündeki heyecan.",
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Icon(Icons.location_on, color: Color(0xFF00FF7F), size: 18),
            const SizedBox(width: 8),
            Text("İstanbul, Türkiye", style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14)),
          ],
        ),
        const SizedBox(height: 30),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildLinkColumn("Hızlı Erişim", [
                {"label": "Ana Sayfa", "route": "/"},
                {"label": "Puan Durumu", "route": "/home"},
              ], context),
            ),
            Expanded(
              child: _buildLinkColumn("Yasal", [
                {"label": "Kural Kitabı", "route": "/rules"},
              ], context),
            ),
          ],
        ),
        const SizedBox(height: 30),
        const Text("Bizi Takip Edin", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _socialIcon(Icons.facebook),
            _socialIcon(Icons.video_library),
            _socialIcon(Icons.camera_alt),
          ],
        )
      ],
    );
  }

  Widget _buildLinkColumn(String title, List<Map<String, String>> links, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        ...links.map((link) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () {
                  if (link["route"] == "/login" || link["route"] == "/rules") {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bu özellik yakında eklenecek!")));
                  } else {
                    context.push(link["route"]!);
                  }
                },
                hoverColor: Colors.transparent,
                child: Text(
                  link["label"]!,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 14,
                  ),
                ),
              ),
            )),
      ],
    );
  }

  Widget _socialIcon(IconData icon) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Icon(icon, color: Colors.white70, size: 18),
    );
  }

  Widget _footerBottomLink(String text, BuildContext context) {
    return InkWell(
      onTap: () {
        if (text == "İletişim") {
          context.push('/contact');
        } else {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bu özellik yakında eklenecek!")));
        }
      },
      hoverColor: Colors.transparent,
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withOpacity(0.5),
          fontSize: 12,
        ),
      ),
    );
  }
}

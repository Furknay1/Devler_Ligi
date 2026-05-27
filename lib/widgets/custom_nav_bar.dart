import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:devler_ligi/main.dart'; 

class CustomNavBar extends StatefulWidget {
  final bool showBackButton;

  const CustomNavBar({super.key, this.showBackButton = false});

  @override
  State<CustomNavBar> createState() => _CustomNavBarState();
}

class _CustomNavBarState extends State<CustomNavBar> {
  
  final Color lacivert = const Color(0xFF06283D);
  final Color gold = const Color(0xFFFFD700);

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    final user = supabase.auth.currentUser; 

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
          height: 80,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: const Color(0xFF0B101E).withOpacity(0.7),
            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
          ),
          child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          
          Expanded(
            child: Row(
              children: [
                if (widget.showBackButton)
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                    onPressed: () => context.pop(),
                  ),
                Expanded(
                  child: InkWell(
                    onTap: () => _handleHomeNavigation(context),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2), 
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF00FF7F), width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00FF7F).withOpacity(0.4),
                                blurRadius: 12,
                                spreadRadius: 1,
                              )
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.asset(
                              'assets/images/logo.jpeg',
                              width: isMobile ? 40 : 56, 
                              height: isMobile ? 40 : 56, 
                              fit: BoxFit.cover,
                              filterQuality: FilterQuality.high, 
                              errorBuilder: (context, error, stackTrace) => 
                                  Icon(Icons.emoji_events, color: gold, size: isMobile ? 24 : 36),
                            ),
                          ),
                        ),
                        SizedBox(width: isMobile ? 8 : 12),
                        Expanded(
                          child: Text(
                            "İSTANBUL DEVLER LİGİ",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isMobile ? 16 : 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          
          if (!isMobile)
            Row(
              children: [
                _navButton(context, "ANA SAYFA"),
                _navButton(context, "KURAL KİTABI"),
                _navButton(context, "İLETİŞİM"),
                
                
                if (user != null) ...[
                  const SizedBox(width: 20), 
                  _buildProfileMenu(context),
                ]
              ],
            )
        ],
      ),
    ),
    ),
    );
  }

  
  Widget _buildProfileMenu(BuildContext context) {
    return PopupMenuButton<String>(
      offset: const Offset(0, 60), 
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tooltip: "Profil İşlemleri",
      
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
      
      itemBuilder: (context) => [
        
        _buildPopupMenuItem("profile", "PROFİLE GİT", Icons.person_outline, false),
        
        _buildPopupMenuItem("update", "PROFİL GÜNCELLE", Icons.edit_outlined, false),
        
        _buildPopupMenuItem("team", "TAKIM İŞLEMLERİ", Icons.groups_outlined, false),
        
        _buildPopupMenuItem("transfer", "TRANSFER TEKLİFLERİ", Icons.swap_horiz, false),
        
        _buildPopupMenuItem("logout", "ÇIKIŞ", Icons.logout, true),
      ],
      
      onSelected: (value) async {
        if (value == "logout") {
          await supabase.auth.signOut();
          if (context.mounted) {
            context.go('/');
          }
        } else if (value == "team") {
          Future.delayed(const Duration(milliseconds: 100), () => context.push('/my-team'));
        } else if (value == "profile") {
          Future.delayed(const Duration(milliseconds: 100), () => context.push('/profile'));
        } else if (value == "transfer") {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bu özellik yakında eklenecek!")));
        } else if (value == "update") {
          Future.delayed(const Duration(milliseconds: 100), () => context.push('/edit-profile'));
        }
      },
    );
  }

  
  PopupMenuItem<String> _buildPopupMenuItem(String value, String text, IconData icon, bool isDestructive) {
    final color = isDestructive ? Colors.red : const Color(0xFF2E7D32); 

    return PopupMenuItem<String>(
      value: value,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4), 
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        width: double.infinity, 
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color, width: 1.5), 
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center, 
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

  
  void _showLoginPrompt(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0B101E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: const Color(0xFF00FF7F).withOpacity(0.5)),
        ),
        title: const Text("Giriş Gerekli", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          "Bu sayfayı görüntülemek ve lige dahil olmak için giriş yapmalısınız veya takımınızı kurmalısınız.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Future.delayed(const Duration(milliseconds: 100), () {
                if (context.mounted) context.go('/register');
              });
            },
            child: const Text("KAYIT OL", style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Future.delayed(const Duration(milliseconds: 100), () {
                if (context.mounted) context.go('/');
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00FF7F),
              foregroundColor: Colors.black,
            ),
            child: const Text("GİRİŞ YAP", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  
  void _handleHomeNavigation(BuildContext context) {
    final user = supabase.auth.currentUser;
    if (user != null) {
      context.go('/home');
    } else {
      _showLoginPrompt(context);
    }
  }

  Widget _navButton(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: TextButton(
        onPressed: () {
          final user = supabase.auth.currentUser;
          if (user == null) {
            _showLoginPrompt(context);
            return;
          }
          
          if (title == "İLETİŞİM") {
            context.push('/contact');
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
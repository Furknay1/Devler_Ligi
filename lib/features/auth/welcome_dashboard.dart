import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:devler_ligi/main.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:devler_ligi/widgets/custom_footer.dart';

class WelcomeDashboard extends StatefulWidget {
  const WelcomeDashboard({super.key});

  @override
  State<WelcomeDashboard> createState() => _WelcomeDashboardState();
}

class _WelcomeDashboardState extends State<WelcomeDashboard> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _signIn(BuildContext dialogContext) async {
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
        setState(() => _isLoading = false);
        Navigator.pop(dialogContext); 
        if (role == 'admin') {
          context.go('/admin');
        } else {
          context.go('/home');
        }
        return;
      }
    } on AuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: ${e.message}"), backgroundColor: Colors.red));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red));
    }
    
    if (mounted) setState(() => _isLoading = false);
  }

  void _showLoginDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    width: 400,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withOpacity(0.7),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.sports_soccer, color: Color(0xFF00FF7F), size: 48),
                        const SizedBox(height: 16),
                        const Text("SAHAYA DÖN", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        const SizedBox(height: 30),
                        TextField(
                          controller: _emailController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: "E-Posta Adresi",
                            hintStyle: const TextStyle(color: Colors.white54),
                            filled: true,
                            fillColor: Colors.black.withOpacity(0.3),
                            prefixIcon: const Icon(Icons.email_outlined, color: Colors.white54),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: "Şifre",
                            hintStyle: const TextStyle(color: Colors.white54),
                            filled: true,
                            fillColor: Colors.black.withOpacity(0.3),
                            prefixIcon: const Icon(Icons.lock_outline, color: Colors.white54),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 30),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : () async {
                              setDialogState(() => _isLoading = true);
                              await _signIn(dialogContext);
                              setDialogState(() => _isLoading = false);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00FF7F),
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _isLoading 
                                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                                : const Text("GİRİŞ YAP", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            context.push('/register');
                          },
                          child: const Text("Hesabın Yok Mu? Kayıt Ol", style: TextStyle(color: Colors.white70)),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          
          Positioned.fill(
            child: Image.network(
              'https://images.unsplash.com/photo-1543351611-58f69d7c1781?q=80&w=2070&auto=format&fit=crop',
              fit: BoxFit.cover,
            ),
          ),
          
          
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.9),
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.8),
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
            ),
          ),

          
          Positioned.fill(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height),
                    child: IntrinsicHeight(
                      child: Column(
                        children: [
                          
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: MediaQuery.of(context).size.width < 600 ? 16 : 40, 
                              vertical: 30
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: const Color(0xFF00FF7F), width: 2),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF00FF7F).withOpacity(0.5),
                                              blurRadius: 15,
                                              spreadRadius: 2,
                                            )
                                          ],
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: Image.asset(
                                            'assets/images/logo.jpeg',
                                            width: MediaQuery.of(context).size.width < 600 ? 48 : 64, 
                                            height: MediaQuery.of(context).size.width < 600 ? 48 : 64, 
                                            fit: BoxFit.cover,
                                            filterQuality: FilterQuality.high, 
                                            errorBuilder: (context, error, stackTrace) => 
                                                const Icon(Icons.sports_soccer, color: Color(0xFF00FF7F), size: 40),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          "İSTANBUL DEVLER LİGİ", 
                                          style: GoogleFonts.racingSansOne(
                                            color: Colors.white, 
                                            fontSize: MediaQuery.of(context).size.width < 600 ? 20 : 26
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  onPressed: _showLoginDialog,
                                  icon: const Icon(Icons.login),
                                  label: Text(MediaQuery.of(context).size.width < 600 ? "GİRİŞ" : "GİRİŞ YAP"),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(color: Colors.white54),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: MediaQuery.of(context).size.width < 600 ? 16 : 24, 
                                      vertical: MediaQuery.of(context).size.width < 600 ? 10 : 14
                                    ),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                  ),
                                )
                              ],
                            ),
                          ),

                          const Spacer(),

                          
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width < 600 ? 16 : 40),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  "TÜRKİYE'NİN EN REKABETÇİ",
                                  style: TextStyle(color: Colors.white70, fontSize: MediaQuery.of(context).size.width < 600 ? 16 : 20, fontWeight: FontWeight.bold, letterSpacing: 4),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  "HALI SAHA LİGİNE",
                                  style: GoogleFonts.inter(color: Colors.white, fontSize: MediaQuery.of(context).size.width < 600 ? 32 : 48, fontWeight: FontWeight.w900, height: 1.1),
                                  textAlign: TextAlign.center,
                                ),
                                Text(
                                  "HOŞ GELDİN",
                                  style: GoogleFonts.inter(color: const Color(0xFF00FF7F), fontSize: MediaQuery.of(context).size.width < 600 ? 40 : 64, fontWeight: FontWeight.w900, height: 1.1),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),
                                Container(
                                  constraints: const BoxConstraints(maxWidth: 600),
                                  child: Text(
                                    "Takımını kur, yeteneklerini sergile, transfer borsasına düş ve Devler Ligi'nde şampiyonluk için mücadele et.",
                                    style: TextStyle(color: Colors.white70, fontSize: MediaQuery.of(context).size.width < 600 ? 15 : 18, height: 1.5),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(height: 50),
                                
                                
                                Container(
                                  decoration: BoxDecoration(
                                    boxShadow: [
                                      BoxShadow(color: const Color(0xFF00FF7F).withOpacity(0.4), blurRadius: 30, spreadRadius: 5),
                                    ],
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: ElevatedButton(
                                    onPressed: () => context.push('/register'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF00FF7F),
                                      foregroundColor: Colors.black,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: MediaQuery.of(context).size.width < 600 ? 24 : 50, 
                                        vertical: MediaQuery.of(context).size.width < 600 ? 16 : 20
                                      ),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          MediaQuery.of(context).size.width < 600 ? "HEMEN KATIL" : "YENİ YILDIZ OL: HEMEN KATIL", 
                                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1),
                                        ),
                                        const SizedBox(width: 12),
                                        const Icon(Icons.arrow_forward_rounded)
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const Spacer(flex: 2),
                        ],
                      ),
                    ),
                  ),
                  const CustomFooter(), 
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:devler_ligi/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:devler_ligi/widgets/custom_nav_bar.dart'; 

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  Future<void> _signUp() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("⚠️ Lütfen tüm alanları doldurun!"),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    final digitsOnly = phone.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("⚠️ Lütfen geçerli bir telefon numarası girin!"),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    setState(() => _isLoading = true);
    try {
      await supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': name,
          'phone': phone,
        },
      );

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF0F172A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFF00FF7F), width: 1)),
            title: const Row(
              children: [
                Icon(Icons.mark_email_unread_outlined, color: Color(0xFF00FF7F)),
                SizedBox(width: 10),
                Text("KAYIT BAŞARILI", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
              ],
            ),
            content: Text(
              "İstanbul Devler Ligi'ne katılımınız için ilk adım tamamlandı!\n\n"
              "Hesabınızı doğrulamak üzere $email adresine bir aktivasyon bağlantısı gönderilmiştir.\n\n"
              "Lütfen e-posta kutunuzu (Spam/Gereksiz klasörünü de) kontrol edip bağlantıya tıklayarak hesabınızı aktif edin. Aktivasyon yapılmadan sisteme giriş yapılamaz.",
              style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); 
                  Navigator.pop(context); 
                },
                child: const Text("TAMAM", style: TextStyle(color: Color(0xFF00FF7F), fontWeight: FontWeight.bold, fontSize: 16)),
              )
            ],
          ),
        );
        return;
      }
    } on AuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: ${e.message}"), backgroundColor: Colors.red));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Beklenmeyen Hata: $e"), backgroundColor: Colors.red));
    }
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
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
                    Colors.black.withOpacity(0.6),
                    Colors.black.withOpacity(0.8),
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
            ),
          ),

          
          Positioned.fill(
            child: Column(
              children: [
                
                const CustomNavBar(showBackButton: true),

                
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            width: 450,
                            padding: EdgeInsets.symmetric(
                              horizontal: MediaQuery.of(context).size.width < 600 ? 20 : 40, 
                              vertical: 40
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A).withOpacity(0.7),
                              border: Border.all(color: Colors.white.withOpacity(0.1)),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 30, spreadRadius: -5)
                              ]
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_border_rounded, color: Color(0xFF00FF7F), size: 56),
                                const SizedBox(height: 16),
                                const Text("YENİ YILDIZ OL", style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 2)),
                                const SizedBox(height: 8),
                                const Text("Lige katılmak için ücretsiz hesabını oluştur.", style: TextStyle(color: Colors.white54, fontSize: 15)),
                                const SizedBox(height: 40),

                                
                                TextField(
                                  controller: _nameController,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    hintText: 'Ad Soyad',
                                    hintStyle: const TextStyle(color: Colors.white54),
                                    filled: true,
                                    fillColor: Colors.black.withOpacity(0.3),
                                    prefixIcon: const Icon(Icons.person_outline, color: Colors.white54),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                TextField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    hintText: 'Telefon Numarası (örn: 05551234567)',
                                    hintStyle: const TextStyle(color: Colors.white54),
                                    filled: true,
                                    fillColor: Colors.black.withOpacity(0.3),
                                    prefixIcon: const Icon(Icons.phone_outlined, color: Colors.white54),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                
                                TextField(
                                  controller: _emailController,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    hintText: 'E-Posta Adresi',
                                    hintStyle: const TextStyle(color: Colors.white54),
                                    filled: true,
                                    fillColor: Colors.black.withOpacity(0.3),
                                    prefixIcon: const Icon(Icons.email_outlined, color: Colors.white54),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                
                                TextField(
                                  controller: _passwordController,
                                  obscureText: true,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    hintText: 'Şifre',
                                    hintStyle: const TextStyle(color: Colors.white54),
                                    filled: true,
                                    fillColor: Colors.black.withOpacity(0.3),
                                    prefixIcon: const Icon(Icons.lock_outline, color: Colors.white54),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  ),
                                ),
                                const SizedBox(height: 40),

                                
                                SizedBox(
                                  width: double.infinity,
                                  height: 55,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _signUp,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF00FF7F),
                                      foregroundColor: Colors.black,
                                      elevation: 8,
                                      shadowColor: const Color(0xFF00FF7F).withOpacity(0.5),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: _isLoading 
                                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black)) 
                                      : const Text("HESABIMI OLUŞTUR", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text("Zaten hesabın var mı?", style: TextStyle(color: Colors.white70)),
                                )
                              ],
                            ),
                          ),
                        ),
                      ),
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
}
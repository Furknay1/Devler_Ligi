import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:devler_ligi/providers/auth_provider.dart';
import 'package:devler_ligi/features/auth/register_page.dart';
import 'package:devler_ligi/features/home/home_page.dart';
import 'package:devler_ligi/features/admin/admin_panel.dart';
import 'package:devler_ligi/widgets/custom_nav_bar.dart'; 

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});
  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  void _handleLogin() async {
    FocusScope.of(context).unfocus();
    final success = await ref.read(authProvider.notifier).signIn(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

    if (success && mounted) {
      final role = ref.read(authProvider).role;
      if (role == 'admin') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminPanel()));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomePage()));
      }
    } else {
       final error = ref.read(authProvider).errorMessage;
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $error"), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      
      body: Column(
        children: [
          
          const CustomNavBar(showBackButton: true),

          
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox( 
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    children: [
                      const Text("GİRİŞ YAP", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF06283D))),
                      const SizedBox(height: 30),
                      
                      TextField(
                        controller: _emailController,
                        decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder(), prefixIcon: Icon(Icons.email)),
                      ),
                      const SizedBox(height: 16),
                      
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Şifre', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock)),
                      ),
                      const SizedBox(height: 24),
                      
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: authState.isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF06283D), 
                            foregroundColor: Colors.white, 
                            padding: const EdgeInsets.symmetric(vertical: 16)
                          ),
                          child: authState.isLoading 
                              ? const CircularProgressIndicator(color: Colors.white) 
                              : const Text("GİRİŞ YAP", style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterPage())),
                        child: const Text("Hesabın yok mu? Kayıt Ol", style: TextStyle(color: Color(0xFF06283D))),
                      ),
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
}
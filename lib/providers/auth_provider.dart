import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:devler_ligi/main.dart'; // supabase client için

// 1. Auth State Sınıfı (AYNI)
class AuthState {
  final bool isLoading;
  final String? errorMessage;
  final String? role; // 'admin' veya 'user'

  AuthState({this.isLoading = false, this.errorMessage, this.role});
}

// 2. Notifier Sınıfı (YENİ SÖZDİZİMİ)
// 'extends StateNotifier' YERİNE 'extends Notifier' kullanıyoruz.
class AuthNotifier extends Notifier<AuthState> {
  
  // Başlangıç durumu (Constructor yerine build metodu kullanılır)
  @override
  AuthState build() {
    return AuthState(); // Initial State
  }

  // Giriş Yapma Fonksiyonu
  Future<bool> signIn(String email, String password) async {
    // state = ... diyerek durumu güncelliyoruz.
    state = AuthState(isLoading: true); 

    try {
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final userId = response.user?.id;
      if (userId == null) throw "Kullanıcı ID alınamadı.";

      final data = await supabase
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .single();

      final role = data['role'] as String;

      state = AuthState(isLoading: false, role: role);
      return true;
    } catch (e) {
      state = AuthState(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  // Çıkış Yapma
  Future<void> signOut() async {
    await supabase.auth.signOut();
    state = AuthState(); // Sıfırla
  }
}

// 3. Provider Tanımı (YENİ)
// StateNotifierProvider YERİNE NotifierProvider
final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});
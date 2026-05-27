import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:devler_ligi/main.dart'; 


class AuthState {
  final bool isLoading;
  final String? errorMessage;
  final String? role; 

  AuthState({this.isLoading = false, this.errorMessage, this.role});
}



class AuthNotifier extends Notifier<AuthState> {
  
  
  @override
  AuthState build() {
    return AuthState(); 
  }

  
  Future<bool> signIn(String email, String password) async {
    state = AuthState(isLoading: true); 

    try {
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final userId = response.user?.id;
      if (userId == null) throw "Kullanıcı ID alınamadı.";

      Map<String, dynamic>? data;
      try {
        data = await supabase
            .from('profiles')
            .select('role')
            .eq('id', userId)
            .single();
      } catch (e) {
        // Fallback: Eğer tetikleyici çalışmadıysa veya profiles tablosunda satır oluşmadıysa otomatik oluştur
        final email = response.user?.email ?? "";
        final username = email.split('@').first;
        final fullName = response.user?.userMetadata?['full_name'] ?? "";
        final phone = response.user?.userMetadata?['phone'] ?? "";
        
        try {
          await supabase.from('profiles').insert({
            'id': userId,
            'username': username,
            'full_name': fullName,
            'phone': phone,
            'role': 'player'
          });
          data = {'role': 'player'};
        } catch (insertError) {
          // Eğer veritabanı yazma izni RLS vb. takılırsa hatayı yukarı fırlat
          throw "Profil bilgileri oluşturulamadı. Lütfen veritabanı ayarlarını kontrol edin: $insertError";
        }
      }

      final role = data?['role'] as String? ?? 'player';

      state = AuthState(isLoading: false, role: role);
      return true;
    } catch (e) {
      String errorMessage = e.toString();
      
      if (errorMessage.contains("Email not confirmed") || errorMessage.contains("email_not_confirmed")) {
        errorMessage = "Hesabınız henüz onaylanmamış. Lütfen e-posta kutunuza (Spam/Gereksiz klasörünü de kontrol ederek) gönderilen doğrulama linkine tıklayıp hesabınızı onaylayın.";
      } else if (errorMessage.contains("Invalid login credentials") || errorMessage.contains("invalid_credentials")) {
        errorMessage = "E-posta adresi veya şifre hatalı.";
      }
      
      state = AuthState(isLoading: false, errorMessage: errorMessage);
      return false;
    }
  }

  
  Future<void> signOut() async {
    await supabase.auth.signOut();
    state = AuthState(); 
  }
}



final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserService {
  // Usamos una propiedad getter para asegurar que siempre usamos la instancia actual
  SupabaseClient get _supa => Supabase.instance.client;

  /// Devuelve 'admin' | 'coach' | 'client'.
  /// Si hay error/RLS/fila inexistente => devuelve null (NO forzar 'client').
  Future<String?> getRole() async {
    try {
      final uid = _supa.auth.currentUser?.id;
      if (uid == null) return null;

      // 1) Chequeo rápido: is_admin() (RPC segura con security definer)
      try {
        final isAdm = await _supa.rpc('is_admin') as bool?;
        if (isAdm == true) return 'admin';
      } catch (_) {
        // Si falla la RPC o no existe, seguimos con el select normal
      }

      // 2) Leer mi fila en app_user
      final me = await _supa
          .from('app_user')
          .select('role')
          .eq('auth_user_id', uid)
          .maybeSingle();

      final role = (me?['role'] as String?)?.toLowerCase();

      if (role == 'admin' || role == 'coach' || role == 'client') {
        return role;
      }

      // Si existe el usuario pero el rol es extraño o nulo, asumimos cliente por defecto
      // (Ojo: solo si 'me' no fue null. Si 'me' es null, devolvemos null abajo)
      if (me != null) {
        return 'client';
      }

      return null;
    } catch (e) {
      debugPrint('[UserService.getRole] ERROR: $e');
      return null;
    }
  }

  /// Verifica si el Cliente actual tiene un Entrenador asignado.
  Future<bool> isClientLinkedToTrainer() async {
    try {
      final user = _supa.auth.currentUser;
      if (user == null) return false;

      final clientProfile = await _supa
          .from('app_user')
          .select('id')
          .eq('auth_user_id', user.id)
          .maybeSingle();

      if (clientProfile == null) return false;

      final clientId = clientProfile['id'];

      final client = await _supa
          .from('clients')
          .select('id')
          .eq('app_user_id', clientId)
          .maybeSingle();

      if (client == null) {
        // El usuario no tiene perfil de cliente creado aún
        return false;
      }

      final clientTableId = client['id'];

      // 2. Ver si aparece en la tabla de relación client_trainer
      final link = await _supa
          .from('client_trainer')
          .select('id') // Solo traemos el ID para ser más eficientes
          .eq('client_id', clientTableId)
          .maybeSingle();

      // Si link no es nulo, significa que encontró la relación
      return link != null;
    } catch (e) {
      debugPrint('[UserService.isClientLinkedToTrainer] ERROR: $e');
      return false;
    }
  }
}

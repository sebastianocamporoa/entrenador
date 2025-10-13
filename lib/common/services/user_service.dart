import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserService {
  final _supa = Supabase.instance.client;

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
        // seguimos con select normal
      }

      // 2) Leer mi fila en app_user (policy: app_user_self_select)
      final me = await _supa
          .from('app_user')
          .select('role')
          .eq('auth_user_id', uid)
          .maybeSingle();

      final role = (me?['role'] as String?)?.toLowerCase();
      if (role == 'admin' || role == 'coach' || role == 'client') {
        return role;
      }
      return 'client'; // default si hay fila pero sin rol válido
    } catch (e) {
      // Importante: NO forzar 'client' ante errores de permisos o query.
      debugPrint('[UserService.getRole] ERROR: $e');
      return null;
    }
  }

  /// ¿Cliente asociado a un entrenador?
  Future<bool> isClientLinkedToTrainer() async {
    try {
      final uid = _supa.auth.currentUser?.id;
      if (uid == null) return false;

      // Si es admin o coach, no aplica
      final role = await getRole();
      if (role == 'admin' || role == 'coach')
        return true; // evita bloquear dashboards

      final appUser = await _supa
          .from('app_user')
          .select('id')
          .eq('auth_user_id', uid)
          .single();
      final auid = appUser['id'] as String;

      final row = await _supa
          .from('clients')
          .select('id, trainer_id')
          .eq('app_user_id', auid)
          .maybeSingle();

      if (row != null && row['trainer_id'] != null) return true;

      // fallback por email si lo usas en tus datos
      final email = _supa.auth.currentUser?.email;
      if (email != null) {
        final byEmail = await _supa
            .from('clients')
            .select('trainer_id')
            .eq('email', email)
            .maybeSingle();
        return (byEmail != null && byEmail['trainer_id'] != null);
      }
      return false;
    } catch (e) {
      debugPrint('[isClientLinkedToTrainer] ERROR: $e -> false');
      return false;
    }
  }
}

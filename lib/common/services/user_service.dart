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
    final supa = Supabase.instance.client;
    final user = supa.auth.currentUser;
    if (user == null) return false;

    // 1. Obtener app_user.id
    final profile = await supa
        .from('app_user')
        .select('id')
        .eq('auth_user_id', user.id)
        .maybeSingle();

    if (profile == null) return false;
    final appUserId = profile['id'];

    // 2. Obtener clients.id usando app_user_id
    final client = await supa
        .from('clients')
        .select('id')
        .eq('app_user_id', appUserId)
        .maybeSingle();

    if (client == null) return false;
    final clientTableId = client['id'];

    // 3. Ver si aparece en client_trainer
    final link = await supa
        .from('client_trainer')
        .select()
        .eq('client_id', clientTableId)
        .maybeSingle();

    return link != null;
  }
}

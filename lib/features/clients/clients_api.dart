import 'package:supabase_flutter/supabase_flutter.dart';

class ClientsApi {
  final _db = Supabase.instance.client;

  /// 🔹 Devuelve la lista de clientes asociados al entrenador actual.
  /// Ya no permite crear, actualizar ni eliminar.
  Future<List<Map<String, dynamic>>> list() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return [];

    final res = await _db
        .from('client_trainer')
        .select(
          'client_id, client:client_id(name, email, phone, goal, sex, is_active)',
        )
        .eq('trainer_id', uid);

    return List<Map<String, dynamic>>.from(
      res.map((e) {
        final c = e['client'] ?? {};
        return {
          'id': e['client_id'],
          'name': c['name'] ?? '—',
          'email': c['email'],
          'phone': c['phone'],
          'goal': c['goal'],
          'sex': c['sex'],
          'is_active': c['is_active'] ?? true,
        };
      }),
    );
  }
}

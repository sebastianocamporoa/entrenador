import 'package:supabase_flutter/supabase_flutter.dart';

class ClientsApi {
  final _db = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> list() async {
    final uid = _db.auth.currentUser!.id;

    final res = await _db
        .from('client_trainer')
        .select('client_id, client:client_id(name, email, phone, goal, sex)')
        .eq('trainer_id', uid);

    return List<Map<String, dynamic>>.from(
      res.map(
        (e) => {
          'id': e['client_id'],
          'name': e['client']?['name'] ?? '—',
          'email': e['client']?['email'],
          'phone': e['client']?['phone'],
          'goal': e['client']?['goal'],
          'sex': e['client']?['sex'],
        },
      ),
    );
  }

  Future<void> create({required String email}) async {
    final uid = _db.auth.currentUser!.id; // entrenador actual
    final cleanEmail = email.trim().toLowerCase();

    // 🔍 Verificar si ya existe ese correo
    final exists = await _db
        .from('clients')
        .select('id')
        .eq('email', cleanEmail)
        .maybeSingle();

    if (exists != null) {
      throw Exception('Ya existe un cliente con ese correo');
    }

    // 🆕 Crear cliente
    final inserted = await _db
        .from('clients')
        .insert({
          'trainer_id': uid,
          'email': cleanEmail,
          'name': cleanEmail.split('@').first,
        })
        .select('id')
        .single();

    final clientId = inserted['id'] as String;

    // 🔗 Insertar también en client_trainer
    await _db.from('client_trainer').insert({
      'trainer_id': uid,
      'client_id': clientId,
    });
  }

  Future<void> remove(String id) async {
    await _db.from('clients').delete().eq('id', id);
  }

  Future<void> update(String id, Map<String, dynamic> fields) async {
    await _db.from('clients').update(fields).eq('id', id);
  }
}

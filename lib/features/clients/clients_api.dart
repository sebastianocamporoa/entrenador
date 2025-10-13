import 'package:supabase_flutter/supabase_flutter.dart';

class ClientsApi {
  final _db = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> list() async {
    final res = await _db
        .from('clients')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<void> create({
    required String name,
    String? email,
    String? phone,
    String? goal,
    String? sex, // 'M','F','O'
  }) async {
    final uid = _db.auth.currentUser!.id; // entrenador actual
    await _db.from('clients').insert({
      'trainer_id': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'goal': goal,
      'sex': sex,
    });
  }

  Future<void> remove(String id) async {
    await _db.from('clients').delete().eq('id', id);
  }

  Future<void> update(String id, Map<String, dynamic> fields) async {
    await _db.from('clients').update(fields).eq('id', id);
  }
}

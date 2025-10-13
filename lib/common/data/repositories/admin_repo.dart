import 'package:supabase_flutter/supabase_flutter.dart';

class AdminRepo {
  final _supa = Supabase.instance.client;

  Future<Map<String, dynamic>?> findAppUserByEmail(String email) async {
    final row = await _supa
        .from('app_user')
        .select('id, auth_user_id, email, role')
        .eq('email', email)
        .maybeSingle();
    return row;
  }

  Future<void> promoteToCoachByEmail(String email) async {
    // idempotente: si ya es coach, no pasa nada
    await _supa.from('app_user').update({'role': 'coach'}).eq('email', email);
  }

  Future<void> demoteToClientByEmail(String email) async {
    await _supa.from('app_user').update({'role': 'client'}).eq('email', email);
  }
}

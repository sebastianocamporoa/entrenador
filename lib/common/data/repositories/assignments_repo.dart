import 'package:supabase_flutter/supabase_flutter.dart';

class AssignmentsRepo {
  final _supa = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> todayWorkoutForClient() async {
    final user = _supa.auth.currentUser;
    if (user == null) return [];

    // ===============================
    // DEBUG
    // ===============================
    print('==============================');
    print('=== DEBUG CLIENT WORKOUT ===');

    print('auth_user_id = ${user.id}');

    // 1) Obtener app_user
    final profile = await _supa
        .from('app_user')
        .select('id, email, role')
        .eq('auth_user_id', user.id)
        .maybeSingle();

    print('app_user row = $profile');

    if (profile == null) {
      print('❌ No existe app_user — retornando vacío');
      print('==============================');
      return [];
    }

    final appUserId = profile['id'];

    // 2) Buscar fila en clients
    final clientRow = await _supa
        .from('clients')
        .select('id, email, app_user_id')
        .eq('app_user_id', appUserId)
        .maybeSingle();

    print('clients row = $clientRow');

    if (clientRow == null) {
      print('❌ No existe fila en clients — retornando vacío');
      print('==============================');
      return [];
    }

    final clientId = clientRow['id'];

    // ===============================
    // 3) Buscar la sesión iniciada MÁS RECIENTE
    // (sin filtrar por fecha porque UTC rompía la lógica)
    // ===============================
    final sessionRes = await _supa
        .from('training_session')
        .select('id, start_time, client_id, started')
        .eq('client_id', clientId)
        .eq('started', true)
        .order('start_time', ascending: false)
        .limit(1);

    print('training_session result = $sessionRes');

    if (sessionRes.isEmpty) {
      print('❌ NO SESSION STARTED — retornando vacío');
      print('==============================');
      return [];
    }

    final sessionId = sessionRes.first['id'];
    print('sessionId = $sessionId');

    // ===============================
    // 4) Obtener workout asociado a esa sesión
    // ===============================
    final data = await _supa.rpc(
      'get_workout_for_session',
      params: {'session_id': sessionId},
    );

    print('workout result = $data');
    print('==============================');

    return List<Map<String, dynamic>>.from(data);
  }
}

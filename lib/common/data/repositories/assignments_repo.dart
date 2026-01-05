import 'package:supabase_flutter/supabase_flutter.dart';

class AssignmentsRepo {
  final _supa = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> todayWorkoutForClient() async {
    final user = _supa.auth.currentUser;
    if (user == null) return [];

    // 1) Obtener IDs
    final profile = await _supa
        .from('app_user')
        .select('id')
        .eq('auth_user_id', user.id)
        .maybeSingle();
    if (profile == null) return [];

    final clientRow = await _supa
        .from('clients')
        .select('id')
        .eq('app_user_id', profile['id'])
        .maybeSingle();
    if (clientRow == null) return [];

    final clientId = clientRow['id'];

    // 2) DEFINIR RANGO DE TIEMPO (UTC)
    final now = DateTime.now().toUtc();

    // Calculamos el inicio del día de hoy (00:00:00)
    // Nota: Si quieres que sea el inicio del día en COLOMBIA, debes manejar la zona horaria.
    // Por defecto aquí tomamos el inicio del día UTC para simplificar con la DB.
    final startOfDay = DateTime.utc(now.year, now.month, now.day);

    // Convertimos a ISO String para Supabase
    final nowIso = now.toIso8601String();
    final startDayIso = startOfDay.toIso8601String();

    // 3) CONSULTA ESTRICTA DE "HOY"
    final sessionRes = await _supa
        .from('training_session')
        .select('id, start_time, client_id, started')
        .eq('client_id', clientId)
        .eq('started', true) // Entrenador inició
        .gte('start_time', startDayIso) // Mayor que hoy a las 00:00
        .lte('start_time', nowIso) // Menor que AHORA mismo
        .order('start_time', ascending: false)
        .limit(1);

    if (sessionRes.isEmpty) {
      // Si con tu data del 17 de Dic pruebas esto HOY (22 Dic),
      // esto retornará vacío. ¡ES LO CORRECTO!
      // Porque hoy 22 no tienes clase asignada/iniciada.
      return [];
    }

    final sessionId = sessionRes.first['id'];

    // 4) Obtener ejercicios
    final data = await _supa.rpc(
      'get_workout_for_session',
      params: {'session_id': sessionId},
    );

    return List<Map<String, dynamic>>.from(data);
  }

  /// 🔹 Verifica el estado de la sesión de HOY para dar feedback al usuario
  Future<Map<String, dynamic>?> getTodaySessionStatus() async {
    final user = _supa.auth.currentUser;
    if (user == null) return null;

    // 1. Obtener IDs (App User -> Client)
    final profile = await _supa
        .from('app_user')
        .select('id')
        .eq('auth_user_id', user.id)
        .maybeSingle();
    if (profile == null) return null;

    final clientRow = await _supa
        .from('clients')
        .select('id')
        .eq('app_user_id', profile['id'])
        .maybeSingle();
    if (clientRow == null) return null;

    final clientId = clientRow['id'];

    // 2. Rango de tiempo HOY (UTC)
    final now = DateTime.now().toUtc();
    final startOfDay = DateTime.utc(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(hours: 23, minutes: 59));

    // 3. Buscar CUALQUIER sesión programada para hoy (iniciada o no)
    final res = await _supa
        .from('training_session')
        .select('start_time, started')
        .eq('client_id', clientId)
        .gte('start_time', startOfDay.toIso8601String())
        .lte('start_time', endOfDay.toIso8601String())
        .order('start_time', ascending: false) // La última del día
        .limit(1)
        .maybeSingle();

    return res;
    // Retorna:
    // null -> No hay nada programado hoy.
    // Map -> { 'start_time': '...', 'started': false/true }
  }

  // 1. Guardar el peso
  Future<void> logExerciseWeight(String exerciseName, double weight) async {
    final user = _supa.auth.currentUser;
    if (user == null) return;

    // Obtener ID del cliente (Lógica rápida)
    final appUser = await _supa
        .from('app_user')
        .select('id')
        .eq('auth_user_id', user.id)
        .single();
    final client = await _supa
        .from('clients')
        .select('id')
        .eq('app_user_id', appUser['id'])
        .single();

    await _supa.from('exercise_logs').insert({
      'client_id': client['id'],
      'exercise_name': exerciseName,
      'weight': weight,
    });
  }

  // 2. Obtener historial para la gráfica
  Future<List<Map<String, dynamic>>> getExerciseHistory(
    String exerciseName,
  ) async {
    final user = _supa.auth.currentUser;
    if (user == null) return [];

    final appUser = await _supa
        .from('app_user')
        .select('id')
        .eq('auth_user_id', user.id)
        .single();
    final client = await _supa
        .from('clients')
        .select('id')
        .eq('app_user_id', appUser['id'])
        .single();

    final response = await _supa
        .from('exercise_logs')
        .select('weight, created_at')
        .eq('client_id', client['id'])
        .eq('exercise_name', exerciseName)
        .order(
          'created_at',
          ascending: true,
        ) // Importante para la línea de tiempo
        .limit(20); // Últimos 20 registros

    return List<Map<String, dynamic>>.from(response);
  }
}

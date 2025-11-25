import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/training_session.dart';

class TrainingSessionsRepo {
  final _supa = Supabase.instance.client;

  /// 🔹 Obtiene todas las sesiones del entrenador autenticado
  Future<List<TrainingSession>> getSessions() async {
    final user = _supa.auth.currentUser;
    if (user == null) throw Exception('Usuario no autenticado');

    final res = await _supa
        .from('training_session')
        .select(
          'id, trainer_id, client_id, start_time, end_time, notes, started, client:client_id(name)',
        )
        .eq('trainer_id', user.id)
        .order('start_time', ascending: true);

    return (res as List)
        .map(
          (e) => TrainingSession.fromJson({
            ...e,
            'client_name': e['client']?['name'],
          }),
        )
        .toList();
  }

  /// 🔹 Crea una nueva sesión
  Future<void> addSession({
    required DateTime startTime,
    required DateTime endTime,
    String? notes,
    required String? clientId,
  }) async {
    final user = _supa.auth.currentUser;
    if (user == null) throw Exception('Usuario no autenticado');
    if (clientId == null) throw Exception('Selecciona un cliente');

    await _supa.from('training_session').insert({
      'trainer_id': user.id,
      'client_id': clientId,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'notes': notes,
      'started': false, // 👈 nuevo campo por defecto
    });
  }

  /// 🔹 Elimina una sesión
  Future<void> deleteSession(String id) async {
    await _supa.from('training_session').delete().eq('id', id);
  }

  /// 🔹 Actualiza una sesión
  Future<void> updateSession(TrainingSession session) async {
    await _supa
        .from('training_session')
        .update({
          'start_time': session.startTime.toIso8601String(),
          'end_time': session.endTime.toIso8601String(),
          'notes': session.notes,
          'client_id': session.clientId,
        })
        .eq('id', session.id);
  }

  /// 🔹 Marca una sesión como iniciada (nuevo paso 3)
  Future<void> markSessionStarted(String id) async {
    await _supa.from('training_session').update({'started': true}).eq('id', id);
  }
}

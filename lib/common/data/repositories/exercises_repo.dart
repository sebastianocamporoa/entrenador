import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/exercise.dart';

class ExercisesRepo {
  final _supa = Supabase.instance.client;

  // Modificado: Trae Globales + Los creados por el usuario actual
  Future<List<Exercise>> listAllVisible() async {
    final uid = _supa.auth.currentUser?.id;

    // Si no hay usuario logueado, retornamos vacío o solo globales por seguridad
    if (uid == null) return [];

    // Sintaxis de filtro OR en Supabase: "col1.eq.val1,col2.eq.val2"
    final res = await _supa
        .from('exercise')
        .select()
        .or('scope.eq.global,trainer_id.eq.$uid')
        .order('name', ascending: true);

    return (res as List).map((m) => Exercise.fromMap(m)).toList();
  }

  // ADMIN crea ejercicios GLOBAL
  Future<String> addGlobal(Exercise e) async {
    final data = e.toInsert(scope: 'global');
    // Aseguramos que trainer_id sea null para globales
    data['trainer_id'] = null;

    final inserted = await _supa
        .from('exercise')
        .insert(data)
        .select('id')
        .single();
    return inserted['id'] as String;
  }

  // COACH crea ejercicios privados
  Future<String> addCoach(Exercise e) async {
    final uid = _supa.auth.currentUser!.id;
    // Asignamos trainer_id al usuario actual
    final data = e.toInsert(scope: 'coach')..addAll({'trainer_id': uid});

    final inserted = await _supa
        .from('exercise')
        .insert(data)
        .select('id')
        .single();
    return inserted['id'] as String;
  }

  Future<void> update(String id, Map<String, dynamic> patch) async {
    await _supa.from('exercise').update(patch).eq('id', id);
  }

  Future<void> remove(String id) async {
    await _supa.from('exercise').delete().eq('id', id);
  }
}

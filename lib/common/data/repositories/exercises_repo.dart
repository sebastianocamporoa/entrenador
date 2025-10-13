import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/exercise.dart';

class ExercisesRepo {
  final _supa = Supabase.instance.client;

  Future<List<Exercise>> listAllVisible() async {
    final res = await _supa
        .from('exercise')
        .select()
        .order('name', ascending: true); // o 'created_at' si lo agregaste
    return (res as List).map((m) => Exercise.fromMap(m)).toList();
  }

  // ADMIN crea ejercicios GLOBAL -> SIN trainer_id
  Future<String> addGlobal(Exercise e) async {
    final data = e.toInsert(scope: 'global'); // no incluimos trainer_id
    final inserted = await _supa
        .from('exercise')
        .insert(data)
        .select('id')
        .single();
    return inserted['id'] as String;
  }

  // COACH crea ejercicios privados -> CON trainer_id = auth.uid()
  Future<String> addCoach(Exercise e) async {
    final uid = _supa.auth.currentUser!.id;
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

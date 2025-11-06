import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/training_plan.dart';
import '../models/training_plan_exercise.dart';

class PlansRepo {
  final _supa = Supabase.instance.client;

  /// 🔹 Lista planes globales (solo visibles por admin o coach)
  Future<List<TrainingPlan>> listGlobalPlans() async {
    final res = await _supa
        .from('training_plan')
        .select()
        .eq('scope', 'global')
        .order('created_at', ascending: false);

    return (res as List).map((m) => TrainingPlan.fromMap(m)).toList();
  }

  /// 🔹 Lista planes del entrenador actual
  Future<List<TrainingPlan>> listMyPlans() async {
    final user = _supa.auth.currentUser;
    if (user == null) return [];

    final res = await _supa
        .from('training_plan')
        .select()
        .eq('trainer_id', user.id)
        .order('created_at', ascending: false);

    return (res as List).map((m) => TrainingPlan.fromMap(m)).toList();
  }

  /// 🔹 Crea un plan global (admin)
  Future<String> addGlobalPlan(TrainingPlan plan) async {
    final data = plan.toInsert();
    final inserted = await _supa
        .from('training_plan')
        .insert({...data, 'scope': 'global'})
        .select('id')
        .single();
    return inserted['id'] as String;
  }

  /// 🔹 Crea un plan normal (coach)
  Future<String> add(TrainingPlan plan) async {
    final data = plan.toInsert();
    final inserted = await _supa
        .from('training_plan')
        .insert({...data, 'scope': 'coach'})
        .select('id')
        .single();
    return inserted['id'] as String;
  }

  /// 🔹 Elimina un plan
  Future<void> remove(String id) async {
    await _supa.from('training_plan').delete().eq('id', id);
  }

  /// 🔹 Obtiene los ejercicios asignados a un plan
  Future<List<TrainingPlanExercise>> getExercises(String planId) async {
    final res = await _supa
        .from('training_plan_exercise')
        .select('*, exercise:exercise_id(name)')
        .eq('plan_id', planId);

    return (res as List).map((m) => TrainingPlanExercise.fromMap(m)).toList();
  }

  /// 🔹 Agrega ejercicios a un plan
  Future<void> addExercises(
    String planId,
    List<TrainingPlanExercise> list,
  ) async {
    final data = list.map((e) => e.toMap()).toList();
    await _supa.from('training_plan_exercise').insert(data);
  }
}

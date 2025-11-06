import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/training_plan.dart';
import '../models/training_plan_exercise.dart';

class PlansRepo {
  final _supa = Supabase.instance.client;

  // 🔹 ADMIN: listar todos los planes (globales)
  Future<List<TrainingPlan>> listAll() async {
    final res = await _supa
        .from('training_plan')
        .select()
        .order('created_at', ascending: false);
    return (res as List)
        .map((e) => TrainingPlan.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  // 🔹 COACH: listar solo sus planes
  Future<List<TrainingPlan>> listMyPlans() async {
    final user = _supa.auth.currentUser;
    if (user == null) return [];

    final res = await _supa
        .from('training_plan')
        .select()
        .or('scope.eq.coach,and(scope.eq.global)')
        .order('created_at', ascending: false);

    // Nota: puedes filtrar si solo quieres los del entrenador
    // .eq('trainer_id', user.id)
    return (res as List)
        .map((e) => TrainingPlan.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  // 🔹 ADMIN: agregar plan global
  Future<String> addGlobal(String name, {String? description}) async {
    final user = _supa.auth.currentUser;
    final inserted = await _supa
        .from('training_plan')
        .insert({
          'name': name,
          'description': description,
          'scope': 'global',
          'trainer_id': user?.id,
        })
        .select('id')
        .single();
    return inserted['id'];
  }

  // 🔹 COACH: agregar plan propio
  Future<String> add(TrainingPlan plan) async {
    final inserted = await _supa
        .from('training_plan')
        .insert({
          'trainer_id': plan.trainerId,
          'name': plan.name,
          'description': plan.description,
          'scope': 'coach',
        })
        .select('id')
        .single();
    return inserted['id'];
  }

  Future<void> remove(String id) async {
    await _supa.from('training_plan').delete().eq('id', id);
  }

  Future<void> removePlan(String id) async {
    await remove(id);
  }

  // 🔹 Obtener ejercicios de un plan
  Future<List<TrainingPlanExercise>> getExercises(String planId) async {
    final res = await _supa
        .from('training_plan_exercise')
        .select('*, exercise:exercise_id(name)')
        .eq('plan_id', planId);

    return (res as List).map((e) => TrainingPlanExercise.fromMap(e)).toList();
  }

  // 🔹 Agregar ejercicios al plan
  Future<void> addExercises(
    String planId,
    List<TrainingPlanExercise> exs,
  ) async {
    final data = exs.map((e) => e.toMap()).toList();
    await _supa.from('training_plan_exercise').insert(data);
  }
}

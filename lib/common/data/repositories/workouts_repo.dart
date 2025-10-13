import 'package:supabase_flutter/supabase_flutter.dart';

class WorkoutsRepo {
  final _supa = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> listWorkouts(String planId) async {
    final res = await _supa
        .from('workout')
        .select('id, day_index, title, notes')
        .eq('plan_id', planId)
        .order('day_index', ascending: true);
    return List<Map<String, dynamic>>.from(res as List);
  }

  Future<List<Map<String, dynamic>>> listWorkoutExercises(
    String workoutId,
  ) async {
    final res = await _supa
        .from('workout_exercise')
        .select('id, exercise_id, ord, reps, rest_sec, exercise(name)')
        .eq('workout_id', workoutId)
        .order('ord', ascending: true);
    return List<Map<String, dynamic>>.from(res as List);
  }

  Future<String> addWorkout(
    String planId,
    int dayIndex, {
    String? title,
    String? notes,
  }) async {
    final inserted = await _supa
        .from('workout')
        .insert({
          'plan_id': planId,
          'day_index': dayIndex,
          'title': title,
          'notes': notes,
        })
        .select('id')
        .single();
    return inserted['id'] as String;
  }

  Future<void> addWorkoutExercise(
    String workoutId,
    Map<String, dynamic> data,
  ) async {
    await _supa.from('workout_exercise').insert({
      'workout_id': workoutId,
      ...data,
    });
  }
}

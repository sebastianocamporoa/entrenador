// lib/common/data/repositories/workout_logs_repo.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class WorkoutLogsRepo {
  final _supa = Supabase.instance.client;

  Future<void> markExerciseDone({
    required String clientId,
    required String workoutId,
    String? workoutExerciseId,
    String? notes,
  }) async {
    await _supa.from('workout_log').insert({
      'client_id': clientId,
      'workout_id': workoutId,
      'workout_exercise_id': workoutExerciseId,
      if (notes != null) 'notes': notes,
    });
  }
}

class TrainingPlanExercise {
  final String id;
  final String planId;
  final String exerciseId;
  final int? sets;
  final int? repetitions; // 🔹 alias más claro que reps
  final int? restSeconds; // 🔹 tiempo de descanso entre series
  final String? notes;
  final int? order;
  final String? exerciseName;

  TrainingPlanExercise({
    required this.id,
    required this.planId,
    required this.exerciseId,
    this.sets,
    this.repetitions,
    this.restSeconds,
    this.notes,
    this.order,
    this.exerciseName,
  });

  factory TrainingPlanExercise.fromMap(Map<String, dynamic> m) {
    return TrainingPlanExercise(
      id: m['id'] ?? '',
      planId: m['plan_id'] ?? '',
      exerciseId: m['exercise_id'] ?? '',
      sets: m['sets'],
      repetitions: m['repetitions'] ?? m['reps'], // compatibilidad vieja
      restSeconds: m['rest_seconds'],
      notes: m['notes'],
      order: m['order'],
      exerciseName: m['exercise'] != null
          ? m['exercise']['name']
          : m['exercise_name'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id.isNotEmpty) 'id': id,
      'plan_id': planId,
      'exercise_id': exerciseId,
      'sets': sets,
      'repetitions': repetitions,
      'rest_seconds': restSeconds,
      'notes': notes,
      'order': order,
    };
  }
}

class TrainingPlanExercise {
  final String id;
  final String planId;
  final String exerciseId;
  final int? repetitions;
  final int? sets;
  final int? restSeconds;
  final String? notes;
  final String? exerciseName;

  TrainingPlanExercise({
    required this.id,
    required this.planId,
    required this.exerciseId,
    this.repetitions,
    this.sets,
    this.restSeconds,
    this.notes,
    this.exerciseName,
  });

  factory TrainingPlanExercise.fromMap(Map<String, dynamic> m) =>
      TrainingPlanExercise(
        id: m['id'],
        planId: m['plan_id'],
        exerciseId: m['exercise_id'],
        repetitions: m['repetitions'],
        sets: m['sets'],
        restSeconds: m['rest_seconds'],
        notes: m['notes'],
        exerciseName: m['exercise']?['name'], // join con exercise.name
      );

  Map<String, dynamic> toMap() => {
    'plan_id': planId,
    'exercise_id': exerciseId,
    'repetitions': repetitions,
    'sets': sets,
    'rest_seconds': restSeconds,
    'notes': notes,
  };
}

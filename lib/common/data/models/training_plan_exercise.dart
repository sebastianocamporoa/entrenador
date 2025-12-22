class TrainingPlanExercise {
  final String id;
  final String planId;
  final String exerciseId;
  final String? exerciseName; // Nombre del ejercicio (traído por join)

  // AHORA ES STRING
  final String repetitions;

  final int sets;
  final int restSeconds;
  final String? notes;

  TrainingPlanExercise({
    required this.id,
    required this.planId,
    required this.exerciseId,
    this.exerciseName,
    required this.repetitions,
    required this.sets,
    required this.restSeconds,
    this.notes,
  });

  factory TrainingPlanExercise.fromMap(Map<String, dynamic> map) {
    return TrainingPlanExercise(
      id: map['id'].toString(),
      planId: map['plan_id'].toString(),
      exerciseId: map['exercise_id'].toString(),
      // Si hacemos join con la tabla exercises:
      exerciseName: map['exercise'] != null ? map['exercise']['name'] : null,

      // --- CORRECCIÓN CLAVE AQUÍ ---
      // Usamos .toString() para que si llega un 12 (int), lo convierta a "12" (String)
      // y no genere el error de tipo.
      repetitions: map['repetitions'].toString(),

      sets: map['sets'] is int
          ? map['sets']
          : int.tryParse(map['sets'].toString()) ?? 0,
      restSeconds: map['rest_seconds'] is int
          ? map['rest_seconds']
          : int.tryParse(map['rest_seconds'].toString()) ?? 0,
      notes: map['notes'],
    );
  }

  Map<String, dynamic> toInsert() {
    return {
      // No enviamos ID si es 'tmp' o dejamos que Supabase lo genere
      if (id != 'tmp') 'id': id,
      'plan_id': planId,
      'exercise_id': exerciseId,
      'repetitions': repetitions, // Ahora envía String
      'sets': sets,
      'rest_seconds': restSeconds,
      'notes': notes,
    };
  }
}

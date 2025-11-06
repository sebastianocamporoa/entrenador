class TrainingPlan {
  final String id;
  final String trainerId;
  final String name;
  final String? goal;
  final String scope;

  TrainingPlan({
    required this.id,
    required this.trainerId,
    required this.name,
    this.goal,
    required this.scope,
  });

  factory TrainingPlan.fromMap(Map<String, dynamic> map) => TrainingPlan(
    id: map['id'] ?? '',
    trainerId: map['trainer_id'] ?? '',
    name: map['name'] ?? '',
    goal: map['goal'],
    scope: map['scope'] ?? 'coach',
  );

  Map<String, dynamic> toInsert() => {
    'trainer_id': trainerId,
    'name': name,
    'goal': goal,
    'scope': scope,
  };
}

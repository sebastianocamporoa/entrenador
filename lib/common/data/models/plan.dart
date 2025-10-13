class Plan {
  final String id;
  final String trainerId;
  final String name;
  final String? goal;
  final String? scope; // 'coach' | 'global' (opcional)

  Plan({
    required this.id,
    required this.trainerId,
    required this.name,
    this.goal,
    this.scope,
  });

  factory Plan.fromMap(Map<String, dynamic> m) => Plan(
    id: m['id'],
    trainerId: m['trainer_id'],
    name: m['name'],
    goal: m['goal'],
    scope: m['scope'],
  );

  Map<String, dynamic> toInsert(String trainerId) => {
    'trainer_id': trainerId,
    'name': name,
    'goal': goal,
    'scope': scope ?? 'coach',
  };
}

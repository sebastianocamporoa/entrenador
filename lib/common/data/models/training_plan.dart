class TrainingPlan {
  final String id;
  final String name;
  final String? description;
  final bool isGlobal;
  final String? trainerId;
  final DateTime? createdAt;

  TrainingPlan({
    required this.id,
    required this.name,
    this.description,
    this.isGlobal = false,
    this.trainerId,
    this.createdAt,
  });

  factory TrainingPlan.fromMap(Map<String, dynamic> m) => TrainingPlan(
    id: m['id'],
    name: m['name'],
    description: m['description'],
    isGlobal: m['is_global'] ?? false,
    trainerId: m['trainer_id'],
    createdAt: m['created_at'] != null ? DateTime.parse(m['created_at']) : null,
  );

  Map<String, dynamic> toInsert({
    required String name,
    String? description,
    bool isGlobal = false,
    String? trainerId,
  }) => {
    'name': name,
    'description': description,
    'is_global': isGlobal,
    'trainer_id': trainerId,
  };
}

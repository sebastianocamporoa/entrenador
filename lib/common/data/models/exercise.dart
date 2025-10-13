class Exercise {
  final String id;
  final String scope; // 'global' | 'coach'
  final String name;
  final String? muscleGroup;
  final String? videoUrl;
  final String? description;

  Exercise({
    required this.id,
    required this.scope,
    required this.name,
    this.muscleGroup,
    this.videoUrl,
    this.description,
  });

  factory Exercise.fromMap(Map<String, dynamic> m) => Exercise(
    id: m['id'],
    scope: m['scope'],
    name: m['name'],
    muscleGroup: m['muscle_group'],
    videoUrl: m['video_url'],
    description: m['description'],
  );

  Map<String, dynamic> toInsert({required String scope}) => {
    'scope': scope,
    'name': name,
    'muscle_group': muscleGroup,
    'video_url': videoUrl,
    'description': description,
  };
}

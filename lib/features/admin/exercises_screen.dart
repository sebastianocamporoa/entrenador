import 'package:flutter/material.dart';
import '../../common/data/models/exercise.dart';
import '../../common/data/repositories/exercises_repo.dart';

class ExercisesScreen extends StatefulWidget {
  const ExercisesScreen({super.key});

  @override
  State<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends State<ExercisesScreen> {
  final _repo = ExercisesRepo();
  late Future<List<Exercise>> _future;

  final List<String> _muscleGroups = const [
    'Pecho',
    'Espalda',
    'Hombros',
    'Bíceps',
    'Tríceps',
    'Piernas',
    'Glúteos',
    'Abdomen',
    'Full Body',
    'Cardio',
    'Movilidad',
    'Otro',
  ];

  @override
  void initState() {
    super.initState();
    _future = _repo.listAllVisible();
  }

  Future<void> _reload() async {
    final future = _repo.listAllVisible(); // ejecutar async fuera de setState
    if (!mounted) return;
    setState(() {
      _future = future; // actualizar el estado de forma síncrona
    });
  }

  Future<void> _showEditDialog([Exercise? exercise]) async {
    final isNew = exercise == null;
    final nameCtrl = TextEditingController(text: exercise?.name ?? '');
    final videoCtrl = TextEditingController(text: exercise?.videoUrl ?? '');
    final descCtrl = TextEditingController(text: exercise?.description ?? '');
    String? selectedGroup = exercise?.muscleGroup;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isNew ? 'Nuevo ejercicio' : 'Editar ejercicio'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Grupo muscular',
                  border: OutlineInputBorder(),
                ),
                value: selectedGroup,
                items: _muscleGroups
                    .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                    .toList(),
                onChanged: (val) => selectedGroup = val,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: videoCtrl,
                decoration: const InputDecoration(labelText: 'URL de video'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Descripción'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty || selectedGroup == null) return;
              Navigator.pop(context, true);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (ok == true) {
      if (isNew) {
        await _repo.addGlobal(
          Exercise(
            id: 'tmp',
            scope: 'global',
            name: nameCtrl.text.trim(),
            muscleGroup: selectedGroup,
            videoUrl: videoCtrl.text.trim().isEmpty
                ? null
                : videoCtrl.text.trim(),
            description: descCtrl.text.trim().isEmpty
                ? null
                : descCtrl.text.trim(),
          ),
        );
      } else {
        await _repo.update(exercise!.id, {
          'name': nameCtrl.text.trim(),
          'muscle_group': selectedGroup,
          'video_url': videoCtrl.text.trim().isEmpty ? null : videoCtrl.text,
          'description': descCtrl.text.trim().isEmpty ? null : descCtrl.text,
        });
      }
      await _reload(); // recarga automáticamente
    }
  }

  Future<void> _removeExercise(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar ejercicio'),
        content: const Text('¿Seguro que deseas eliminar este ejercicio?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _repo.remove(id);
      await _reload(); // recarga automáticamente
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ejercicios Globales')),
      body: FutureBuilder<List<Exercise>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }

          final exercises = snap.data ?? [];
          if (exercises.isEmpty) {
            return const Center(child: Text('No hay ejercicios aún.'));
          }

          final grouped = <String, List<Exercise>>{};
          for (var e in exercises) {
            final group = e.muscleGroup ?? 'Otro';
            grouped.putIfAbsent(group, () => []).add(e);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: grouped.keys.length,
            itemBuilder: (context, index) {
              final group = grouped.keys.elementAt(index);
              final groupExercises = grouped[group]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 4,
                    ),
                    child: Text(
                      group.toUpperCase(),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 160,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: groupExercises.length,
                      itemBuilder: (context, i) {
                        final e = groupExercises[i];
                        return GestureDetector(
                          onTap: () => _showEditDialog(e),
                          onLongPress: () => _removeExercise(e.id),
                          child: Container(
                            width: 160,
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.indigo.shade50,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 4,
                                  offset: const Offset(2, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.fitness_center,
                                  color: Colors.indigo,
                                  size: 26,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  e.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                const Spacer(),
                                if (e.videoUrl != null &&
                                    e.videoUrl!.isNotEmpty)
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.play_circle_fill,
                                        color: Colors.indigo.shade400,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      const Text(
                                        'Video',
                                        style: TextStyle(
                                          color: Colors.indigo,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

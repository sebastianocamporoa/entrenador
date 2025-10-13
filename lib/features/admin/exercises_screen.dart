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

  @override
  void initState() {
    super.initState();
    _future = _repo.listAllVisible();
  }

  Future<void> _reload() async {
    setState(() {
      _future = _repo.listAllVisible();
    });
  }

  Future<void> _showAddDialog() async {
    final nameCtrl = TextEditingController();
    final muscleCtrl = TextEditingController();
    final videoCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nuevo ejercicio (GLOBAL)'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              TextField(
                controller: muscleCtrl,
                decoration: const InputDecoration(labelText: 'Grupo muscular'),
              ),
              TextField(
                controller: videoCtrl,
                decoration: const InputDecoration(
                  labelText: 'URL de video (opcional)',
                ),
              ),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Descripción'),
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
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (ok == true) {
      final e = Exercise(
        id: 'tmp',
        scope: 'global',
        name: nameCtrl.text.trim(),
        muscleGroup: muscleCtrl.text.trim().isEmpty
            ? null
            : muscleCtrl.text.trim(),
        videoUrl: videoCtrl.text.trim().isEmpty ? null : videoCtrl.text.trim(),
        description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
      );
      await _repo.addGlobal(e);
      await _reload();
    }
  }

  Future<void> _remove(String id) async {
    await _repo.remove(id);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ejercicios Globales'),
        actions: [
          IconButton(onPressed: _showAddDialog, icon: const Icon(Icons.add)),
        ],
      ),
      body: FutureBuilder<List<Exercise>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final items = snap.data ?? [];
          if (items.isEmpty) {
            return const Center(child: Text('No hay ejercicios aún.'));
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 0),
            itemBuilder: (_, i) {
              final e = items[i];
              return ListTile(
                title: Text(e.name),
                subtitle: Text(
                  [
                    'scope: ${e.scope}',
                    if (e.muscleGroup != null && e.muscleGroup!.isNotEmpty)
                      'grupo: ${e.muscleGroup}',
                    if (e.videoUrl != null && e.videoUrl!.isNotEmpty)
                      'video: ${e.videoUrl}',
                  ].join('  ·  '),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _remove(e.id),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

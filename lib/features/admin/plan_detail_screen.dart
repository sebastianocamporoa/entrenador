import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../common/data/models/training_plan.dart';
import '../../common/data/models/training_plan_exercise.dart';
import '../../common/data/models/exercise.dart';
import '../../common/data/repositories/plans_repo.dart';
import '../../common/data/repositories/exercises_repo.dart';

class PlanDetailScreen extends StatefulWidget {
  final TrainingPlan plan;
  const PlanDetailScreen({super.key, required this.plan});

  @override
  State<PlanDetailScreen> createState() => _PlanDetailScreenState();
}

class _PlanDetailScreenState extends State<PlanDetailScreen> {
  final _repo = PlansRepo();
  final _exRepo = ExercisesRepo();
  late Future<List<TrainingPlanExercise>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.getExercises(widget.plan.id);
  }

  Future<void> _reload() async {
    final newFuture = _repo.getExercises(widget.plan.id); // ejecuta async fuera
    if (!mounted) return;
    setState(() {
      _future = newFuture; // actualiza sin async dentro
    });
  }

  Future<void> _addExercise() async {
    final allExercises = await _exRepo.listAllVisible();

    // Agrupamos los ejercicios por grupo muscular
    final grouped = <String, List<Exercise>>{};
    for (final ex in allExercises) {
      final key = ex.muscleGroup?.toUpperCase() ?? 'OTROS';
      grouped.putIfAbsent(key, () => []).add(ex);
    }

    final selected = await showDialog<Exercise>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Seleccionar ejercicio'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: grouped.entries.map((entry) {
                final groupName = entry.key;
                final exercises = entry.value;

                return ExpansionTile(
                  title: Text(
                    groupName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  children: exercises
                      .map(
                        (e) => ListTile(
                          title: Text(e.name),
                          subtitle: e.videoUrl != null
                              ? Text(
                                  e.videoUrl!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.blueGrey,
                                  ),
                                )
                              : null,
                          onTap: () => Navigator.pop(context, e),
                        ),
                      )
                      .toList(),
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );

    if (selected == null) return;

    final repsCtrl = TextEditingController();
    final setsCtrl = TextEditingController();
    final restCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Configurar ${selected.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: repsCtrl,
              decoration: const InputDecoration(labelText: 'Repeticiones'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: setsCtrl,
              decoration: const InputDecoration(labelText: 'Series'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: restCtrl,
              decoration: const InputDecoration(
                labelText: 'Descanso (segundos)',
              ),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(labelText: 'Notas'),
            ),
          ],
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
      final ex = TrainingPlanExercise(
        id: 'tmp',
        planId: widget.plan.id,
        exerciseId: selected.id,
        repetitions: int.tryParse(repsCtrl.text) ?? 0,
        sets: int.tryParse(setsCtrl.text) ?? 0,
        restSeconds: int.tryParse(restCtrl.text) ?? 0,
        notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
      );
      await _repo.addExercises(widget.plan.id, [ex]);
      _reload();
    }
  }

  Future<void> _removeExercise(String id) async {
    await Supabase.instance.client
        .from('training_plan_exercise')
        .delete()
        .eq('id', id);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.plan.name),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _addExercise),
        ],
      ),
      body: FutureBuilder<List<TrainingPlanExercise>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());
          final items = snap.data!;
          if (items.isEmpty)
            return const Center(child: Text('No hay ejercicios en este plan.'));

          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 0),
            itemBuilder: (_, i) {
              final e = items[i];
              return ListTile(
                title: Text(e.exerciseName ?? 'Ejercicio'),
                subtitle: Text(
                  'Series: ${e.sets} · Reps: ${e.repetitions} · Descanso: ${e.restSeconds}s',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _removeExercise(e.id),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

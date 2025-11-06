import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
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
    setState(() => _future = _repo.getExercises(widget.plan.id));
  }

  Future<void> _addExercise() async {
    final allExercises = await _exRepo.listAllVisible();
    final selected = await showDialog<Exercise>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Seleccionar ejercicio'),
        children: allExercises
            .map(
              (e) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, e),
                child: Text(e.name),
              ),
            )
            .toList(),
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
              decoration: const InputDecoration(labelText: 'Descanso (seg)'),
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
        repetitions: int.tryParse(
          repsCtrl.text.trim().isEmpty ? '0' : repsCtrl.text,
        ),
        sets: int.tryParse(setsCtrl.text.trim().isEmpty ? '0' : setsCtrl.text),
        restSeconds: int.tryParse(
          restCtrl.text.trim().isEmpty ? '0' : restCtrl.text,
        ),
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
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data!;
          if (items.isEmpty) {
            return const Center(child: Text('No hay ejercicios en este plan.'));
          }

          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 0),
            itemBuilder: (_, i) {
              final e = items[i];
              return ListTile(
                title: Text('Ejercicio: ${e.exerciseId}'),
                subtitle: Text(
                  'Series: ${e.sets ?? '-'} · Reps: ${e.repetitions ?? '-'} · Descanso: ${e.restSeconds ?? '-'}s',
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

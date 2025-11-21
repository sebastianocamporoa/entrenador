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
    final newFuture = _repo.getExercises(widget.plan.id);
    if (!mounted) return;
    setState(() {
      _future = newFuture;
    });
  }

  Future<void> _addExercise() async {
    const background = Color(0xFF1C1C1E);
    const accent = Color(0xFFBF5AF2);
    const textColor = Color(0xFFD9D9D9);

    final allExercises = await _exRepo.listAllVisible();

    // 🔹 Agrupamos ejercicios por grupo muscular
    final grouped = <String, List<Exercise>>{};
    for (final ex in allExercises) {
      final key = ex.muscleGroup?.toUpperCase() ?? 'OTROS';
      grouped.putIfAbsent(key, () => []).add(ex);
    }

    final selected = await showDialog<Exercise>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Seleccionar ejercicio',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: Column(
              children: grouped.entries.map((entry) {
                final group = entry.key;
                final exercises = entry.value;
                return Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor: Colors.transparent,
                    listTileTheme: const ListTileThemeData(
                      iconColor: textColor,
                    ),
                  ),
                  child: ExpansionTile(
                    collapsedIconColor: Colors.white70,
                    iconColor: accent,
                    title: Text(
                      group,
                      style: const TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    children: exercises
                        .map(
                          (e) => ListTile(
                            title: Text(
                              e.name,
                              style: const TextStyle(color: textColor),
                            ),
                            subtitle: e.videoUrl != null
                                ? Text(
                                    e.videoUrl!,
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 12,
                                    ),
                                  )
                                : null,
                            onTap: () => Navigator.pop(context, e),
                          ),
                        )
                        .toList(),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );

    if (selected == null) return;

    // 🔹 Diálogo de configuración del ejercicio
    final repsCtrl = TextEditingController();
    final setsCtrl = TextEditingController();
    final restCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Configurar ${selected.name}',
          style: const TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: repsCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: textColor),
              decoration: const InputDecoration(
                labelText: 'Repeticiones',
                labelStyle: TextStyle(color: Colors.white70),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: accent),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: setsCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: textColor),
              decoration: const InputDecoration(
                labelText: 'Series',
                labelStyle: TextStyle(color: Colors.white70),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: accent),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: restCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: textColor),
              decoration: const InputDecoration(
                labelText: 'Descanso (segundos)',
                labelStyle: TextStyle(color: Colors.white70),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: accent),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: notesCtrl,
              style: const TextStyle(color: textColor),
              decoration: const InputDecoration(
                labelText: 'Notas',
                labelStyle: TextStyle(color: Colors.white70),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: accent),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: accent),
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2E),
        title: const Text(
          'Eliminar ejercicio',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          '¿Deseas eliminar este ejercicio del plan?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await Supabase.instance.client
          .from('training_plan_exercise')
          .delete()
          .eq('id', id);
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFF1C1C1E);
    const cardColor = Color(0xFF2C2C2E);
    const accent = Color(0xFFBF5AF2);
    const textColor = Color(0xFFD9D9D9);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        title: Text(
          widget.plan.name,
          style: const TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        iconTheme: const IconThemeData(color: textColor),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: accent),
            onPressed: _addExercise,
          ),
        ],
      ),
      body: FutureBuilder<List<TrainingPlanExercise>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: accent),
            );
          }
          if (snap.hasError) {
            return Center(
              child: Text(
                'Error: ${snap.error}',
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }

          final items = snap.data ?? [];
          if (items.isEmpty) {
            return const Center(
              child: Text(
                'No hay ejercicios en este plan.',
                style: TextStyle(color: textColor, fontSize: 16),
              ),
            );
          }

          return RefreshIndicator(
            color: accent,
            onRefresh: _reload,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (_, i) {
                final e = items[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: ListTile(
                    title: Text(
                      e.exerciseName ?? 'Ejercicio',
                      style: const TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'Series: ${e.sets} · Reps: ${e.repetitions} · Descanso: ${e.restSeconds}s',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                      ),
                      onPressed: () => _removeExercise(e.id),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

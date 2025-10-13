import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../common/data/repositories/workouts_repo.dart';

class PlanEditorScreen extends StatefulWidget {
  final String planId;
  final String planName;
  const PlanEditorScreen({
    super.key,
    required this.planId,
    required this.planName,
  });

  @override
  State<PlanEditorScreen> createState() => _PlanEditorScreenState();
}

class _PlanEditorScreenState extends State<PlanEditorScreen> {
  final _repo = WorkoutsRepo();
  late Future<List<Map<String, dynamic>>> _futureWorkouts;

  @override
  void initState() {
    super.initState();
    _futureWorkouts = _repo.listWorkouts(widget.planId);
  }

  Future<void> _reload() async {
    setState(() => _futureWorkouts = _repo.listWorkouts(widget.planId));
  }

  Future<void> _addWorkoutDialog() async {
    final dayCtrl = TextEditingController(text: '0'); // 0..6 si usas day_index
    final titleCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nuevo workout'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: dayCtrl,
              decoration: const InputDecoration(labelText: 'Día (0..6)'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Título'),
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
      await _repo.addWorkout(
        widget.planId,
        int.tryParse(dayCtrl.text.trim()) ?? 0,
        title: titleCtrl.text.trim(),
        notes: notesCtrl.text.trim(),
      );
      await _reload();
    }
  }

  Future<void> _addExerciseDialog(String workoutId) async {
    final supa = Supabase.instance.client;
    // Trae ejercicios visibles (global + del coach por RLS)
    final ex = await supa.from('exercise').select('id, name').order('name');
    final List<Map<String, dynamic>> list = List<Map<String, dynamic>>.from(
      ex as List,
    );
    String? selectedId;
    final repsCtrl = TextEditingController();
    final restCtrl = TextEditingController(); // opcional si creaste rest_sec
    final ordCtrl = TextEditingController(text: '0');

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Agregar ejercicio'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedId,
                items: list
                    .map(
                      (m) => DropdownMenuItem(
                        value: m['id'] as String,
                        child: Text(m['name'] as String),
                      ),
                    )
                    .toList(),
                onChanged: (v) => selectedId = v,
                decoration: const InputDecoration(labelText: 'Ejercicio'),
              ),
              TextField(
                controller: repsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Reps (ej. 12 o 12-10-8)',
                ),
              ),
              TextField(
                controller: restCtrl,
                decoration: const InputDecoration(
                  labelText: 'Descanso (segundos, opcional)',
                ),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: ordCtrl,
                decoration: const InputDecoration(labelText: 'Orden (0..N)'),
                keyboardType: TextInputType.number,
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
            child: const Text('Agregar'),
          ),
        ],
      ),
    );

    if (ok == true && selectedId != null) {
      await _repo.addWorkoutExercise(workoutId, {
        'exercise_id': selectedId,
        'reps': repsCtrl.text.trim().isEmpty ? null : repsCtrl.text.trim(),
        'rest_sec': int.tryParse(restCtrl.text.trim()),
        'ord': int.tryParse(ordCtrl.text.trim()) ?? 0,
      });
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Editar plan: ${widget.planName}'),
        actions: [
          IconButton(onPressed: _addWorkoutDialog, icon: const Icon(Icons.add)),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _futureWorkouts,
        builder: (_, snap) {
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());
          final workouts = snap.data!;
          if (workouts.isEmpty)
            return const Center(
              child: Text('Aún no hay workouts. Crea uno con +'),
            );
          return ListView.separated(
            itemBuilder: (_, i) {
              final w = workouts[i];
              return ExpansionTile(
                title: Text(
                  'Día ${w['day_index'] ?? '-'} — ${w['title'] ?? '(sin título)'}',
                ),
                subtitle: Text(w['notes'] ?? ''),
                children: [
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _repo.listWorkoutExercises(w['id'] as String),
                    builder: (_, snapEx) {
                      if (!snapEx.hasData)
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        );
                      final exs = snapEx.data!;
                      if (exs.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: TextButton.icon(
                            onPressed: () =>
                                _addExerciseDialog(w['id'] as String),
                            icon: const Icon(Icons.add),
                            label: const Text('Agregar ejercicio'),
                          ),
                        );
                      }
                      return Column(
                        children: [
                          ...exs.map(
                            (e) => ListTile(
                              leading: Text((e['ord'] ?? 0).toString()),
                              title: Text(e['exercise']['name'] ?? 'Ejercicio'),
                              subtitle: Text(
                                [
                                  if (e['reps'] != null) 'Reps: ${e['reps']}',
                                  if (e['rest_sec'] != null)
                                    'Descanso: ${e['rest_sec']}s',
                                ].join('  ·  '),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: TextButton.icon(
                              onPressed: () =>
                                  _addExerciseDialog(w['id'] as String),
                              icon: const Icon(Icons.add),
                              label: const Text('Agregar otro ejercicio'),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              );
            },
            separatorBuilder: (_, __) => const Divider(height: 0),
            itemCount: workouts.length,
          );
        },
      ),
    );
  }
}

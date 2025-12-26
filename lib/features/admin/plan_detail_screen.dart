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

  // --- AGREGAR NUEVO EJERCICIO ---
  Future<void> _addExercise() async {
    const background = Color(0xFF1C1C1E);
    const accent = Color(0xFFBF5AF2);
    const textColor = Color(0xFFD9D9D9);

    final allExercises = await _exRepo.listAllVisible();
    final grouped = <String, List<Exercise>>{};
    for (final ex in allExercises) {
      final key = ex.muscleGroup?.toUpperCase() ?? 'OTROS';
      grouped.putIfAbsent(key, () => []).add(ex);
    }

    // 1. Seleccionar Ejercicio
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
                    children: entry.value
                        .map(
                          (e) => ListTile(
                            title: Text(
                              e.name,
                              style: const TextStyle(color: textColor),
                            ),
                            subtitle: e.videoUrl != null
                                ? Text(
                                    'Con video',
                                    style: TextStyle(
                                      color: accent.withOpacity(0.7),
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

    // 2. Configurar (Reutilizamos la lógica, pero iniciamos vacíos)
    _showConfigDialog(
      exerciseName: selected.name,
      onSave: (sets, repsString, rest, notes) async {
        final ex = TrainingPlanExercise(
          id: 'tmp',
          planId: widget.plan.id,
          exerciseId: selected.id,
          repetitions: repsString,
          sets: sets,
          restSeconds: rest,
          notes: notes,
        );
        await _repo.addExercises(widget.plan.id, [ex]);
        _reload();
      },
    );
  }

  // --- EDITAR EJERCICIO EXISTENTE ---
  Future<void> _editExercise(TrainingPlanExercise exercise) async {
    // Parseamos las repeticiones existentes para pre-llenar
    // Si guardaste "12", y son 3 series -> ["12", "12", "12"]
    // Si guardaste "12/10/8" -> ["12", "10", "8"]

    List<String> initialReps = exercise.repetitions.split('-');
    if (initialReps.length == 1 && exercise.sets > 1) {
      initialReps = List.filled(exercise.sets, initialReps[0]);
    }

    _showConfigDialog(
      exerciseName: exercise.exerciseName ?? 'Ejercicio',
      initialSets: exercise.sets,
      initialRest: exercise.restSeconds,
      initialNotes: exercise.notes,
      initialReps: initialReps,
      isEditing: true,
      onSave: (sets, repsString, rest, notes) async {
        // Creamos una instancia con los nuevos datos pero EL MISMO ID
        final updated = TrainingPlanExercise(
          id: exercise.id, // ID original importante para el update
          planId: exercise.planId,
          exerciseId: exercise.exerciseId,
          repetitions: repsString,
          sets: sets,
          restSeconds: rest,
          notes: notes,
        );

        await _repo.updateExercise(updated); // Método nuevo en el repo
        _reload();
      },
    );
  }

  // --- DIÁLOGO REUTILIZABLE (SIRVE PARA AGREGAR Y EDITAR) ---
  Future<void> _showConfigDialog({
    required String exerciseName,
    required Function(int sets, String reps, int rest, String? notes) onSave,
    int initialSets = 3,
    int initialRest = 60,
    String? initialNotes,
    List<String>? initialReps,
    bool isEditing = false,
  }) async {
    const background = Color(0xFF1C1C1E);
    const accent = Color(0xFFBF5AF2);
    const textColor = Color(0xFFD9D9D9);

    int numberOfSets = initialSets;

    // Inicializamos controladores de reps
    List<TextEditingController> repControllers = List.generate(numberOfSets, (
      index,
    ) {
      String text = '';
      if (initialReps != null && index < initialReps.length) {
        text = initialReps[index];
      }
      return TextEditingController(text: text);
    });

    final setsCtrl = TextEditingController(text: initialSets.toString());
    final restCtrl = TextEditingController(text: initialRest.toString());
    final notesCtrl = TextEditingController(text: initialNotes ?? '');

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: background,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                isEditing ? 'Editar $exerciseName' : 'Configurar $exerciseName',
                style: const TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: setsCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: textColor),
                      decoration: const InputDecoration(
                        labelText: 'Número de Series',
                        labelStyle: TextStyle(color: Colors.white70),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: accent),
                        ),
                      ),
                      onChanged: (val) {
                        final n = int.tryParse(val);
                        if (n != null && n > 0 && n <= 10) {
                          setStateDialog(() {
                            numberOfSets = n;
                            final oldValues = repControllers
                                .map((c) => c.text)
                                .toList();
                            repControllers = List.generate(n, (index) {
                              final txt = index < oldValues.length
                                  ? oldValues[index]
                                  : (oldValues.isNotEmpty
                                        ? oldValues.last
                                        : '');
                              return TextEditingController(text: txt);
                            });
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Repeticiones por serie:",
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(numberOfSets, (index) {
                        return SizedBox(
                          width: 70,
                          child: TextField(
                            controller: repControllers[index],
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: InputDecoration(
                              labelText: 'S${index + 1}',
                              labelStyle: const TextStyle(
                                color: accent,
                                fontSize: 12,
                              ),
                              filled: true,
                              fillColor: Colors.white10,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 4,
                                horizontal: 8,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
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
                        labelText: 'Notas (RIR, Tempo, etc.)',
                        labelStyle: TextStyle(color: Colors.white70),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: accent),
                        ),
                      ),
                    ),
                  ],
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
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: accent),
                  onPressed: () {
                    bool hasEmpty = repControllers.any(
                      (c) => c.text.trim().isEmpty,
                    );
                    if (hasEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Por favor llena todas las series'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                      return;
                    }

                    Navigator.pop(context); // Cerrar dialog

                    // Lógica de string de reps
                    final vals = repControllers
                        .map((c) => c.text.trim())
                        .toList();
                    final allEqual = vals.every((v) => v == vals[0]);
                    final repsStr = allEqual ? vals[0] : vals.join('-');

                    onSave(
                      int.tryParse(setsCtrl.text) ?? 0,
                      repsStr,
                      int.tryParse(restCtrl.text) ?? 0,
                      notesCtrl.text.trim().isEmpty
                          ? null
                          : notesCtrl.text.trim(),
                    );
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
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
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    // Tocar para EDITAR
                    onTap: () => _editExercise(e),
                    title: Text(
                      e.exerciseName ?? 'Ejercicio',
                      style: const TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          _BadgeInfo(
                            icon: Icons.repeat,
                            text: '${e.sets} Series',
                          ),
                          const SizedBox(width: 12),
                          _BadgeInfo(
                            icon: Icons.fitness_center,
                            text: e.repetitions,
                          ),
                          const SizedBox(width: 12),
                          _BadgeInfo(
                            icon: Icons.timer,
                            text: '${e.restSeconds}s',
                          ),
                        ],
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

class _BadgeInfo extends StatelessWidget {
  final IconData icon;
  final String text;
  const _BadgeInfo({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFFBF5AF2)),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13)),
      ],
    );
  }
}

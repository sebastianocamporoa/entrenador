import 'package:flutter/material.dart';
import '../../common/data/models/exercise.dart';
import '../../common/data/repositories/exercises_repo.dart';

class ExercisesScreen extends StatefulWidget {
  final bool isCoachMode; // true = Entrenador, false = Admin

  const ExercisesScreen({super.key, this.isCoachMode = false});

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
    final future = _repo.listAllVisible();
    if (!mounted) return;
    setState(() {
      _future = future;
    });
  }

  // --- DIÁLOGO DE EDICIÓN / CREACIÓN ---
  Future<void> _showEditDialog([Exercise? exercise]) async {
    // 1. Verificamos permisos de EDICIÓN antes de abrir
    if (widget.isCoachMode && exercise != null && exercise.scope == 'global') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este es un ejercicio Global. Solo lectura.'),
          backgroundColor: Colors.orange,
        ),
      );
      // Podrías retornar aquí si no quieres que ni siquiera abran el dialog,
      // pero a veces es útil abrirlo para ver la info completa aunque no editen.
      // Por ahora dejaremos que lo abran pero ocultaremos el botón de guardar si quieres ser estricto,
      // o simplemente dejamos que lo vean.
    }

    final isNew = exercise == null;
    final nameCtrl = TextEditingController(text: exercise?.name ?? '');
    final videoCtrl = TextEditingController(text: exercise?.videoUrl ?? '');
    final descCtrl = TextEditingController(text: exercise?.description ?? '');
    String? selectedGroup = exercise?.muscleGroup;

    // Determinamos si es "Solo Lectura" para la UI
    final isReadOnly =
        widget.isCoachMode && !isNew && exercise?.scope == 'global';

    final result = await showDialog<String>(
      // Retorna 'save', 'delete' o null
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2E),
        title: Text(
          isNew
              ? 'Nuevo ejercicio'
              : (isReadOnly ? 'Detalles' : 'Editar ejercicio'),
          style: const TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(nameCtrl, 'Nombre', readOnly: isReadOnly),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                dropdownColor: const Color(0xFF2C2C2E),
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Grupo muscular'),
                value: selectedGroup,
                items: _muscleGroups
                    .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                    .toList(),
                onChanged: isReadOnly ? null : (val) => selectedGroup = val,
              ),
              const SizedBox(height: 12),
              _buildTextField(videoCtrl, 'URL de video', readOnly: isReadOnly),
              const SizedBox(height: 12),
              _buildTextField(
                descCtrl,
                'Descripción',
                maxLines: 3,
                readOnly: isReadOnly,
              ),
            ],
          ),
        ),
        actions: [
          // BOTÓN ELIMINAR (Solo si no es nuevo y tengo permisos)
          if (!isNew && !isReadOnly)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              tooltip: 'Eliminar ejercicio',
              onPressed: () {
                Navigator.pop(
                  context,
                  'delete',
                ); // Cerramos dialog devolviendo 'delete'
              },
            ),

          // Espaciador para empujar botones a la derecha
          if (!isNew && !isReadOnly) const SizedBox(width: 8),

          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.white54),
            ),
          ),

          // BOTÓN GUARDAR (Oculto si es solo lectura)
          if (!isReadOnly)
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFBF5AF2),
              ),
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty || selectedGroup == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Nombre y Grupo son obligatorios'),
                    ),
                  );
                  return;
                }
                Navigator.pop(context, 'save'); // Devolvemos 'save'
              },
              child: const Text('Guardar'),
            ),
        ],
      ),
    );

    // --- PROCESAR RESULTADO DEL DIÁLOGO ---
    if (result == 'delete' && exercise != null) {
      // Llamamos a la función de borrado
      _confirmAndRemove(exercise);
    } else if (result == 'save') {
      // Guardar o Actualizar
      if (isNew) {
        final newExercise = Exercise(
          id: 'tmp',
          scope: widget.isCoachMode ? 'coach' : 'global',
          name: nameCtrl.text.trim(),
          muscleGroup: selectedGroup,
          videoUrl: videoCtrl.text.trim().isEmpty
              ? null
              : videoCtrl.text.trim(),
          description: descCtrl.text.trim().isEmpty
              ? null
              : descCtrl.text.trim(),
        );

        if (widget.isCoachMode) {
          await _repo.addCoach(newExercise);
        } else {
          await _repo.addGlobal(newExercise);
        }
      } else {
        await _repo.update(exercise!.id, {
          'name': nameCtrl.text.trim(),
          'muscle_group': selectedGroup,
          'video_url': videoCtrl.text.trim().isEmpty ? null : videoCtrl.text,
          'description': descCtrl.text.trim().isEmpty ? null : descCtrl.text,
        });
      }
      await _reload();
    }
  }

  // --- FUNCIÓN DE BORRADO ---
  Future<void> _confirmAndRemove(Exercise exercise) async {
    // Doble verificación de seguridad
    if (widget.isCoachMode && exercise.scope == 'global') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No tienes permiso para borrar ejercicios globales'),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2E),
        title: const Text(
          '¿Eliminar ejercicio?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Se eliminará "${exercise.name}" permanentemente.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.white54),
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
      await _repo.remove(exercise.id);
      await _reload();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Ejercicio eliminado')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1C1E),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.isCoachMode ? 'Mis Ejercicios' : 'Ejercicios Globales',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: FutureBuilder<List<Exercise>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFBF5AF2)),
            );
          }
          if (snap.hasError) {
            return Center(
              child: Text(
                'Error: ${snap.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final exercises = snap.data ?? [];
          if (exercises.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.fitness_center,
                    size: 60,
                    color: Colors.white24,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hay ejercicios disponibles.',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                ],
              ),
            );
          }

          // Agrupar por grupo muscular
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
                      style: const TextStyle(
                        color: Color(0xFFBF5AF2),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 170, // Altura de la tarjeta
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: groupExercises.length,
                      itemBuilder: (context, i) {
                        final e = groupExercises[i];

                        // Lógica visual
                        final isGlobal = e.scope == 'global';
                        final isReadOnly = widget.isCoachMode && isGlobal;

                        return GestureDetector(
                          onTap: () => _showEditDialog(e),
                          // Mantenemos onLongPress como atajo
                          onLongPress: isReadOnly
                              ? null
                              : () => _confirmAndRemove(e),
                          child: Container(
                            width: 160,
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isReadOnly
                                  ? const Color(0xFF2C2C2E)
                                  : const Color(0xFFBF5AF2).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isReadOnly
                                    ? Colors.white10
                                    : const Color(0xFFBF5AF2).withOpacity(0.5),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Icon(
                                      Icons.fitness_center,
                                      color: isReadOnly
                                          ? Colors.white24
                                          : const Color(0xFFBF5AF2),
                                      size: 24,
                                    ),
                                    if (isGlobal && widget.isCoachMode)
                                      const Icon(
                                        Icons.public,
                                        size: 16,
                                        color: Colors.white24,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  e.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: isReadOnly
                                        ? Colors.white70
                                        : Colors.white,
                                  ),
                                ),
                                const Spacer(),
                                if (e.videoUrl != null &&
                                    e.videoUrl!.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black38,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.play_arrow,
                                          color: isReadOnly
                                              ? Colors.white54
                                              : const Color(0xFFBF5AF2),
                                          size: 14,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Video',
                                          style: TextStyle(
                                            color: isReadOnly
                                                ? Colors.white54
                                                : const Color(0xFFBF5AF2),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFBF5AF2),
        onPressed: () => _showEditDialog(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // Helper para inputs
  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    bool readOnly = false,
  }) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration(label),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54),
      filled: true,
      fillColor: Colors.black12,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFBF5AF2)),
      ),
    );
  }
}

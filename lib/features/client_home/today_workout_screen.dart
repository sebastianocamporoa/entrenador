import 'dart:async';
import 'package:flutter/material.dart';
import '../../common/data/repositories/assignments_repo.dart';

class TodayWorkoutScreen extends StatefulWidget {
  const TodayWorkoutScreen({super.key});

  @override
  State<TodayWorkoutScreen> createState() => _TodayWorkoutScreenState();
}

class _TodayWorkoutScreenState extends State<TodayWorkoutScreen> {
  final _repo = AssignmentsRepo();
  late Future<List<Map<String, dynamic>>> _future;

  // Variables para el Cronómetro (Timer)
  Timer? _timer;
  int _remainingSeconds = 0;
  bool _isTimerActive = false;

  @override
  void initState() {
    super.initState();
    _future = _repo.todayWorkoutForClient();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // Lógica del Cronómetro
  void _startRestTimer(int seconds) {
    _timer?.cancel();
    setState(() {
      _remainingSeconds = seconds;
      _isTimerActive = true;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _stopTimer();
        // Opcional: Aquí podrías reproducir un sonido o vibración
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Descanso terminado! A darle duro.')),
        );
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() {
      _isTimerActive = false;
      _remainingSeconds = 0;
    });
  }

  void _addTime(int seconds) {
    setState(() {
      _remainingSeconds += seconds;
    });
  }

  String _formatTime(int totalSeconds) {
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Entrenamiento de hoy')),
      // Usamos Column para poner el timer abajo si está activo
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (_, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }

                final items = snap.data ?? [];

                if (items.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text(
                        'Tu entrenador aún no ha configurado los ejercicios de esta sesión.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(
                    bottom: 100,
                  ), // Espacio para el timer
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final exercise = items[i];
                    return _buildExerciseCard(exercise);
                  },
                );
              },
            ),
          ),

          // Widget del Cronómetro (solo se muestra si está activo)
          if (_isTimerActive) _buildTimerPanel(),
        ],
      ),
    );
  }

  // --- Widgets Auxiliares ---

  Widget _buildExerciseCard(Map<String, dynamic> data) {
    // Mapeo de datos basado en tu Schema SQL
    // Nota: Asegúrate de que tu repo devuelva estas keys. Si usa otras, ajustalas aquí.
    final name =
        data['name'] ?? data['exercise_name'] ?? 'Ejercicio sin nombre';
    final muscleGroup = data['muscle_group'] ?? 'General';
    final notes = data['notes'];
    final sets = data['sets'] ?? 0;
    final reps = data['repetitions'] ?? data['presc_reps'] ?? 0;
    final restSeconds = data['rest_seconds'] ?? 60; // Default 60s
    final videoUrl = data['video_url'];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Nombre y Grupo Muscular
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        muscleGroup,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                if (videoUrl != null && videoUrl.toString().isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.play_circle_fill, color: Colors.red),
                    onPressed: () {
                      // AQUÍ IMPLEMENTARÍAS URL_LAUNCHER
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Abrir video: $videoUrl')),
                      );
                    },
                  ),
              ],
            ),
            const Divider(),

            // Detalles: Series, Reps
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildInfoChip(Icons.repeat, '$sets Series'),
                _buildInfoChip(Icons.fitness_center, '$reps Reps'),
                // Botón para iniciar descanso
                ElevatedButton.icon(
                  onPressed: () => _startRestTimer(restSeconds),
                  icon: const Icon(Icons.timer, size: 18),
                  label: Text('${restSeconds}s'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                  ),
                ),
              ],
            ),

            // Notas si existen
            if (notes != null && notes.toString().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Nota: $notes',
                  style: TextStyle(fontSize: 13, color: Colors.brown[800]),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[700]),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ],
    );
  }

  Widget _buildTimerPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.black87,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'DESCANSO',
            style: TextStyle(
              color: Colors.white70,
              letterSpacing: 1.5,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatTime(_remainingSeconds),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace', // Para que los números no salten
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () => _addTime(-10),
                icon: const Icon(
                  Icons.remove_circle_outline,
                  color: Colors.white54,
                ),
                tooltip: '-10s',
              ),
              const SizedBox(width: 16),
              FilledButton.icon(
                onPressed: _stopTimer,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
                icon: const Icon(Icons.stop),
                label: const Text('Detener'),
              ),
              const SizedBox(width: 16),
              IconButton(
                onPressed: () => _addTime(10),
                icon: const Icon(
                  Icons.add_circle_outline,
                  color: Colors.white54,
                ),
                tooltip: '+10s',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

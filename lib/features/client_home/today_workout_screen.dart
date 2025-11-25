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

  @override
  void initState() {
    super.initState();
    _future = _repo.todayWorkoutForClient();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Entrenamiento de hoy')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
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
              child: Text(
                'Tu entrenador aún no ha iniciado tu entrenamiento de hoy.',
                textAlign: TextAlign.center,
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemBuilder: (_, i) {
              final it = items[i];
              final parts = <String>[];
              if (it['presc_reps'] != null)
                parts.add('Reps: ${it['presc_reps']}');
              final subtitle = parts.isEmpty ? '' : parts.join(' · ');
              return ListTile(
                title: Text(it['exercise_name'] ?? 'Ejercicio'),
                subtitle: Text(subtitle),
              );
            },
            separatorBuilder: (_, __) => const Divider(height: 0),
            itemCount: items.length,
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../common/data/repositories/plans_repo.dart';
import '../../common/data/models/training_plan.dart';
import '../admin/plan_detail_screen.dart';

class PlansListScreen extends StatefulWidget {
  const PlansListScreen({super.key});

  @override
  State<PlansListScreen> createState() => _PlansListScreenState();
}

class _PlansListScreenState extends State<PlansListScreen> {
  final _repo = PlansRepo();
  late Future<List<TrainingPlan>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.listGlobalPlans();
  }

  Future<void> _reload() async {
    final newFuture = _repo.listGlobalPlans();
    if (!mounted) return;
    setState(() {
      _future = newFuture;
    });
  }

  Future<void> _addPlanDialog() async {
    final nameCtrl = TextEditingController();
    final goalCtrl = TextEditingController();

    const accent = Color(0xFFBF5AF2);
    const background = Color(0xFF1C1C1E);
    const textColor = Color(0xFFD9D9D9);

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Nuevo plan global',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: textColor),
              decoration: const InputDecoration(
                labelText: 'Nombre del plan',
                labelStyle: TextStyle(color: Colors.white70),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: accent),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: goalCtrl,
              style: const TextStyle(color: textColor),
              decoration: const InputDecoration(
                labelText: 'Objetivo',
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
      final plan = TrainingPlan(
        id: 'tmp',
        trainerId: Supabase.instance.client.auth.currentUser!.id,
        name: nameCtrl.text.trim(),
        goal: goalCtrl.text.trim(),
        scope: 'global',
      );
      await _repo.addGlobalPlan(plan);
      await _reload();
    }
  }

  Future<void> _deletePlan(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2E),
        title: const Text(
          'Eliminar plan',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          '¿Seguro que deseas eliminar este plan?',
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
      await _repo.remove(id);
      await _reload();
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
        title: const Text(
          'Planes de entrenamiento',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        iconTheme: const IconThemeData(color: textColor),
        actions: [
          IconButton(
            onPressed: _addPlanDialog,
            icon: const Icon(Icons.add, color: accent),
          ),
        ],
      ),
      body: FutureBuilder<List<TrainingPlan>>(
        future: _future,
        builder: (_, snap) {
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
                'No hay planes globales todavía.',
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
                final p = items[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: ListTile(
                    title: Text(
                      p.name,
                      style: const TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      p.goal ?? 'Sin objetivo',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PlanDetailScreen(plan: p),
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                      ),
                      onPressed: () => _deletePlan(p.id),
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

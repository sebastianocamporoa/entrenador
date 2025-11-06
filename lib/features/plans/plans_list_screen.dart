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

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nuevo plan global'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Nombre del plan'),
            ),
            TextField(
              controller: goalCtrl,
              decoration: const InputDecoration(labelText: 'Objetivo'),
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
    await _repo.remove(id);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Planes de entrenamiento'),
        actions: [
          IconButton(onPressed: _addPlanDialog, icon: const Icon(Icons.add)),
        ],
      ),
      body: FutureBuilder<List<TrainingPlan>>(
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
            return const Center(child: Text('No hay planes globales todavía.'));
          }

          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 0),
            itemBuilder: (_, i) {
              final p = items[i];
              return ListTile(
                title: Text(p.name),
                subtitle: Text(p.goal ?? 'Sin objetivo'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => PlanDetailScreen(plan: p)),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _deletePlan(p.id),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

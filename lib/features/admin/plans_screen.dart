import 'package:flutter/material.dart';
import '../../common/data/models/training_plan.dart';
import '../../common/data/repositories/plans_repo.dart';
import 'plan_detail_screen.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  final _repo = PlansRepo();
  late Future<List<TrainingPlan>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.listGlobalPlans(); // ✅ usamos el método correcto
  }

  Future<void> _reload() async {
    setState(() {
      _future = _repo.listGlobalPlans();
    });
  }

  Future<void> _showAddDialog() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nuevo plan global'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nombre del plan'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Objetivo (opcional)',
                ),
                maxLines: 2,
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
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (ok == true) {
      try {
        final plan = TrainingPlan(
          id: 'tmp',
          trainerId: 'admin',
          name: nameCtrl.text.trim(),
          goal: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
          scope: 'global',
        );
        await _repo.addGlobalPlan(plan); // ✅ método actualizado
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Plan agregado ✅')));
          _reload();
        }
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al agregar: $e')));
      }
    }
  }

  Future<void> _removePlan(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar plan'),
        content: const Text(
          '¿Seguro que deseas eliminar este plan de entrenamiento?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _repo.remove(id); // ✅ coincide con el repositorio actual
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Plan eliminado')));
        _reload();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Planes de entrenamiento'),
        actions: [
          IconButton(onPressed: _showAddDialog, icon: const Icon(Icons.add)),
        ],
      ),
      body: FutureBuilder<List<TrainingPlan>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }

          final plans = snap.data ?? [];
          if (plans.isEmpty) {
            return const Center(child: Text('No hay planes creados todavía.'));
          }

          return ListView.separated(
            itemCount: plans.length,
            separatorBuilder: (_, __) => const Divider(height: 0),
            itemBuilder: (_, i) {
              final p = plans[i];
              return ListTile(
                title: Text(p.name),
                subtitle: Text(p.goal ?? 'Sin objetivo'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _removePlan(p.id),
                ),
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PlanDetailScreen(plan: p),
                    ),
                  );
                  _reload();
                },
              );
            },
          );
        },
      ),
    );
  }
}

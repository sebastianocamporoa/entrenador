import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../common/data/repositories/plans_repo.dart';
import '../../common/data/repositories/assignments_repo.dart';
import 'plan_editor_screen.dart';
import 'assign_plan_screen.dart';
import '../../common/data/models/training_plan.dart';

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
    _future = _repo.listMyPlans();
  }

  Future<void> _reload() async {
    final fut = _repo.listMyPlans();
    if (!mounted) return;
    setState(() {
      _future = fut;
    });
  }

  Future<void> _addPlanDialog() async {
    final nameCtrl = TextEditingController();
    final goalCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nuevo plan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            TextField(
              controller: goalCtrl,
              decoration: const InputDecoration(
                labelText: 'Objetivo o descripción (opcional)',
              ),
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
      await _repo.add(
        TrainingPlan(
          id: 'tmp',
          trainerId: Supabase.instance.client.auth.currentUser!.id,
          name: nameCtrl.text.trim(),
          description: goalCtrl.text.trim().isEmpty
              ? null
              : goalCtrl.text.trim(),
        ),
      );
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
        title: const Text('Mis planes'),
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
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No se pudieron cargar los planes.\n${snap.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _reload,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }

          final items = snap.data ?? const <TrainingPlan>[];
          if (items.isEmpty) {
            return const Center(
              child: Text('Aún no tienes planes. Crea uno con +'),
            );
          }

          return ListView.separated(
            itemBuilder: (_, i) {
              final p = items[i];
              return ListTile(
                title: Text(p.name),
                subtitle: Text(p.description ?? '-'),
                onTap: () {
                  Navigator.of(context)
                      .push(
                        MaterialPageRoute(
                          builder: (_) =>
                              PlanEditorScreen(planId: p.id, planName: p.name),
                        ),
                      )
                      .then((_) => _reload());
                },
                trailing: PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'assign') {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              AssignPlanScreen(planId: p.id, planName: p.name),
                        ),
                      );
                    } else if (v == 'delete') {
                      await _repo.remove(p.id);
                      await _reload();
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'assign',
                      child: Text('Asignar a cliente'),
                    ),
                    PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                  ],
                ),
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

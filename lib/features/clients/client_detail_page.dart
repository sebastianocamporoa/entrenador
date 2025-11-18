import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Vista de detalle de un cliente (coach: lectura en datos/progreso; edición SOLO en planes)
class ClientDetailPage extends StatelessWidget {
  final Map<String, dynamic> client;

  const ClientDetailPage({super.key, required this.client});

  @override
  Widget build(BuildContext context) {
    final c = client;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(c['name'] ?? 'Cliente'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Datos'),
              Tab(text: 'Planes'),
              Tab(text: 'Progreso'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _DatosTab(c: c),
            _PlanesTab(clientId: c['id'], clientName: c['name'] ?? 'Cliente'),
            _ProgresoTab(clientId: c['id']),
          ],
        ),
      ),
    );
  }
}

/// 🔹 Tab 1: Datos del cliente (solo lectura)
class _DatosTab extends StatelessWidget {
  final Map<String, dynamic> c;
  const _DatosTab({required this.c});

  String _sexLabel(String? s) {
    switch (s) {
      case 'M':
        return 'Masculino';
      case 'F':
        return 'Femenino';
      case 'O':
        return 'Otro';
      default:
        return '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Tile(label: 'Email', value: c['email']),
        _Tile(label: 'Teléfono', value: c['phone']),
        _Tile(label: 'Objetivo', value: c['goal']),
        _Tile(label: 'Sexo', value: _sexLabel(c['sex'])),
        _Tile(
          label: 'Estado',
          value: (c['is_active'] ?? true) ? 'Activo' : 'Inactivo',
        ),
      ],
    );
  }
}

/// 🔹 Tab 2: Planes asignados al cliente (coach puede asignar y quitar)
class _PlanesTab extends StatefulWidget {
  final String clientId;
  final String clientName;
  const _PlanesTab({required this.clientId, required this.clientName});

  @override
  State<_PlanesTab> createState() => _PlanesTabState();
}

class _PlanesTabState extends State<_PlanesTab> {
  final _db = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _loadAssignedPlans();
  }

  Future<List<Map<String, dynamic>>> _loadAssignedPlans() async {
    final data = await _db
        .from('client_plan') // ✅ tabla corregida
        .select('id, start_date, is_active, plan:plan_id(id, name, goal)')
        .eq('client_id', widget.clientId)
        .order('start_date', ascending: false);

    return List<Map<String, dynamic>>.from(
      data.map((e) {
        final p = e['plan'] ?? {};
        return {
          'assignment_id': e['id'],
          'plan_id': p['id'],
          'name': p['name'] ?? 'Plan',
          'goal': p['goal'],
          'is_active': e['is_active'] ?? true,
        };
      }),
    );
  }

  Future<void> _assignPlanFlow() async {
    final coachId = _db.auth.currentUser?.id;
    if (coachId == null) return;

    // 🔹 1) Traer planes del coach desde training_plan
    final plans = await _db
        .from('training_plan')
        .select('id, name, goal, scope, trainer_id')
        .or('scope.eq.global,trainer_id.eq.$coachId')
        .order('created_at', ascending: false);

    if (!mounted) return;

    // 🔹 2) Mostrar selector
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _AssignPlanSheet(
        plans: List<Map<String, dynamic>>.from(plans),
        clientName: widget.clientName,
      ),
    );

    if (selected == null) return;

    // 🔹 3) Insertar relación cliente-plan
    setState(() => _busy = true);
    try {
      await _db.from('client_plan').insert({
        'client_id': widget.clientId,
        'plan_id': selected['id'],
        'start_date': DateTime.now().toIso8601String(),
        'is_active': true,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Plan asignado ✅')));
      setState(() => _future = _loadAssignedPlans());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo asignar: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _unassignPlan(String assignmentId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Quitar plan'),
        content: const Text('¿Deseas quitar este plan del cliente?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      await _db.from('client_plan').delete().eq('id', assignmentId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Plan quitado 🗑️')));
      setState(() => _future = _loadAssignedPlans());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo quitar: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(child: Text('Error: ${snap.error}'));
            }
            final items = snap.data ?? [];
            if (items.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Sin planes asignados'),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _busy ? null : _assignPlanFlow,
                      icon: const Icon(Icons.add),
                      label: const Text('Asignar plan'),
                    ),
                  ],
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: () async =>
                  setState(() => _future = _loadAssignedPlans()),
              child: ListView.separated(
                padding: const EdgeInsets.only(bottom: 88),
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final p = items[i];
                  return ListTile(
                    title: Text(p['name'] ?? 'Plan'),
                    subtitle: Text(p['goal'] ?? '—'),
                    trailing: IconButton(
                      tooltip: 'Quitar plan',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: _busy
                          ? null
                          : () => _unassignPlan(p['assignment_id'] as String),
                    ),
                  );
                },
              ),
            );
          },
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: _busy ? null : _assignPlanFlow,
            icon: const Icon(Icons.add),
            label: const Text('Asignar plan'),
          ),
        ),
      ],
    );
  }
}

class _AssignPlanSheet extends StatelessWidget {
  final List<Map<String, dynamic>> plans;
  final String clientName;
  const _AssignPlanSheet({required this.plans, required this.clientName});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, controller) {
          return Material(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Asignar plan a $clientName',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    controller: controller,
                    itemCount: plans.length,
                    itemBuilder: (_, i) {
                      final p = plans[i];
                      return ListTile(
                        title: Text(p['name'] ?? 'Plan'),
                        subtitle: Text((p['goal'] ?? '').toString()),
                        onTap: () => Navigator.pop(context, p),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProgresoTab extends StatelessWidget {
  final String clientId;
  const _ProgresoTab({required this.clientId});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Progreso del cliente (solo lectura)',
        style: TextStyle(color: Colors.grey),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final String label;
  final String? value;

  const _Tile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        label,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      subtitle: Text(value == null || value!.isEmpty ? '—' : value!),
    );
  }
}

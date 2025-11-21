import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ClientDetailPage extends StatelessWidget {
  final Map<String, dynamic> client;

  const ClientDetailPage({super.key, required this.client});

  @override
  Widget build(BuildContext context) {
    final c = client;
    const background = Color(0xFF1C1C1E);
    const cardColor = Color(0xFF2C2C2E);
    const accent = Color(0xFFBF5AF2);
    const textColor = Color(0xFFD9D9D9);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          backgroundColor: background,
          elevation: 0,
          title: Text(
            c['name'] ?? 'Cliente',
            style: const TextStyle(
              color: textColor,
              fontWeight: FontWeight.w700,
              fontSize: 22,
            ),
          ),
          iconTheme: const IconThemeData(color: textColor),
          bottom: const TabBar(
            indicatorColor: accent,
            labelColor: accent,
            unselectedLabelColor: Colors.white54,
            labelStyle: TextStyle(fontWeight: FontWeight.bold),
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
    const cardColor = Color(0xFF2C2C2E);
    const textColor = Color(0xFFD9D9D9);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.purple.withOpacity(0.3),
                child: Text(
                  (c['name'] ?? '?')[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 36,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                c['name'] ?? '—',
                style: const TextStyle(
                  color: textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                c['email'] ?? '',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const Divider(height: 32, color: Colors.white10),
              _Tile(label: 'Teléfono', value: c['phone']),
              _Tile(label: 'Objetivo', value: c['goal']),
              _Tile(label: 'Sexo', value: _sexLabel(c['sex'])),
              _Tile(
                label: 'Estado',
                value: (c['is_active'] ?? true) ? 'Activo' : 'Inactivo',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

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
        .from('client_plan')
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

    final plans = await _db
        .from('training_plan')
        .select('id, name, goal, scope, trainer_id')
        .or('scope.eq.global,trainer_id.eq.$coachId')
        .order('created_at', ascending: false);

    if (!mounted) return;

    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _AssignPlanSheet(
        plans: List<Map<String, dynamic>>.from(plans),
        clientName: widget.clientName,
      ),
    );

    if (selected == null) return;

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
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _unassignPlan(String assignmentId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2E),
        title: const Text('Quitar plan', style: TextStyle(color: Colors.white)),
        content: const Text(
          '¿Deseas quitar este plan del cliente?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.white),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
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
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFBF5AF2);
    const cardColor = Color(0xFF2C2C2E);
    const textColor = Color(0xFFD9D9D9);

    return Stack(
      children: [
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: accent),
              );
            }
            if (snap.hasError) {
              return Center(
                child: Text(
                  'Error: ${snap.error}',
                  style: TextStyle(color: accent),
                ),
              );
            }
            final items = snap.data ?? [];
            if (items.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Sin planes asignados',
                      style: TextStyle(color: textColor),
                    ),
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
              color: accent,
              onRefresh: () async =>
                  setState(() => _future = _loadAssignedPlans()),
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
                        p['name'] ?? 'Plan',
                        style: const TextStyle(color: textColor),
                      ),
                      subtitle: Text(
                        p['goal'] ?? '—',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                        ),
                        onPressed: _busy
                            ? null
                            : () => _unassignPlan(p['assignment_id']),
                      ),
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
            backgroundColor: accent,
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
    const background = Color(0xFF1C1C1E);
    const textColor = Color(0xFFD9D9D9);

    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        builder: (_, controller) {
          return Container(
            decoration: const BoxDecoration(
              color: background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade600,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Asignar plan a $clientName',
                  style: const TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    controller: controller,
                    itemCount: plans.length,
                    itemBuilder: (_, i) {
                      final p = plans[i];
                      return ListTile(
                        title: Text(
                          p['name'] ?? 'Plan',
                          style: const TextStyle(color: textColor),
                        ),
                        subtitle: Text(
                          p['goal'] ?? '',
                          style: const TextStyle(color: Colors.white70),
                        ),
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
        style: TextStyle(color: Colors.white54),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 14),
          ),
          Text(
            value == null || value!.isEmpty ? '—' : value!,
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

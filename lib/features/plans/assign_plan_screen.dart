import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../common/data/repositories/assignments_repo.dart';

class AssignPlanScreen extends StatefulWidget {
  final String planId;
  final String planName;
  const AssignPlanScreen({
    super.key,
    required this.planId,
    required this.planName,
  });

  @override
  State<AssignPlanScreen> createState() => _AssignPlanScreenState();
}

class _AssignPlanScreenState extends State<AssignPlanScreen> {
  final _repo = AssignmentsRepo();
  final _supa = Supabase.instance.client;

  String? _selectedClientId;
  DateTime _start = DateTime.now();

  Future<List<Map<String, dynamic>>> _loadMyClients() async {
    // Lista clientes del coach: ajusta el select a tus columnas
    final uid = _supa.auth.currentUser!.id;
    final res = await _supa
        .from('clients')
        .select('id, full_name, email, trainer_id')
        .eq('trainer_id', uid)
        .order('full_name', ascending: true);
    return List<Map<String, dynamic>>.from(res as List);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => _start = picked);
  }

  Future<void> _assign() async {
    if (_selectedClientId == null) return;
    // Guarda start_date y (opcional) active=true
    await _supa.from('plan_assignment').insert({
      'plan_id': widget.planId,
      'client_id': _selectedClientId,
      'start_date': _start.toIso8601String(),
      'active': true,
    });
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Plan asignado')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Asignar plan: ${widget.planName}')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _loadMyClients(),
        builder: (_, snap) {
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());
          final clients = snap.data!;
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: _selectedClientId,
                  items: clients.map((c) {
                    final name =
                        (c['full_name'] ?? c['email'] ?? 'Cliente') as String;
                    return DropdownMenuItem(
                      value: c['id'] as String,
                      child: Text(name),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedClientId = v),
                  decoration: const InputDecoration(labelText: 'Cliente'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Inicio: ${_start.toIso8601String().split('T').first}',
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.date_range),
                      label: const Text('Cambiar'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _assign,
                    child: const Text('Asignar plan'),
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

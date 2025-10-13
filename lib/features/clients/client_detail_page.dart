import 'package:flutter/material.dart';
import 'clients_api.dart';

class ClientDetailPage extends StatefulWidget {
  final Map<String, dynamic> client; // viene desde la lista
  const ClientDetailPage({super.key, required this.client});

  @override
  State<ClientDetailPage> createState() => _ClientDetailPageState();
}

class _ClientDetailPageState extends State<ClientDetailPage> {
  final api = ClientsApi();
  late Map<String, dynamic> c;

  @override
  void initState() {
    super.initState();
    c = Map<String, dynamic>.from(widget.client);
  }

  Future<void> _edit() async {
    final nameCtrl = TextEditingController(text: c['name'] ?? '');
    final emailCtrl = TextEditingController(text: c['email'] ?? '');
    final phoneCtrl = TextEditingController(text: c['phone'] ?? '');
    final goalCtrl = TextEditingController(text: c['goal'] ?? '');
    String? sex = c['sex']; // 'M', 'F', 'O'
    bool isActive = (c['is_active'] ?? true) as bool;

    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Editar cliente'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
                TextFormField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                ),
                TextFormField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Teléfono'),
                  keyboardType: TextInputType.phone,
                ),
                TextFormField(
                  controller: goalCtrl,
                  decoration: const InputDecoration(labelText: 'Objetivo'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: sex,
                  decoration: const InputDecoration(labelText: 'Sexo'),
                  items: const [
                    DropdownMenuItem(value: 'M', child: Text('Masculino')),
                    DropdownMenuItem(value: 'F', child: Text('Femenino')),
                    DropdownMenuItem(value: 'O', child: Text('Otro')),
                  ],
                  onChanged: (v) => sex = v,
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Activo'),
                  value: isActive,
                  onChanged: (v) => setState(() => isActive = v),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              // Actualiza en Supabase
              await api.update(c['id'], {
                'name': nameCtrl.text.trim(),
                'email': emailCtrl.text.trim().isEmpty
                    ? null
                    : emailCtrl.text.trim(),
                'phone': phoneCtrl.text.trim().isEmpty
                    ? null
                    : phoneCtrl.text.trim(),
                'goal': goalCtrl.text.trim().isEmpty
                    ? null
                    : goalCtrl.text.trim(),
                'sex': sex,
                'is_active': isActive,
              });
              // Refresca estado local
              setState(() {
                c['name'] = nameCtrl.text.trim();
                c['email'] = emailCtrl.text.trim().isEmpty
                    ? null
                    : emailCtrl.text.trim();
                c['phone'] = phoneCtrl.text.trim().isEmpty
                    ? null
                    : phoneCtrl.text.trim();
                c['goal'] = goalCtrl.text.trim().isEmpty
                    ? null
                    : goalCtrl.text.trim();
                c['sex'] = sex;
                c['is_active'] = isActive;
              });
              if (context.mounted) Navigator.pop(context, true);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cliente actualizado ✅')));
    }
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar cliente'),
        content: const Text('Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await api.remove(c['id']);
      if (!mounted) return;
      Navigator.pop(context, true); // volvemos a la lista para refrescar
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cliente eliminado 🗑️')));
    }
  }

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
    final chips = <Widget>[];
    chips.add(
      Chip(label: Text(c['is_active'] == true ? 'Activo' : 'Inactivo')),
    );
    if (c['sex'] != null) chips.add(Chip(label: Text(_sexLabel(c['sex']))));

    return Scaffold(
      appBar: AppBar(
        title: Text(c['name'] ?? 'Cliente'),
        actions: [
          IconButton(icon: const Icon(Icons.edit), onPressed: _edit),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(spacing: 8, runSpacing: 8, children: chips),
          const SizedBox(height: 12),
          _Tile(label: 'Email', value: c['email']),
          _Tile(label: 'Teléfono', value: c['phone']),
          _Tile(label: 'Objetivo', value: c['goal']),
          const Divider(height: 32),
          const Text(
            'Próximo: Mediciones y Fotos',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Aquí pondremos pestañas: Datos · Mediciones · Fotos · Nutrición · Notas',
          ),
        ],
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

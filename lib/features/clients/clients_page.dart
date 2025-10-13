import 'package:flutter/material.dart';
import 'clients_api.dart';
import 'client_detail_page.dart';

class ClientsPage extends StatefulWidget {
  const ClientsPage({super.key});
  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> {
  final api = ClientsApi();
  final nameCtrl = TextEditingController();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = api.list();
  }

  Future<void> _create() async {
    final name = nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Escribe un nombre')));
      return;
    }
    try {
      await api.create(name: name);
      nameCtrl.clear();
      setState(() {
        _future = api.list();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cliente agregado ✅')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo agregar: $e')));
    }
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clientes')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del cliente',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) =>
                        setState(() {}), // para habilitar/deshabilitar botón
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: nameCtrl.text.trim().isEmpty ? null : _create,
                  child: const Text('Agregar'),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder(
              future: _future,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snap.data as List<Map<String, dynamic>>;
                if (items.isEmpty) {
                  return const Center(child: Text('Aún no hay clientes'));
                }
                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final c = items[i];
                    return ListTile(
                      title: Text(c['name'] ?? '—'),
                      subtitle: Text(c['email'] ?? ''),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          await api.remove(c['id']);
                          setState(() {
                            _future = api.list();
                          });
                        },
                      ),
                      // 👉 ESTE ES EL onTap QUE PREGUNTAS
                      onTap: () async {
                        final changed = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) => ClientDetailPage(client: c),
                          ),
                        );
                        if (changed == true && mounted) {
                          setState(() {
                            _future = api.list(); // refresca si hubo cambios
                          });
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

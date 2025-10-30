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
  final emailCtrl = TextEditingController();
  late Future<List<Map<String, dynamic>>> _future;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _future = api.list();
  }

  Future<void> _create() async {
    final email = emailCtrl.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ingresa un correo válido')));
      return;
    }

    setState(() => loading = true);

    try {
      // 🔹 Creamos el cliente solo con el correo
      await api.create(email: email);

      emailCtrl.clear();
      setState(() {
        _future = api.list();
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Cliente agregado ✅')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo agregar: $e')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    emailCtrl.dispose();
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
            child: Column(
              children: [
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo del cliente',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: loading ? null : _create,
                    icon: const Icon(Icons.person_add_alt_1),
                    label: Text(loading ? 'Agregando...' : 'Agregar cliente'),
                  ),
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
                      title: Text(c['email'] ?? '—'),
                      subtitle: Text(c['name'] ?? ''),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          await api.remove(c['id']);
                          setState(() {
                            _future = api.list();
                          });
                        },
                      ),
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

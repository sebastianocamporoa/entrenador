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
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = api.list();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clientes')),
      body: FutureBuilder(
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
            return const Center(child: Text('Aún no hay clientes asignados'));
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _future = api.list());
            },
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final c = items[i];
                return ListTile(
                  title: Text(c['name'] ?? '—'),
                  subtitle: Text(c['email'] ?? ''),
                  trailing: Icon(
                    (c['is_active'] ?? true)
                        ? Icons.circle
                        : Icons.circle_outlined,
                    size: 12,
                    color: (c['is_active'] ?? true)
                        ? Colors.green
                        : Colors.grey,
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ClientDetailPage(client: c),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

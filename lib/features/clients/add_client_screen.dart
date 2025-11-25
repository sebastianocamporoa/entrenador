import 'package:flutter/material.dart';
import 'clients_api.dart';

class AddClientScreen extends StatefulWidget {
  const AddClientScreen({super.key});

  @override
  State<AddClientScreen> createState() => _AddClientScreenState();
}

class _AddClientScreenState extends State<AddClientScreen> {
  final emailCtrl = TextEditingController();
  final api = ClientsApi();
  bool loading = false;
  String? error;

  Future<void> _save() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      await api.addClient(emailCtrl.text.trim());
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFBF5AF2);

    return Scaffold(
      appBar: AppBar(title: const Text('Agregar cliente')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red)),
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(
                labelText: 'Correo del cliente',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: loading ? null : _save,
                child: Text(loading ? 'Agregando...' : 'Agregar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

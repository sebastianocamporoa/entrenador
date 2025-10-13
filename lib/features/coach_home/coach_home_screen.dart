import 'package:flutter/material.dart';
import '../clients/clients_page.dart';
import '../plans/plans_list_screen.dart';

class CoachHomeScreen extends StatelessWidget {
  const CoachHomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Entrenador')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ClientsPage())),
            child: const Text('Ir a Clientes'),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const PlansListScreen())),
            child: const Text('Planes de entrenamiento'),
          ),
        ],
      ),
    );
  }
}

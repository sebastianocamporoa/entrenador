import 'package:flutter/material.dart';
import 'promote_user_screen.dart';
import 'exercises_screen.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Panel Admin')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.upgrade),
              title: const Text('Promover usuario a Coach'),
              subtitle: const Text('Eleva un usuario existente al rol coach'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PromoteUserScreen()),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.fitness_center),
              title: const Text('Ejercicios Globales'),
              subtitle: const Text('Gestiona la librería global de ejercicios'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ExercisesScreen()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

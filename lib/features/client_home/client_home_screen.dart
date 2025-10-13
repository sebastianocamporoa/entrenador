import 'package:flutter/material.dart';
import '../../common/services/user_service.dart';
import 'today_workout_screen.dart';

class ClientHomeScreen extends StatefulWidget {
  const ClientHomeScreen({super.key});
  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen> {
  final _userSrv = UserService();
  late Future<bool> _linked;

  @override
  void initState() {
    super.initState();
    _linked = _userSrv.isClientLinkedToTrainer();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _linked,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final isLinked = snap.data!;
        if (!isLinked) {
          return Scaffold(
            appBar: AppBar(title: const Text('Mi rutina')),
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.info_outline, size: 48),
                    SizedBox(height: 12),
                    Text(
                      'Aún no estás asociado a un entrenador.',
                      style: TextStyle(fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Pídele a tu entrenador que te agregue para ver tu rutina aquí.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Mi rutina')),
          body: Center(
            child: FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TodayWorkoutScreen()),
              ),
              child: const Text('Ver entrenamiento de hoy'),
            ),
          ),
        );
      },
    );
  }
}

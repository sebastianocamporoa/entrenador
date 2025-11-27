import 'package:flutter/material.dart';
import '../../common/services/user_service.dart';
import '../../common/data/repositories/training_sessions_repo.dart'; // Asegúrate de importar tu repo
import '../../common/data/models/training_session.dart'; // Importa el modelo
import 'today_workout_screen.dart';

class ClientHomeScreen extends StatefulWidget {
  const ClientHomeScreen({super.key});
  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen> {
  final _userSrv = UserService();
  final _sessionRepo = TrainingSessionsRepo(); // Instancia del repo

  // Vamos a cargar dos cosas: si está vinculado y la sesión de hoy
  late Future<Map<String, dynamic>> _initData;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _initData = _fetchData();
    });
  }

  Future<Map<String, dynamic>> _fetchData() async {
    final isLinked = await _userSrv.isClientLinkedToTrainer();
    TrainingSession? session;

    if (isLinked) {
      // Solo buscamos sesión si ya tiene entrenador
      session = await _sessionRepo.getClientSessionToday();
    }

    return {'isLinked': isLinked, 'session': session};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi rutina'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed:
                _loadData, // Para que el cliente pueda recargar y ver si ya inició
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _initData,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }

          final data = snap.data!;
          final bool isLinked = data['isLinked'];
          final TrainingSession? session = data['session'];

          // CASO 1: No tiene entrenador
          if (!isLinked) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Aún no estás asociado a un entrenador.\nPídele que te agregue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ),
            );
          }

          // CASO 2: Tiene entrenador pero NO hay sesión programada para hoy
          if (session == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.event_busy, size: 60, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Hoy no tienes entrenamiento programado.',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          // CASO 3: Hay sesión, pero el entrenador NO le ha dado "Iniciar"
          if (!session.started) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.hourglass_top_rounded,
                      size: 80,
                      color: Colors.orangeAccent,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Esperando al entrenador',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Tu sesión está programada, pero tu entrenador debe iniciarla primero.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: _loadData,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Verificar de nuevo'),
                    ),
                  ],
                ),
              ),
            );
          }

          // CASO 4: ¡Sesión iniciada! Mostrar botón de acceso
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.fitness_center,
                  size: 80,
                  color: Colors.greenAccent,
                ),
                const SizedBox(height: 24),
                const Text(
                  '¡Tu sesión está lista!',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 20,
                    ),
                  ),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const TodayWorkoutScreen(),
                    ),
                  ),
                  child: const Text(
                    'Comenzar entrenamiento',
                    style: TextStyle(fontSize: 18),
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

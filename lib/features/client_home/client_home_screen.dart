import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Necesario para la consulta directa

import '../../common/services/user_service.dart';
import '../../common/data/repositories/training_sessions_repo.dart';
import '../../common/data/models/training_session.dart';
import 'today_workout_screen.dart';

// Importamos el Wizard que acabamos de crear
import '../client_onboarding/client_onboarding_wizard.dart';

class ClientHomeScreen extends StatefulWidget {
  const ClientHomeScreen({super.key});

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen> {
  final _userSrv = UserService();
  final _sessionRepo = TrainingSessionsRepo();
  final _supa = Supabase.instance.client;

  late Future<Map<String, dynamic>> _initData;

  @override
  void initState() {
    super.initState();
    _loadData();

    // 🔥 NUEVO: Verificamos si faltan datos apenas carga la pantalla
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkOnboarding();
    });
  }

  void _loadData() {
    setState(() {
      _initData = _fetchData();
    });
  }

  // Lógica para detectar si es la primera vez (o faltan datos)
  Future<void> _checkOnboarding() async {
    final user = _supa.auth.currentUser;
    if (user == null) return;

    try {
      // 1. Obtener ID interno (app_user)
      final appUser = await _supa
          .from('app_user')
          .select('id')
          .eq('auth_user_id', user.id)
          .maybeSingle();

      if (appUser == null) return;
      final internalId = appUser['id'];

      // 2. Consultar datos del cliente
      final clientData = await _supa
          .from('clients')
          .select('sex, phone, goal')
          .eq('app_user_id', internalId)
          .maybeSingle();

      if (clientData == null) return;

      // 3. Verificar si algún campo clave está vacío o nulo
      final needsOnboarding =
          clientData['sex'] == null ||
          clientData['phone'] == null ||
          clientData['goal'] == null;

      if (needsOnboarding) {
        if (!mounted) return;

        // 4. Lanzar el Wizard
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const ClientOnboardingWizard(),
            fullscreenDialog: true, // Animación deslizante desde abajo
          ),
        );

        // Al volver, recargamos por si acaso
        _loadData();
      }
    } catch (e) {
      debugPrint('Error verificando onboarding: $e');
    }
  }

  Future<Map<String, dynamic>> _fetchData() async {
    final isLinked = await _userSrv.isClientLinkedToTrainer();
    TrainingSession? session;

    if (isLinked) {
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
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
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

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../common/services/user_service.dart';
import '../../common/data/models/training_session.dart';
import 'today_workout_screen.dart'; // Recuperamos esta importación para poder navegar
import '../client_onboarding/client_onboarding_wizard.dart';
import 'widgets/weekly_schedule_bar.dart';

class ClientHomeScreen extends StatefulWidget {
  const ClientHomeScreen({super.key});

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen> {
  final _userSrv = UserService();
  final _supa = Supabase.instance.client;

  // Estado
  DateTime _selectedDateInBar =
      DateTime.now(); // Solo para efecto visual de la barra
  List<TrainingSession> _allSessions = [];
  List<String> _workoutDates = [];
  bool _isLoading = true;
  bool _isLinked = false;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting();
    _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkOnboarding();
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final isLinked = await _userSrv.isClientLinkedToTrainer();
      if (!isLinked) {
        setState(() {
          _isLinked = false;
          _isLoading = false;
        });
        return;
      }
      _isLinked = true;

      final user = _supa.auth.currentUser;
      if (user == null) return;

      // Obtener IDs
      final appUser = await _supa
          .from('app_user')
          .select('id')
          .eq('auth_user_id', user.id)
          .single();
      final client = await _supa
          .from('clients')
          .select('id')
          .eq('app_user_id', appUser['id'])
          .single();
      final clientId = client['id'];

      // Traer rango amplio para el calendario (-30 a +30 días)
      final now = DateTime.now();
      final startRange = now.subtract(const Duration(days: 30));
      final endRange = now.add(const Duration(days: 30));

      final response = await _supa
          .from('training_session')
          .select()
          .eq('client_id', clientId)
          .gte('start_time', startRange.toIso8601String())
          .lt('start_time', endRange.toIso8601String());

      final List<dynamic> data = response;
      final sessions = data
          .map((json) => TrainingSession.fromJson(json))
          .toList();

      // Fechas para los puntitos
      final dates = sessions
          .map((s) {
            return DateFormat('yyyy-MM-dd').format(s.startTime.toLocal());
          })
          .toSet()
          .toList();

      setState(() {
        _allSessions = sessions;
        _workoutDates = dates;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkOnboarding() async {
    // (Tu lógica de onboarding existente...)
  }

  // Busca sesión por fecha específica
  TrainingSession? _getSessionForDate(DateTime date) {
    final targetStr = DateFormat('yyyy-MM-dd').format(date);
    try {
      return _allSessions.firstWhere((s) {
        final sessionDate = DateFormat(
          'yyyy-MM-dd',
        ).format(s.startTime.toLocal());
        return sessionDate == targetStr;
      });
    } catch (e) {
      return null;
    }
  }

  // --- LÓGICA DEL DIALOG (POPUP) ---
  void _showDayDetails(DateTime date) {
    setState(() => _selectedDateInBar = date); // Actualiza visualmente la barra

    final session = _getSessionForDate(date);
    final dateTitle = DateFormat(
      'EEEE d \'de\' MMMM',
      'es_ES',
    ).format(date); // Ej: Lunes 15 de Enero

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: const EdgeInsets.all(20),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                dateTitle.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 20),
              if (session == null) ...[
                // Caso: Sin entreno
                Icon(Icons.weekend, size: 50, color: Colors.grey.shade700),
                const SizedBox(height: 16),
                const Text(
                  'Día Libre',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ] else ...[
                // Caso: Con entreno
                Icon(
                  session.started ? Icons.check_circle : Icons.schedule,
                  size: 60,
                  color: session.started ? Colors.green : Colors.orange,
                ),
                const SizedBox(height: 16),
                Text(
                  session.started ? 'REALIZADO' : 'PENDIENTE',
                  style: TextStyle(
                    color: session.started ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white10),
                const SizedBox(height: 16),
                Text(
                  session.notes?.toUpperCase() ?? 'ENTRENAMIENTO',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Hora: ${DateFormat('h:mm a').format(session.startTime.toLocal())}',
                  style: const TextStyle(color: Colors.white38),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Cerrar',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Para el cuerpo principal, SIEMPRE usamos HOY
    final todaySession = _getSessionForDate(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Rutina'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: Column(
        children: [
          // 1. BARRA (Abre Dialog)
          WeeklyScheduleBar(
            workoutDates: _workoutDates,
            selectedDate: _selectedDateInBar,
            onDateSelected: (date) => _showDayDetails(date),
          ),

          const Divider(height: 1, color: Colors.white10),

          // 2. CUERPO PRINCIPAL (Lógica de "HOY")
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildTodayContent(todaySession),
          ),
        ],
      ),
    );
  }

  /// RESTAURAMOS LA VISTA DE ACCIÓN PARA HOY
  Widget _buildTodayContent(TrainingSession? session) {
    if (!_isLinked) {
      return const Center(child: Text('Sin entrenador asignado.'));
    }

    // A. Hoy no hay nada
    if (session == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.event_available, size: 60, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Hoy es día de descanso.',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Revisa la barra para ver otros días.',
              style: TextStyle(color: Colors.white38),
            ),
          ],
        ),
      );
    }

    // B. Hoy hay entreno, pero no ha iniciado
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
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
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

    // C. Hoy hay entreno Y ya inició (Boton verde)
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.fitness_center, size: 80, color: Colors.greenAccent),
          const SizedBox(height: 24),
          const Text(
            '¡Tu sesión está lista!',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
            ),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TodayWorkoutScreen()),
            ),
            child: const Text(
              'Comenzar entrenamiento',
              style: TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
    );
  }
}

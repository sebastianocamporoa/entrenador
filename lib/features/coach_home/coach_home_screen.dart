import 'dart:math';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import '../clients/clients_page.dart';
import '../plans/plans_list_screen.dart';
import '../../common/data/repositories/training_sessions_repo.dart';
import '../../common/data/models/training_session.dart';
import 'widgets/add_session_dialog.dart';

class CoachHomeScreen extends StatefulWidget {
  const CoachHomeScreen({super.key});

  @override
  State<CoachHomeScreen> createState() => _CoachHomeScreenState();
}

class _CoachHomeScreenState extends State<CoachHomeScreen> {
  final _repo = TrainingSessionsRepo();
  List<TrainingSession> _sessions = [];

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    try {
      final data = await _repo.getSessions();
      if (mounted) setState(() => _sessions = data);
    } catch (e) {
      debugPrint('Error cargando sesiones: $e');
    }
  }

  // 🎨 Paleta de colores para las sesiones
  final List<Color> _colors = [
    Colors.indigo,
    Colors.orange,
    Colors.green,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.blueGrey,
    Colors.cyan,
    Colors.redAccent,
    Colors.lime,
  ];

  // 🔹 Asigna color determinístico por cliente
  Color _getColorForClient(String? clientId) {
    if (clientId == null) return Colors.grey.shade400;
    final hash = clientId.hashCode;
    final index = hash.abs() % _colors.length;
    return _colors[index];
  }

  List<Appointment> _mapToAppointments(List<TrainingSession> sessions) {
    return sessions.map((s) {
      return Appointment(
        startTime: s.startTime,
        endTime: s.endTime,
        subject: s.notes ?? (s.clientName ?? 'Sesión'),
        color: _getColorForClient(s.clientId),
        isAllDay: false,
        notes: s.clientName ?? '',
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final appointments = _mapToAppointments(_sessions);

    return Scaffold(
      appBar: AppBar(title: const Text('Entrenador')),
      body: RefreshIndicator(
        onRefresh: _loadSessions,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 🔹 Botones principales
            FilledButton(
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ClientsPage())),
              child: const Text('Ir a Clientes'),
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PlansListScreen()),
              ),
              child: const Text('Planes de entrenamiento'),
            ),
            const SizedBox(height: 24),

            // 🗓️ Calendario semanal
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Agenda semanal',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Actualizar calendario',
                  onPressed: _loadSessions,
                ),
              ],
            ),
            const SizedBox(height: 8),

            SizedBox(
              height: 600,
              child: SfCalendar(
                view: CalendarView.week,
                firstDayOfWeek: 1,
                dataSource: TrainingDataSource(appointments),
                showDatePickerButton: true,
                showCurrentTimeIndicator: true,
                todayHighlightColor: Colors.indigo,
                appointmentTextStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
                timeSlotViewSettings: const TimeSlotViewSettings(
                  timeIntervalHeight: 60,
                  startHour: 6,
                  endHour: 22,
                ),
                onTap: (details) {
                  if (details.targetElement == CalendarElement.appointment) {
                    final session = details.appointments?.first;
                    if (session is Appointment) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '🕒 ${session.subject}\nCliente: ${session.notes}',
                          ),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  }
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.white,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (_) => const AddSessionDialog(),
          );
          if (result == true) {
            _loadSessions(); // 🔄 Refresca la lista del calendario si se guardó correctamente
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// 🔹 Adaptador para el calendario de Syncfusion
class TrainingDataSource extends CalendarDataSource {
  TrainingDataSource(List<Appointment> source) {
    appointments = source;
  }
}

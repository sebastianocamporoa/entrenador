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

  List<Appointment> _mapToAppointments(List<TrainingSession> sessions) {
    return sessions.map((s) {
      return Appointment(
        startTime: s.startTime,
        endTime: s.endTime,
        subject: s.notes ?? (s.clientName ?? 'Sesión'),
        color: Colors.indigo,
        isAllDay: false,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final appointments = _mapToAppointments(_sessions);

    return Scaffold(
      appBar: AppBar(title: const Text('Entrenador')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Botones principales
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
          const SizedBox(height: 24),

          // 🗓️ Calendario tipo Google Calendar
          Text(
            'Agenda semanal',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 600,
            child: SfCalendar(
              view: CalendarView.week,
              firstDayOfWeek: 1,
              dataSource: TrainingDataSource(appointments),
              showDatePickerButton: true,
              showCurrentTimeIndicator: true,
              todayHighlightColor: Colors.indigo,
              onTap: (details) {
                if (details.targetElement == CalendarElement.appointment) {
                  final session = details.appointments?.first;
                  if (session is Appointment) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Sesión: ${session.subject}')),
                    );
                  }
                }
              },
            ),
          ),
        ],
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
            // 🔄 Refresca la lista del calendario si se guardó correctamente
            _loadSessions();
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

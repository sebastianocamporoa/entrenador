import 'dart:math';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import '../clients/clients_page.dart';
import '../plans/plans_list_screen.dart';
import '../../common/data/repositories/training_sessions_repo.dart';
import '../../common/data/models/training_session.dart';
import 'widgets/add_session_dialog.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  Color _getColorForClient(String? clientId) {
    if (clientId == null) return Colors.grey.shade400;
    final hash = clientId.hashCode;
    final index = hash.abs() % _colors.length;
    return _colors[index];
  }

  List<Appointment> _mapToAppointments(List<TrainingSession> sessions) {
    return sessions.map((s) {
      return Appointment(
        id: s.id,
        startTime: s.startTime.toLocal(),
        endTime: s.endTime.toLocal(),

        // --- CAMBIO AQUÍ ---
        // Antes tenías: s.notes ?? ...
        // Ahora ponemos el nombre del cliente como prioridad:
        subject: s.clientName ?? 'Sin Cliente',

        color: _getColorForClient(s.clientId),
        isAllDay: false,

        // Y movemos las notas a la propiedad 'notes' del calendario
        // para que no se pierdan (se verán si inspeccionas el objeto)
        notes: s.notes,

        location: s.started.toString(),
        recurrenceId: s.clientId,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final appointments = _mapToAppointments(_sessions);
    const background = Color(0xFF1C1C1E);
    const backgroundSecondary = Color(0xFF2C2C2E);
    const accent = Color(0xFFBF5AF2);
    const textColor = Color(0xFFD9D9D9);

    final user = Supabase.instance.client.auth.currentUser;
    final name =
        user?.userMetadata?['full_name'] ??
        user?.email?.split('@').first ??
        'Entrenador';

    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Buenos días'
        : hour < 18
        ? 'Buenas tardes'
        : 'Buenas noches';

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        title: const Text(
          'Entrenador',
          style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
        ),
        iconTheme: const IconThemeData(color: textColor),
      ),
      body: RefreshIndicator(
        color: accent,
        onRefresh: _loadSessions,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hola, $name 👋',
                    style: const TextStyle(
                      color: textColor,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    greeting,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 18,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),

            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const ClientsPage()));
              },
              child: const Text('Ir a Clientes'),
            ),
            const SizedBox(height: 12),

            FilledButton.tonal(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white10,
                foregroundColor: textColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PlansListScreen()),
                );
              },
              child: const Text('Planes de entrenamiento'),
            ),
            const SizedBox(height: 28),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Agenda semanal',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: accent),
                  tooltip: 'Actualizar calendario',
                  onPressed: _loadSessions,
                ),
              ],
            ),
            const SizedBox(height: 8),

            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.15),
                ),
                height: 600,
                child: SfCalendar(
                  view: CalendarView.week,
                  firstDayOfWeek: 1,
                  backgroundColor: backgroundSecondary,
                  dataSource: TrainingDataSource(appointments),
                  showDatePickerButton: true,
                  showCurrentTimeIndicator: true,
                  todayHighlightColor: accent,
                  timeSlotViewSettings: const TimeSlotViewSettings(
                    timeTextStyle: TextStyle(color: Colors.white70),
                    timeIntervalHeight: 60,
                    startHour: 0,
                    endHour: 24,
                  ),

                  onTap: (details) async {
                    final tappedDate = details.date;

                    if (details.targetElement == CalendarElement.calendarCell &&
                        tappedDate != null) {
                      final result = await showModalBottomSheet<bool>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: const Color(0xFF111111),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                        ),
                        builder: (_) => AddSessionDialog(
                          initialDate: tappedDate, // <<---- CORREGIDO
                        ),
                      );

                      if (result == true) _loadSessions();
                      return;
                    }

                    if (details.targetElement == CalendarElement.appointment) {
                      final session = details.appointments?.first;
                      if (session is Appointment) {
                        final action = await showModalBottomSheet<String>(
                          context: context,
                          backgroundColor: const Color(0xFF111111),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(16),
                            ),
                          ),
                          builder: (ctx) =>
                              _SessionOptionsSheet(session: session),
                        );

                        if (action == 'deleted' || action == 'updated') {
                          _loadSessions();
                        }
                      }
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: accent,
        onPressed: () async {
          final result = await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            backgroundColor: const Color(0xFF111111),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (_) => AddSessionDialog(
              initialDate:
                  DateTime.now(), // fallback si no viene del calendario
            ),
          );
          if (result == true) _loadSessions();
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class TrainingDataSource extends CalendarDataSource {
  TrainingDataSource(List<Appointment> source) {
    appointments = source;
  }
}

class _SessionOptionsSheet extends StatelessWidget {
  final Appointment session;
  const _SessionOptionsSheet({required this.session});

  @override
  Widget build(BuildContext context) {
    final repo = TrainingSessionsRepo();
    const accent = Color(0xFFBF5AF2);
    const textColor = Color(0xFFD9D9D9);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade600,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.play_arrow, color: Colors.greenAccent),
              title: const Text(
                'Iniciar sesión',
                style: TextStyle(color: textColor),
              ),
              onTap: () async {
                await repo.markSessionStarted(session.id.toString());
                if (context.mounted) Navigator.pop(context, 'updated');
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: accent),
              title: const Text(
                'Editar sesión',
                style: TextStyle(color: textColor),
              ),
              onTap: () async {
                Navigator.pop(context);
                final result = await showModalBottomSheet<bool>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: const Color(0xFF111111),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  builder: (_) => AddSessionDialog(
                    existingSession: session,
                    initialDate: session.startTime,
                  ),
                );

                if (result == true && context.mounted) {
                  final parent = context
                      .findAncestorStateOfType<_CoachHomeScreenState>();
                  parent?._loadSessions();
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.redAccent),
              title: const Text(
                'Eliminar sesión',
                style: TextStyle(color: textColor),
              ),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: const Color(0xFF111111),
                    title: const Text(
                      'Eliminar sesión',
                      style: TextStyle(color: textColor),
                    ),
                    content: const Text(
                      '¿Seguro que deseas eliminar esta sesión?',
                      style: TextStyle(color: Colors.white70),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text(
                          'Cancelar',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text(
                          'Eliminar',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await repo.deleteSession(session.id.toString());
                  if (context.mounted) Navigator.pop(context, 'deleted');
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.close, color: Colors.white54),
              title: const Text('Cancelar', style: TextStyle(color: textColor)),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

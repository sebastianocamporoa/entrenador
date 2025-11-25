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
        startTime: s.startTime,
        endTime: s.endTime,
        subject: s.notes ?? (s.clientName ?? 'Sesión'),
        color: _getColorForClient(s.clientId),
        isAllDay: false,
        notes: s.clientName ?? '',
        location: s.started.toString(), // <<--- guardamos started aquí
        recurrenceId:
            s.clientId, // <<--- guardamos clientId por si lo necesitas
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

    // Determinar el saludo por hora
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = 'Buenos días';
    } else if (hour < 18) {
      greeting = 'Buenas tardes';
    } else {
      greeting = 'Buenas noches';
    }

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
            // 🔹 Encabezado personalizado
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

            // 🔹 Botones principales
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ClientsPage())),
              child: const Text('Ir a Clientes'),
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white10,
                foregroundColor: textColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PlansListScreen()),
              ),
              child: const Text('Planes de entrenamiento'),
            ),
            const SizedBox(height: 28),

            // 🗓️ Calendario semanal
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
                  headerStyle: const CalendarHeaderStyle(
                    textAlign: TextAlign.center,
                    backgroundColor: backgroundSecondary,
                    textStyle: TextStyle(
                      color: Color(0xFFD9D9D9),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  viewHeaderStyle: const ViewHeaderStyle(
                    backgroundColor: backgroundSecondary,
                    dayTextStyle: TextStyle(color: Color(0xFFD9D9D9)),
                    dateTextStyle: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  cellBorderColor: Colors.white10,
                  appointmentTextStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  timeSlotViewSettings: const TimeSlotViewSettings(
                    timeTextStyle: TextStyle(color: Colors.white70),
                    timeIntervalHeight: 60,
                    startHour: 0,
                    endHour: 24,
                  ),
                  onTap: (details) async {
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
            builder: (_) => const AddSessionDialog(),
          );
          if (result == true) {
            _loadSessions();
          }
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1C1C1E),
          border: Border(top: BorderSide(color: Colors.white10, width: 1)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _BottomNavItem(
              icon: Icons.home_rounded,
              selected: true,
              onTap: () {
                // Ya estás en inicio
              },
            ),
            _BottomNavItem(
              icon: Icons.notifications_rounded,
              hasBadge: true,
              onTap: () {
                // Aquí luego abriremos la pantalla de notificaciones
              },
            ),
            _BottomNavItem(
              isProfile: true,
              imageUrl:
                  'https://i.pravatar.cc/150?img=47', // Puedes reemplazarlo con el perfil real del entrenador
              onTap: () {
                // Aquí abriremos el perfil del usuario
              },
            ),
          ],
        ),
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
                  builder: (_) => AddSessionDialog(existingSession: session),
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
                      '¿Seguro que deseas eliminar esta sesión? Esta acción no se puede deshacer.',
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
                  await repo.deleteSession(session.id?.toString() ?? '');
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

class _BottomNavItem extends StatelessWidget {
  final IconData? icon;
  final bool selected;
  final bool hasBadge;
  final VoidCallback onTap;
  final bool isProfile;
  final String? imageUrl;

  const _BottomNavItem({
    this.icon,
    this.selected = false,
    this.hasBadge = false,
    this.isProfile = false,
    this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFBF5AF2);
    const inactive = Colors.grey;
    const active = Colors.white;

    Widget content;

    if (isProfile && imageUrl != null) {
      content = CircleAvatar(
        radius: 18,
        backgroundImage: NetworkImage(imageUrl!),
        backgroundColor: Colors.transparent,
      );
    } else {
      content = Icon(icon, size: 28, color: selected ? active : inactive);
    }

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          content,
          if (hasBadge)
            Positioned(
              right: -1,
              top: -2,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

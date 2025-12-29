import 'dart:io'; // Necesario para manejar archivos
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:intl/intl.dart';

// --- IMPORTANTE: AJUSTA ESTAS RUTAS SEGÚN TU PROYECTO ---
import '../../common/services/diet_service.dart';
import '../../common/data/models/training_session.dart';
import '../../common/data/repositories/training_sessions_repo.dart';

class ClientDetailPage extends StatelessWidget {
  final Map<String, dynamic> client;

  const ClientDetailPage({super.key, required this.client});

  @override
  Widget build(BuildContext context) {
    final c = client;
    const background = Color(0xFF1C1C1E);
    const accent = Color(0xFFBF5AF2);
    const textColor = Color(0xFFD9D9D9);

    return DefaultTabController(
      length: 5, // <--- AHORA SON 5 PESTAÑAS
      child: Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          backgroundColor: background,
          elevation: 0,
          title: Text(
            c['name'] ?? 'Cliente',
            style: const TextStyle(
              color: textColor,
              fontWeight: FontWeight.w700,
              fontSize: 22,
            ),
          ),
          iconTheme: const IconThemeData(color: textColor),
          bottom: const TabBar(
            isScrollable: true,
            indicatorColor: accent,
            labelColor: accent,
            unselectedLabelColor: Colors.white54,
            labelStyle: TextStyle(fontWeight: FontWeight.bold),
            tabs: [
              Tab(text: 'Datos'),
              Tab(text: 'Agenda'),
              Tab(text: 'Asistencia'), // <--- NUEVA PESTAÑA
              Tab(text: 'Progreso'),
              Tab(text: 'Nutrición'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _DatosTab(c: c),
            _AgendaTab(clientId: c['id'], clientName: c['name'] ?? 'Cliente'),
            _AsistenciaTab(
              clientId: c['id'],
              clientName: c['name'] ?? 'Cliente',
            ), // <--- NUEVA PANTALLA
            _ProgresoTab(clientId: c['id']),
            _DietTab(clientId: c['id']),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 1. TAB DE DATOS
// ==========================================
class _DatosTab extends StatelessWidget {
  final Map<String, dynamic> c;
  const _DatosTab({required this.c});

  String _sexLabel(String? s) {
    switch (s) {
      case 'M':
        return 'Masculino';
      case 'F':
        return 'Femenino';
      case 'O':
        return 'Otro';
      default:
        return '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    const cardColor = Color(0xFF2C2C2E);
    const textColor = Color(0xFFD9D9D9);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.purple.withOpacity(0.3),
                child: Text(
                  (c['name'] ?? '?')[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 36,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                c['name'] ?? '—',
                style: const TextStyle(
                  color: textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                c['email'] ?? '',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const Divider(height: 32, color: Colors.white10),
              _Tile(label: 'Teléfono', value: c['phone']),
              _Tile(label: 'Objetivo', value: c['goal']),
              _Tile(label: 'Sexo', value: _sexLabel(c['sex'])),
            ],
          ),
        ),
      ],
    );
  }
}

// ==========================================
// 2. TAB DE AGENDA
// ==========================================
class _AgendaTab extends StatefulWidget {
  final String clientId;
  final String clientName;
  const _AgendaTab({required this.clientId, required this.clientName});

  @override
  State<_AgendaTab> createState() => _AgendaTabState();
}

class _AgendaTabState extends State<_AgendaTab> {
  final _db = Supabase.instance.client;
  Map<int, Map<String, dynamic>> _weeklySchedule = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    try {
      final data = await _db
          .from('client_schedule')
          .select('day_of_week, plan:plan_id(id, name, goal)')
          .eq('client_id', widget.clientId);

      final Map<int, Map<String, dynamic>> tempMap = {};
      for (var item in data) {
        final day = item['day_of_week'] as int;
        final plan = item['plan'] as Map<String, dynamic>;
        tempMap[day] = plan;
      }

      if (mounted) {
        setState(() {
          _weeklySchedule = tempMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _assignPlanToDay(int dayOfWeek) async {
    final authUser = _db.auth.currentUser;
    if (authUser == null) return;

    final coachProfile = await _db
        .from('app_user')
        .select('id')
        .eq('auth_user_id', authUser.id)
        .single();
    final internalCoachId = coachProfile['id'];

    final plans = await _db
        .from('training_plan')
        .select('id, name, goal')
        .or('scope.eq.global,trainer_id.eq.$internalCoachId')
        .order('created_at', ascending: false);

    if (!mounted) return;

    final selectedPlan = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _PlanSelectorSheet(
        plans: List<Map<String, dynamic>>.from(plans),
        dayName: _getDayName(dayOfWeek),
      ),
    );

    if (selectedPlan == null) return;

    try {
      await _db.from('client_schedule').upsert({
        'client_id': widget.clientId,
        'day_of_week': dayOfWeek,
        'plan_id': selectedPlan['id'],
      }, onConflict: 'client_id, day_of_week');

      _loadSchedule();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Rutina asignada')));
      }
    } catch (e) {
      debugPrint('Error asignando: $e');
    }
  }

  Future<void> _clearDay(int dayOfWeek) async {
    try {
      await _db
          .from('client_schedule')
          .delete()
          .eq('client_id', widget.clientId)
          .eq('day_of_week', dayOfWeek);
      _loadSchedule();
    } catch (e) {
      debugPrint('Error borrando dia: $e');
    }
  }

  String _getDayName(int day) {
    const days = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];
    return days[day - 1];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFBF5AF2)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 7,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final dayIndex = index + 1;
        final planData = _weeklySchedule[dayIndex];
        final hasPlan = planData != null;

        return InkWell(
          onTap: () => _assignPlanToDay(dayIndex),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              color: hasPlan
                  ? const Color(0xFFBF5AF2).withOpacity(0.15)
                  : const Color(0xFF2C2C2E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasPlan
                    ? const Color(0xFFBF5AF2).withOpacity(0.5)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: hasPlan
                      ? const Color(0xFFBF5AF2)
                      : Colors.white10,
                  child: Text(
                    _getDayName(dayIndex)[0],
                    style: TextStyle(
                      color: hasPlan ? Colors.white : Colors.white54,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getDayName(dayIndex),
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasPlan ? planData['name'] : 'Descanso / Sin asignar',
                        style: TextStyle(
                          color: hasPlan ? Colors.white : Colors.white38,
                          fontSize: 16,
                          fontWeight: hasPlan
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasPlan)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white38),
                    onPressed: () => _clearDay(dayIndex),
                  )
                else
                  const Icon(Icons.add_circle_outline, color: Colors.white24),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ==========================================
// 3. TAB DE ASISTENCIA (GENERACIÓN PDF)
// ==========================================
class _AsistenciaTab extends StatefulWidget {
  final String clientId;
  final String clientName;

  const _AsistenciaTab({required this.clientId, required this.clientName});

  @override
  State<_AsistenciaTab> createState() => _AsistenciaTabState();
}

class _AsistenciaTabState extends State<_AsistenciaTab> {
  final _repo = TrainingSessionsRepo();
  bool _isLoading = true;
  List<TrainingSession> _sessions = [];

  // Estadísticas
  int _attended = 0;
  int _missed = 0;
  double _percentage = 0.0;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final data = await _repo.getClientHistory(widget.clientId);

      final now = DateTime.now();
      int attendedCount = 0;
      int missedCount = 0;

      // Calcular solo sesiones que ya pasaron
      for (var s in data) {
        // Asistió si tiene started = true
        if (s.started) {
          attendedCount++;
        }
        // Faltó si NO tiene started, y la hora de fin ya pasó
        else if (s.endTime.isBefore(now.toUtc())) {
          missedCount++;
        }
        // Si es a futuro, no cuenta ni como falta ni como asistencia
      }

      final totalEvaluated = attendedCount + missedCount;

      if (mounted) {
        setState(() {
          _sessions = data;
          _attended = attendedCount;
          _missed = missedCount;
          _percentage = totalEvaluated > 0
              ? (attendedCount / totalEvaluated) * 100
              : 0.0;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint('Error cargando historial: $e');
    }
  }

  /// 🖨️ Generar PDF y Abrir con OpenFilex
  Future<void> _generateAndOpenPdf() async {
    final pdf = pw.Document();
    final now = DateTime.now();

    // Filtramos para el reporte: Sesiones pasadas o iniciadas
    final reportSessions = _sessions.where((s) {
      return s.started || s.endTime.isBefore(now.toUtc());
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            // Encabezado
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Reporte de Asistencia',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text('Fecha: ${DateFormat('dd/MM/yyyy').format(now)}'),
                ],
              ),
            ),

            pw.SizedBox(height: 20),

            // Resumen
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _pdfStat('Cliente', widget.clientName),
                  _pdfStat('Efectividad', '${_percentage.toStringAsFixed(1)}%'),
                  _pdfStat('Asistencias', '$_attended', color: PdfColors.green),
                  _pdfStat('Faltas', '$_missed', color: PdfColors.red),
                ],
              ),
            ),

            pw.SizedBox(height: 20),

            // Tabla de datos
            pw.Table.fromTextArray(
              context: context,
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              headers: ['Fecha', 'Hora', 'Nota', 'Estado'],
              data: reportSessions.map((s) {
                final localDate = s.startTime.toLocal();
                final dateStr = DateFormat('dd/MM/yyyy').format(localDate);
                final timeStr = DateFormat('HH:mm').format(localDate);

                String status = 'Ausente';
                if (s.started) status = 'Asistió';

                return [dateStr, timeStr, s.notes ?? '-', status];
              }).toList(),
            ),
          ];
        },
      ),
    );

    try {
      // 1. Obtener directorio temporal
      final output = await getTemporaryDirectory();
      // 2. Crear archivo
      final file = File("${output.path}/asistencia_${widget.clientId}.pdf");
      // 3. Escribir bytes
      await file.writeAsBytes(await pdf.save());
      // 4. Abrir archivo
      await OpenFilex.open(file.path);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al generar PDF: $e')));
      }
    }
  }

  pw.Widget _pdfStat(String label, String value, {PdfColor? color}) {
    return pw.Column(
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: color ?? PdfColors.black,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFBF5AF2)),
      );
    }

    return Column(
      children: [
        // Tarjeta de Resumen Visual en la App
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF2C2C2E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            children: [
              const Text(
                'Efectividad de Asistencia',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Text(
                '${_percentage.toStringAsFixed(1)}%',
                style: const TextStyle(
                  color: Color(0xFFBF5AF2),
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _screenStat('$_attended', 'Asistencias', Colors.greenAccent),
                  Container(width: 1, height: 30, color: Colors.white12),
                  _screenStat('$_missed', 'Faltas', Colors.redAccent),
                ],
              ),
            ],
          ),
        ),

        const Divider(color: Colors.white10),

        // Lista Historial
        Expanded(
          child: _sessions.isEmpty
              ? const Center(
                  child: Text(
                    'No hay historial',
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _sessions.length,
                  itemBuilder: (ctx, i) {
                    final s = _sessions[i];
                    final localDate = s.startTime.toLocal();
                    final now = DateTime.now();

                    // Lógica visual
                    bool isPast = s.endTime.isBefore(now.toUtc());
                    Color statusColor = Colors.grey;
                    String statusText = "Pendiente";
                    IconData icon = Icons.access_time;

                    if (s.started) {
                      statusColor = Colors.green;
                      statusText = "Asistió";
                      icon = Icons.check_circle;
                    } else if (isPast) {
                      statusColor = Colors.redAccent;
                      statusText = "Ausente";
                      icon = Icons.cancel;
                    }

                    return Card(
                      color: Colors.white10,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(icon, color: statusColor),
                        title: Text(
                          DateFormat('EEE d MMM', 'es_ES').format(localDate),
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          DateFormat('HH:mm').format(localDate),
                          style: const TextStyle(color: Colors.white54),
                        ),
                        trailing: Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Botón PDF
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFBF5AF2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _generateAndOpenPdf,
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('DESCARGAR REPORTE PDF'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _screenStat(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }
}

// ==========================================
// 4. TAB DE PROGRESO (CON VISOR DE FOTOS)
// ==========================================
class _ProgresoTab extends StatefulWidget {
  final String clientId;
  const _ProgresoTab({required this.clientId});

  @override
  State<_ProgresoTab> createState() => _ProgresoTabState();
}

class _ProgresoTabState extends State<_ProgresoTab> {
  final _supa = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _history = [];

  double? _startWeight;
  double? _currentWeight;
  double? _totalChange;

  @override
  void initState() {
    super.initState();
    _loadProgressHistory();
  }

  Future<void> _loadProgressHistory() async {
    try {
      final data = await _supa
          .from('measurements')
          .select('id, weight_kg, height_cm, notes, date_at')
          .eq('client_id', widget.clientId)
          .order('date_at', ascending: false);

      if (mounted) {
        setState(() {
          _history = List<Map<String, dynamic>>.from(data);

          if (_history.isNotEmpty) {
            _currentWeight = _history.first['weight_kg'];
            _startWeight = _history.last['weight_kg'];
            _totalChange = (_currentWeight! - _startWeight!);
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showPhotosModal(String measurementId, String dateStr) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) =>
          _PhotosSheet(measurementId: measurementId, dateLabel: dateStr),
    );
  }

  String _formatDate(String isoString) {
    final date = DateTime.parse(isoString);
    return "${date.day}/${date.month}/${date.year}";
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFBF5AF2)),
      );
    }

    if (_history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.analytics_outlined,
              size: 60,
              color: Colors.white24,
            ),
            const SizedBox(height: 16),
            const Text(
              'Aún no hay registros de progreso',
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildSummaryCard(),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _history.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = _history[index];
              final dateStr = _formatDate(item['date_at']);
              final weight = item['weight_kg'];
              final notes = item['notes'] ?? '';

              return Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFBF5AF2).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.scale,
                      color: Color(0xFFBF5AF2),
                      size: 20,
                    ),
                  ),
                  title: Text(
                    '$weight kg',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        dateStr,
                        style: const TextStyle(color: Colors.white54),
                      ),
                      if (notes.isNotEmpty)
                        Text(
                          notes,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white30,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                  trailing: TextButton.icon(
                    onPressed: () => _showPhotosModal(item['id'], dateStr),
                    icon: const Icon(Icons.photo_library, size: 18),
                    label: const Text('Fotos'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFBF5AF2),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    if (_startWeight == null || _currentWeight == null)
      return const SizedBox.shrink();

    final isLoss = _totalChange! < 0;
    final color = isLoss ? Colors.greenAccent : Colors.redAccent;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFBF5AF2).withOpacity(0.2),
            const Color(0xFF1C1C1E),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStatItem('Inicio', '$_startWeight kg'),
          Container(width: 1, height: 40, color: Colors.white12),
          _buildStatItem('Actual', '$_currentWeight kg'),
          Container(width: 1, height: 40, color: Colors.white12),
          _buildStatItem(
            'Cambio',
            '${_totalChange! > 0 ? '+' : ''}${_totalChange!.toStringAsFixed(1)} kg',
            valueColor: color,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, {Color? valueColor}) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}

// ==========================================
// 5. TAB DE NUTRICIÓN
// ==========================================
class _DietTab extends StatefulWidget {
  final String clientId;
  const _DietTab({required this.clientId});

  @override
  State<_DietTab> createState() => _DietTabState();
}

class _DietTabState extends State<_DietTab> {
  final _supa = Supabase.instance.client;
  final _dietService = DietService();

  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _activityCtrl = TextEditingController();
  final _goalCtrl = TextEditingController();

  bool _isLoading = false;
  bool _hasExistingDiet = false;
  String? _lastDietDate;

  @override
  void initState() {
    super.initState();
    _loadClientDataAndDiet();
  }

  Future<void> _loadClientDataAndDiet() async {
    setState(() => _isLoading = true);
    try {
      final dietRes = await _supa
          .from('diet_plans')
          .select('created_at')
          .eq('client_id', widget.clientId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      final measureRes = await _supa
          .from('measurements')
          .select('weight_kg, height_cm')
          .eq('client_id', widget.clientId)
          .order('date_at', ascending: false)
          .limit(1)
          .maybeSingle();

      final clientRes = await _supa
          .from('clients')
          .select('goal')
          .eq('id', widget.clientId)
          .single();

      if (mounted) {
        setState(() {
          _hasExistingDiet = dietRes != null;
          if (dietRes != null) {
            final date = DateTime.parse(dietRes['created_at']);
            _lastDietDate = "${date.day}/${date.month}/${date.year}";
          }

          if (measureRes != null) {
            _weightCtrl.text = measureRes['weight_kg'].toString();
            _heightCtrl.text = measureRes['height_cm'].toString();
          }

          _goalCtrl.text = clientRes['goal'] ?? 'Mejorar composición corporal';
          _ageCtrl.text = '25';
          _activityCtrl.text = 'Sedentario/Oficina';

          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando datos dieta: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _generateDiet() async {
    if (_weightCtrl.text.isEmpty ||
        _heightCtrl.text.isEmpty ||
        _ageCtrl.text.isEmpty ||
        _activityCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa todos los campos')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final photosRes = await _supa
          .from('progress_photos')
          .select('url')
          .eq('client_id', widget.clientId)
          .order('taken_at', ascending: false)
          .limit(4);

      List<String> photoUrls = List<String>.from(
        (photosRes as List).map((item) => item['url']),
      );

      await _dietService.generateAndSaveDiet(
        clientId: widget.clientId,
        currentWeight: double.parse(_weightCtrl.text),
        height: double.parse(_heightCtrl.text),
        age: int.parse(_ageCtrl.text),
        activity: _activityCtrl.text,
        goal: _goalCtrl.text,
        photoUrls: photoUrls,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Plan "NutriMaster" generado!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadClientDataAndDiet();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openDiet() async {
    setState(() => _isLoading = true);
    try {
      await _dietService.openLastDiet(widget.clientId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al abrir: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFBF5AF2)),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _hasExistingDiet
                  ? const Color(0xFF2C2C2E)
                  : Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _hasExistingDiet
                    ? Colors.transparent
                    : Colors.orange.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _hasExistingDiet
                      ? Icons.check_circle
                      : Icons.warning_amber_rounded,
                  color: _hasExistingDiet ? Colors.greenAccent : Colors.orange,
                  size: 30,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _hasExistingDiet ? 'Plan Activo' : 'Sin Plan Asignado',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (_hasExistingDiet)
                        Text(
                          'Creado el: $_lastDietDate',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                if (_hasExistingDiet)
                  IconButton(
                    onPressed: _openDiet,
                    icon: const Icon(
                      Icons.visibility,
                      color: Color(0xFFBF5AF2),
                    ),
                    tooltip: 'Ver PDF',
                  ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          const Divider(color: Colors.white10),
          const SizedBox(height: 20),

          const Text(
            "Generar Plan NutriMaster",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "La IA analizará fotos, somatotipo y datos.",
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: _buildInput(
                  _weightCtrl,
                  'Peso (kg)',
                  Icons.monitor_weight,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInput(_heightCtrl, 'Altura (cm)', Icons.height),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildInput(_ageCtrl, 'Edad (años)', Icons.cake),
          const SizedBox(height: 16),
          _buildInput(
            _activityCtrl,
            'Actividad (Ej: Oficina)',
            Icons.work_outline,
          ),
          const SizedBox(height: 16),
          _buildInput(_goalCtrl, 'Objetivo del ciclo', Icons.flag),

          const SizedBox(height: 30),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _generateDiet,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFBF5AF2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.auto_awesome),
              label: Text(
                _hasExistingDiet
                    ? "REGENERAR PLAN CON IA"
                    : "CREAR PLAN CON IA",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput(TextEditingController ctrl, String label, IconData icon) {
    TextInputType type = TextInputType.text;
    if (label.contains('Peso') ||
        label.contains('Altura') ||
        label.contains('Edad')) {
      type = TextInputType.number;
    }

    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: const Color(0xFFBF5AF2)),
        filled: true,
        fillColor: const Color(0xFF2C2C2E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

// ==========================================
// WIDGETS AUXILIARES
// ==========================================
class _Tile extends StatelessWidget {
  final String label;
  final String? value;
  const _Tile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 14),
          ),
          Text(
            value == null || value!.isEmpty ? '—' : value!,
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class _PlanSelectorSheet extends StatelessWidget {
  final List<Map<String, dynamic>> plans;
  final String dayName;

  const _PlanSelectorSheet({required this.plans, required this.dayName});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.6,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Rutina para el $dayName',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: plans.length,
                itemBuilder: (_, i) {
                  final p = plans[i];
                  return ListTile(
                    title: Text(
                      p['name'],
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      p['goal'] ?? '',
                      style: const TextStyle(color: Colors.white54),
                    ),
                    leading: const Icon(
                      Icons.fitness_center,
                      color: Color(0xFFBF5AF2),
                    ),
                    onTap: () => Navigator.pop(context, p),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ========================================================
// VISOR DE FOTOS PARA PROGRESO (GRID + PANTALLA COMPLETA)
// ========================================================
class _PhotosSheet extends StatefulWidget {
  final String measurementId;
  final String dateLabel;

  const _PhotosSheet({required this.measurementId, required this.dateLabel});

  @override
  State<_PhotosSheet> createState() => _PhotosSheetState();
}

class _PhotosSheetState extends State<_PhotosSheet> {
  final _supa = Supabase.instance.client;
  bool _isLoading = true;
  Map<String, String> _photos = {};

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    try {
      final data = await _supa
          .from('progress_photos')
          .select('kind, url')
          .eq('measurement_id', widget.measurementId);

      final Map<String, String> temp = {};
      for (var item in data) {
        temp[item['kind']] = item['url'];
      }

      if (mounted) {
        setState(() {
          _photos = temp;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Registro del ${widget.dateLabel}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          if (_isLoading)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFFBF5AF2)),
              ),
            )
          else if (_photos.isEmpty)
            const Expanded(
              child: Center(
                child: Text(
                  'Sin fotos adjuntas en este registro',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            )
          else
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.7,
                children: [
                  _buildPhotoCard('Frente', _photos['front']),
                  _buildPhotoCard('Espalda', _photos['back']),
                  _buildPhotoCard('Perfil Izq', _photos['left']),
                  _buildPhotoCard('Perfil Der', _photos['right']),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPhotoCard(String label, String? url) {
    return GestureDetector(
      onTap: () {
        if (url != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FullScreenImageView(imageUrl: url),
            ),
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black38,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (url != null)
                Hero(
                  tag: url, // Importante para la animación suave
                  child: Image.network(url, fit: BoxFit.cover),
                )
              else
                const Center(
                  child: Icon(
                    Icons.no_photography,
                    color: Colors.white10,
                    size: 40,
                  ),
                ),

              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  color: Colors.black54,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// PANTALLA COMPLETA CON ZOOM
// ==========================================
class FullScreenImageView extends StatelessWidget {
  final String imageUrl;
  const FullScreenImageView({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true, // Permitir mover
          minScale: 0.5,
          maxScale: 4.0, // Zoom hasta 4x
          child: Hero(tag: imageUrl, child: Image.network(imageUrl)),
        ),
      ),
    );
  }
}

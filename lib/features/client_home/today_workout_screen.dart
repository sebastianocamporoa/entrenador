import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fl_chart/fl_chart.dart'; // 🔥 NUEVO: Para la gráfica
import 'package:intl/intl.dart';

// Asegúrate de que la ruta sea correcta
import '../../common/data/repositories/assignments_repo.dart';

class TodayWorkoutScreen extends StatefulWidget {
  const TodayWorkoutScreen({super.key});

  @override
  State<TodayWorkoutScreen> createState() => _TodayWorkoutScreenState();
}

class _TodayWorkoutScreenState extends State<TodayWorkoutScreen> {
  final _repo = AssignmentsRepo();
  late Future<List<Map<String, dynamic>>> _future;

  // Variables para el Cronómetro (Tu lógica original intacta)
  Timer? _timer;
  int _totalRestSeconds = 0;
  int _remainingSeconds = 0;
  bool _isTimerActive = false;

  @override
  void initState() {
    super.initState();
    _future = _repo.todayWorkoutForClient();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // --- LÓGICA DEL CRONÓMETRO (Tu código original) ---
  void _startRestTimer(int seconds) {
    _timer?.cancel();
    setState(() {
      _totalRestSeconds = seconds;
      _remainingSeconds = seconds;
      _isTimerActive = true;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        _stopTimer();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Theme.of(context).primaryColor,
              content: const Text(
                '¡A DARLE DURO!',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() {
      _isTimerActive = false;
      _remainingSeconds = 0;
    });
  }

  void _addTime(int seconds) {
    setState(() {
      _remainingSeconds += seconds;
      if (_remainingSeconds > _totalRestSeconds)
        _totalRestSeconds = _remainingSeconds;
    });
  }

  String _formatTime(int totalSeconds) {
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // --- UI PRINCIPAL ---
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final backgroundColor = theme.scaffoldBackgroundColor;
    final onSurfaceColor = theme.colorScheme.onSurface;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'HOY TOCA',
              style: TextStyle(
                color: primaryColor,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            Text(
              'Entrenamiento',
              style: TextStyle(
                color: onSurfaceColor,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          // Fondo decorativo (Tu diseño)
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor.withOpacity(0.05),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.1),
                    blurRadius: 100,
                    spreadRadius: 10,
                  ),
                ],
              ),
            ),
          ),

          FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (_, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return Center(
                  child: CircularProgressIndicator(color: primaryColor),
                );
              }
              if (snap.hasError)
                return Center(child: Text('Error: ${snap.error}'));

              final items = snap.data ?? [];
              if (items.isEmpty)
                return const Center(child: Text("Descanso hoy."));

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (_, i) {
                  final exercise = items[i];
                  // 🔥 CAMBIO: Usamos el Widget Extraído
                  return ExerciseCardItem(
                    data: exercise,
                    index: i + 1,
                    onTimerRequested: (seconds) => _startRestTimer(seconds),
                  );
                },
              );
            },
          ),

          // PANEL DEL TIMER
          if (_isTimerActive)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildTimerPanel(theme),
            ),
        ],
      ),
    );
  }

  // --- Widget del Panel del Timer (Copiado de tu código) ---
  Widget _buildTimerPanel(ThemeData theme) {
    final primaryColor = theme.primaryColor;
    final surfaceColor = theme.colorScheme.surface;
    final onSurfaceColor = theme.colorScheme.onSurface;
    double progress = _totalRestSeconds > 0
        ? _remainingSeconds / _totalRestSeconds
        : 0;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: surfaceColor.withOpacity(0.95),
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'DESCANSO',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      letterSpacing: 2,
                    ),
                  ),
                  IconButton(
                    onPressed: _stopTimer,
                    icon: const Icon(Icons.close, color: Colors.white54),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 100,
                    height: 100,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 8,
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                      backgroundColor: Colors.white10,
                    ),
                  ),
                  Text(
                    _formatTime(_remainingSeconds),
                    style: TextStyle(
                      color: onSurfaceColor,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => _addTime(-10),
                    child: const Text(
                      '-10s',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 20),
                  TextButton(
                    onPressed: () => _addTime(10),
                    child: const Text(
                      '+10s',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 🔥 NUEVO WIDGET: Tarjeta de Ejercicio Inteligente
// Maneja el input de peso y la visualización de la gráfica
// ---------------------------------------------------------------------------
class ExerciseCardItem extends StatefulWidget {
  final Map<String, dynamic> data;
  final int index;
  final Function(int) onTimerRequested;

  const ExerciseCardItem({
    super.key,
    required this.data,
    required this.index,
    required this.onTimerRequested,
  });

  @override
  State<ExerciseCardItem> createState() => _ExerciseCardItemState();
}

class _ExerciseCardItemState extends State<ExerciseCardItem> {
  final _repo = AssignmentsRepo();
  final _weightCtrl = TextEditingController();
  final Color _tiktokCyan = const Color(0xFF00F2EA);
  bool _isSaving = false;

  @override
  void dispose() {
    _weightCtrl.dispose();
    super.dispose();
  }

  // --- Guardar Peso ---
  Future<void> _saveWeight() async {
    final text = _weightCtrl.text.trim();
    if (text.isEmpty) return;

    final weight = double.tryParse(text);
    if (weight == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ingresa un número válido')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final name = widget.data['name'] ?? 'Ejercicio';
      await _repo.logExerciseWeight(name, weight); // Usamos la función del repo

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Peso guardado ✅')));
        _weightCtrl.clear();
        FocusScope.of(context).unfocus(); // Cerrar teclado
      }
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // --- Mostrar Gráfica ---
  void _showGraph() {
    final name = widget.data['name'] ?? 'Ejercicio';

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      isScrollControlled: true, // Para que ocupe más espacio si es necesario
      builder: (ctx) => _ExerciseHistoryChart(exerciseName: name),
    );
  }

  // --- Lanzar Video (Tu lógica original) ---
  Future<void> _launchVideo(String? urlString) async {
    if (urlString == null || urlString.isEmpty) return;
    final Uri url = Uri.parse(urlString);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('No se pudo lanzar la URL');
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = widget.data['name'] ?? 'Ejercicio';
    final muscleGroup = widget.data['muscle_group'] ?? 'General';
    final sets = widget.data['sets'] ?? 0;
    final reps = widget.data['repetitions'] ?? 0;
    final restSeconds = widget.data['rest_seconds'] ?? 60;
    final notes = widget.data['notes'];
    final videoUrl = widget.data['video_url'];

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // CABECERA (Nombre y Video)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Text(
                    '#${widget.index}',
                    style: TextStyle(
                      color: theme.primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.toString().toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        muscleGroup.toString().toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (videoUrl != null && videoUrl.toString().isNotEmpty)
                  InkWell(
                    onTap: () => _launchVideo(videoUrl),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _tiktokCyan.withOpacity(0.5)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.play_arrow, color: _tiktokCyan, size: 16),
                          const SizedBox(width: 4),
                          const Text(
                            "VER",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          Divider(color: Colors.white.withOpacity(0.05), height: 1),

          // DATOS DEL EJERCICIO Y BOTÓN TIMER
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
            child: Row(
              children: [
                _buildStatBox('SERIES', '$sets', Icons.layers),
                const SizedBox(width: 12),
                _buildStatBox('REPS', '$reps', Icons.bolt),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () => widget.onTimerRequested(restSeconds),
                  icon: const Icon(Icons.timer_outlined, size: 18),
                  label: Text('${restSeconds}s'),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: Colors.white10,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // 🔥 NUEVO: INPUT DE PESO Y BOTÓN DE GRÁFICA
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.black26, // Fondo más oscurito
            child: Row(
              children: [
                // Campo de Texto
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: TextField(
                      controller: _weightCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Peso usado (kg/lbs)',
                        hintStyle: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 0,
                        ),
                        fillColor: theme.scaffoldBackgroundColor,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Botón Guardar
                IconButton(
                  onPressed: _isSaving ? null : _saveWeight,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(
                          Icons.check_circle,
                          color: Colors.greenAccent,
                        ),
                  tooltip: 'Guardar peso',
                ),

                // Botón Gráfica
                Container(
                  width: 1,
                  height: 24,
                  color: Colors.white10,
                ), // Separador
                IconButton(
                  onPressed: _showGraph,
                  icon: const Icon(Icons.show_chart, color: Color(0xFFBF5AF2)),
                  tooltip: 'Ver progreso',
                ),
              ],
            ),
          ),

          // NOTAS
          if (notes != null && notes.toString().isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
              ),
              child: Text(
                notes,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatBox(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: Colors.white54),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 🔥 NUEVO WIDGET: El BottomSheet con la Gráfica
// ---------------------------------------------------------------------------
class _ExerciseHistoryChart extends StatelessWidget {
  final String exerciseName;
  final _repo = AssignmentsRepo();

  _ExerciseHistoryChart({required this.exerciseName});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400, // Altura del modal
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Progreso: $exerciseName',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Evolución de carga en el tiempo',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 30),

          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _repo.getExerciseHistory(exerciseName),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting)
                  return const Center(child: CircularProgressIndicator());

                final history = snap.data ?? [];
                if (history.isEmpty || history.length < 2) {
                  return const Center(
                    child: Text(
                      'Guarda al menos 2 registros para ver tu evolución 📈',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white38),
                    ),
                  );
                }

                // Preparar datos para el gráfico
                // Eje X: índice (0, 1, 2...)
                // Eje Y: peso
                List<FlSpot> spots = [];
                for (int i = 0; i < history.length; i++) {
                  final weight = (history[i]['weight'] as num).toDouble();
                  spots.add(FlSpot(i.toDouble(), weight));
                }

                return LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) =>
                          FlLine(color: Colors.white10, strokeWidth: 1),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 1, // Mostrar cada punto si no son muchos
                          getTitlesWidget: (val, meta) {
                            int index = val.toInt();
                            if (index >= 0 && index < history.length) {
                              // Mostrar fecha corta (ej: 25 Dic)
                              final dateStr =
                                  history[index]['created_at'] as String;
                              final date = DateTime.parse(dateStr).toLocal();
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  DateFormat('d/M').format(date),
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 10,
                                  ),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: const Color(0xFFBF5AF2),
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          color: const Color(0xFFBF5AF2).withOpacity(0.1),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

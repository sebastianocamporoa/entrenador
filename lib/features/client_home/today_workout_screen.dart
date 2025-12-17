import 'dart:async';
import 'dart:ui'; // Necesario para el efecto Blur
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../common/data/repositories/assignments_repo.dart';

class TodayWorkoutScreen extends StatefulWidget {
  const TodayWorkoutScreen({super.key});

  @override
  State<TodayWorkoutScreen> createState() => _TodayWorkoutScreenState();
}

class _TodayWorkoutScreenState extends State<TodayWorkoutScreen> {
  final _repo = AssignmentsRepo();
  late Future<List<Map<String, dynamic>>> _future;

  // Variables para el Cronómetro
  Timer? _timer;
  int _totalRestSeconds = 0;
  int _remainingSeconds = 0;
  bool _isTimerActive = false;

  // Color fijo para la marca TikTok (siempre es cian)
  final Color _tiktokCyan = const Color(0xFF00F2EA);

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

  // --- LÓGICA DE VIDEO (TIKTOK) ---
  Future<void> _launchVideo(String? urlString) async {
    if (urlString == null || urlString.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay video adjunto a este ejercicio')),
      );
      return;
    }

    final Uri url = Uri.parse(urlString);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('No se pudo lanzar la URL');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Theme.of(context).colorScheme.error,
            content: Text('Error: $e'),
          ),
        );
      }
    }
  }

  // --- LÓGICA DEL CRONÓMETRO ---
  void _startRestTimer(int seconds) {
    _timer?.cancel();
    setState(() {
      _totalRestSeconds = seconds;
      _remainingSeconds = seconds;
      _isTimerActive = true;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _stopTimer();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Theme.of(context).primaryColor,
              content: const Text(
                '¡A DARLE DURO!',
                style: TextStyle(
                  color:
                      Colors.white, // O color negro si tu primary es muy claro
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
      if (_remainingSeconds > _totalRestSeconds) {
        _totalRestSeconds = _remainingSeconds;
      }
    });
  }

  String _formatTime(int totalSeconds) {
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    // AQUÍ ES DONDE TOMAMOS TUS COLORES REALES
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final backgroundColor = theme.scaffoldBackgroundColor;
    final surfaceColor = theme.colorScheme.surface;
    final onSurfaceColor = theme.colorScheme.onSurface; // Tu color D9D9D9

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        // El AppBar tomará automáticamente los estilos de tu Theme
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
          // Fondo decorativo sutil (Usa tu primaryColor con opacidad)
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

          // LISTA DE EJERCICIOS
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (_, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return Center(
                  child: CircularProgressIndicator(color: primaryColor),
                );
              }
              if (snap.hasError) {
                return const Center(
                  child: Text(
                    'Error al cargar',
                    style: TextStyle(color: Colors.white54),
                  ),
                );
              }

              final items = snap.data ?? [];

              if (items.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.fitness_center_outlined,
                          size: 60,
                          color: Colors.white24,
                        ),
                        SizedBox(height: 20),
                        Text(
                          'Sin ejercicios asignados',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 18, color: Colors.white54),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 10,
                  bottom: 120, // Espacio para el timer
                ),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (_, i) {
                  final exercise = items[i];
                  return _buildExerciseCard(exercise, i + 1, theme);
                },
              );
            },
          ),

          // PANEL DEL TIMER (Overlay)
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

  // --- DISEÑO DE TARJETA ---
  Widget _buildExerciseCard(
    Map<String, dynamic> data,
    int index,
    ThemeData theme,
  ) {
    final name = data['name'] ?? 'Ejercicio';
    final muscleGroup = data['muscle_group'] ?? 'General';
    final sets = data['sets'] ?? 0;
    final reps = data['repetitions'] ?? 0;
    final restSeconds = data['rest_seconds'] ?? 60;
    final notes = data['notes'];
    final videoUrl = data['video_url'];

    final primaryColor = theme.primaryColor;
    final surfaceColor = theme.colorScheme.surface;
    final onSurfaceColor = theme.colorScheme.onSurface;
    final scaffoldBg = theme.scaffoldBackgroundColor;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
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
          // Header de la tarjeta
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badge #
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: scaffoldBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Text(
                    '#$index',
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Textos
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.toString().toUpperCase(),
                        style: TextStyle(
                          color: onSurfaceColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
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

                // BOTÓN TIKTOK
                if (videoUrl != null && videoUrl.toString().isNotEmpty)
                  InkWell(
                    onTap: () => _launchVideo(videoUrl),
                    borderRadius: BorderRadius.circular(50),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24),
                        boxShadow: [
                          BoxShadow(
                            color: _tiktokCyan.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_arrow, color: _tiktokCyan, size: 18),
                          const SizedBox(width: 4),
                          const Text(
                            "VER DEMO",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
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

          // Stats (Series/Reps)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                _buildStatBox('SERIES', '$sets', Icons.layers, onSurfaceColor),
                const SizedBox(width: 12),
                _buildStatBox('REPS', '$reps', Icons.bolt, onSurfaceColor),
                const Spacer(),

                // Botón descanso (Usa el estilo del tema)
                FilledButton.icon(
                  onPressed: () => _startRestTimer(restSeconds),
                  icon: const Icon(Icons.timer_outlined, size: 20),
                  label: Text(
                    '${restSeconds}s',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  // Nota: El estilo ya viene definido en tu theme (FilledButtonThemeData)
                  // pero si quieres forzar el icono negro:
                  style: FilledButton.styleFrom(
                    foregroundColor:
                        Colors.white, // O Colors.black según tu prefieras
                  ),
                ),
              ],
            ),
          ),

          // Notas
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
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.white54,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
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
            ),
        ],
      ),
    );
  }

  Widget _buildStatBox(
    String label,
    String value,
    IconData icon,
    Color textColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.white54),
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
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // --- PANEL TIMER ---
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DESCANSO',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Recupérate',
                        style: TextStyle(
                          color: onSurfaceColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
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
                    width: 120,
                    height: 120,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 8,
                      backgroundColor: Colors.white10,
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    ),
                  ),
                  Text(
                    _formatTime(_remainingSeconds),
                    style: TextStyle(
                      color: onSurfaceColor,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildTimeControlBtn('-10s', () => _addTime(-10)),
                  const SizedBox(width: 20),

                  FilledButton(
                    onPressed: _stopTimer,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.redAccent.withOpacity(0.2),
                      foregroundColor: Colors.redAccent,
                    ),
                    child: const Text(
                      'SALTAR',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),

                  const SizedBox(width: 20),
                  _buildTimeControlBtn('+10s', () => _addTime(10)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeControlBtn(String label, VoidCallback onTap) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white54,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        side: BorderSide(color: Colors.white.withOpacity(0.1)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(label),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// --- IMPORTANTE: AJUSTA ESTA RUTA A DONDE TENGAS TU SERVICIO ---
import '../../common/services/diet_service.dart';

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
      length: 4,
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
              Tab(text: 'Agenda Semanal'),
              Tab(text: 'Progreso'),
              Tab(text: 'Nutrición'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _DatosTab(c: c),
            _AgendaTab(clientId: c['id'], clientName: c['name'] ?? 'Cliente'),
            _ProgresoTab(clientId: c['id']),
            _DietTab(clientId: c['id']), // Widget actualizado abajo
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 1. TAB DE DATOS (Info General)
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
// 2. TAB DE AGENDA (Asignar Rutinas)
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
      debugPrint('Error cargando agenda: $e');
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rutina asignada correctamente')),
        );
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
                          letterSpacing: 1,
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
// 3. TAB DE NUTRICIÓN (ACTUALIZADO: "NutriMaster")
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

  // Controladores
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _ageCtrl = TextEditingController(); // NUEVO: Edad
  final _activityCtrl = TextEditingController(); // NUEVO: Actividad
  final _goalCtrl = TextEditingController();

  bool _isLoading = false;
  bool _hasExistingDiet = false;
  String? _lastDietDate;

  @override
  void initState() {
    super.initState();
    _loadClientDataAndDiet();
  }

  // Carga si ya tiene dieta y sus últimos datos físicos
  Future<void> _loadClientDataAndDiet() async {
    setState(() => _isLoading = true);
    try {
      // 1. Buscar última dieta
      final dietRes = await _supa
          .from('diet_plans')
          .select('created_at')
          .eq('client_id', widget.clientId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      // 2. Buscar datos físicos recientes
      final measureRes = await _supa
          .from('measurements')
          .select('weight_kg, height_cm')
          .eq('client_id', widget.clientId)
          .order('date_at', ascending: false)
          .limit(1)
          .maybeSingle();

      // 3. Buscar objetivo del cliente
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

          // Valores por defecto para agilizar
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

  // Generar dieta con IA (NutriMaster)
  Future<void> _generateDiet() async {
    // Validaciones
    if (_weightCtrl.text.isEmpty ||
        _heightCtrl.text.isEmpty ||
        _ageCtrl.text.isEmpty ||
        _activityCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Por favor completa todos los campos (Peso, Altura, Edad, Actividad)',
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Obtener fotos recientes del cliente
      final photosRes = await _supa
          .from('progress_photos')
          .select('url')
          .eq('client_id', widget.clientId)
          .order('taken_at', ascending: false)
          .limit(4);

      List<String> photoUrls = List<String>.from(
        (photosRes as List).map((item) => item['url']),
      );

      // 2. Llamar al servicio enviando los NUEVOS campos
      await _dietService.generateAndSaveDiet(
        clientId: widget.clientId,
        currentWeight: double.parse(_weightCtrl.text),
        height: double.parse(_heightCtrl.text),
        age: int.parse(_ageCtrl.text), // <--- NUEVO
        activity: _activityCtrl.text, // <--- NUEVO
        goal: _goalCtrl.text,
        photoUrls: photoUrls,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Plan "NutriMaster" generado con éxito!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadClientDataAndDiet(); // Recargar UI
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

  // Ver dieta existente
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
          // Tarjeta de Estado
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

          // Formulario Generador
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
            "La IA analizará fotos, somatotipo y datos para crear 2 menús.",
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 20),

          // FILA 1: Peso y Altura
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

          // FILA 2: Edad (NUEVO)
          _buildInput(_ageCtrl, 'Edad (años)', Icons.cake),
          const SizedBox(height: 16),

          // FILA 3: Actividad (NUEVO)
          _buildInput(
            _activityCtrl,
            'Actividad (Ej: Oficina, Construcción)',
            Icons.work_outline,
          ),
          const SizedBox(height: 16),

          // FILA 4: Objetivo
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
    // Definimos qué teclado usar según el campo
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
// 4. TAB DE PROGRESO (PLACEHOLDER)
// ==========================================
class _ProgresoTab extends StatelessWidget {
  final String clientId;
  const _ProgresoTab({required this.clientId});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Gráficas de progreso aquí...',
        style: TextStyle(color: Colors.white54),
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

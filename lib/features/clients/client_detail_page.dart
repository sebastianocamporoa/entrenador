import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      length: 3,
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
            indicatorColor: accent,
            labelColor: accent,
            unselectedLabelColor: Colors.white54,
            labelStyle: TextStyle(fontWeight: FontWeight.bold),
            tabs: [
              Tab(text: 'Datos'),
              Tab(text: 'Agenda Semanal'), // Nombre actualizado
              Tab(text: 'Progreso'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _DatosTab(c: c),
            _AgendaTab(
              clientId: c['id'],
              clientName: c['name'] ?? 'Cliente',
            ), // Nuevo Widget
            _ProgresoTab(clientId: c['id']),
          ],
        ),
      ),
    );
  }
}

// --- TAB DE DATOS (Igual que antes) ---
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

// --- NUEVO: TAB DE AGENDA SEMANAL ---
class _AgendaTab extends StatefulWidget {
  final String clientId;
  final String clientName;
  const _AgendaTab({required this.clientId, required this.clientName});

  @override
  State<_AgendaTab> createState() => _AgendaTabState();
}

class _AgendaTabState extends State<_AgendaTab> {
  final _db = Supabase.instance.client;

  // Mapa para guardar qué plan toca cada día. Key = int (1-7), Value = Plan Data
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

    // 1. Obtener ID interno del coach
    final coachProfile = await _db
        .from('app_user')
        .select('id')
        .eq('auth_user_id', authUser.id)
        .single();
    final internalCoachId = coachProfile['id'];

    // 2. Traer planes disponibles
    final plans = await _db
        .from('training_plan')
        .select('id, name, goal')
        .or('scope.eq.global,trainer_id.eq.$internalCoachId')
        .order('created_at', ascending: false);

    if (!mounted) return;

    // 3. Mostrar selector
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

    // 4. Guardar en BD (Upsert: Si existe actualiza, si no crea)
    try {
      await _db.from('client_schedule').upsert({
        'client_id': widget.clientId,
        'day_of_week': dayOfWeek,
        'plan_id': selectedPlan['id'],
      }, onConflict: 'client_id, day_of_week'); // Clave única compuesta

      _loadSchedule(); // Recargar UI

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
        final dayIndex = index + 1; // 1 a 7
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
                // Círculo con inicial del día
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

                // Texto del Plan
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

                // Icono de acción
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

// --- SHEET PARA SELECCIONAR PLAN (Simplificado) ---
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

class _ProgresoTab extends StatelessWidget {
  final String clientId;
  const _ProgresoTab({required this.clientId});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Progreso...', style: TextStyle(color: Colors.white54)),
    );
  }
}

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

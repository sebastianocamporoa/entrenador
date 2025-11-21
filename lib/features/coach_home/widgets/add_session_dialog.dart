import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import '../../../common/data/repositories/training_sessions_repo.dart';
import '../../../common/data/models/training_session.dart';

class AddSessionDialog extends StatefulWidget {
  final Appointment? existingSession; // Para edición opcional
  const AddSessionDialog({super.key, this.existingSession});

  @override
  State<AddSessionDialog> createState() => _AddSessionDialogState();
}

class _AddSessionDialogState extends State<AddSessionDialog> {
  final _repo = TrainingSessionsRepo();
  final _formKey = GlobalKey<FormState>();
  final supa = Supabase.instance.client;

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);
  final _noteCtrl = TextEditingController();

  bool _saving = false;
  String? _selectedClient;
  List<Map<String, dynamic>> _clients = [];

  String? _timeError;
  final Map<String, bool> _days = {
    'L': false,
    'M': false,
    'X': false,
    'J': false,
    'V': false,
    'S': false,
    'D': false,
  };

  @override
  void initState() {
    super.initState();
    _loadClients();
    _prefillIfEditing();
  }

  void _prefillIfEditing() {
    final s = widget.existingSession;
    if (s != null) {
      _startDate = s.startTime;
      _endDate = s.endTime;
      _startTime = TimeOfDay.fromDateTime(s.startTime);
      _endTime = TimeOfDay.fromDateTime(s.endTime);
      _noteCtrl.text = s.subject;
    }
  }

  Future<void> _loadClients() async {
    try {
      final user = supa.auth.currentUser;
      if (user == null) return;

      final res = await supa
          .from('client_trainer')
          .select('client_id, client:client_id(name)')
          .eq('trainer_id', user.id);

      if (res is List && res.isNotEmpty) {
        setState(() {
          _clients = res
              .map(
                (e) => {
                  'id': e['client_id'] as String,
                  'name': e['client']?['name'] ?? 'Sin nombre',
                },
              )
              .toList();
        });
      } else {
        setState(() => _clients = []);
      }
    } catch (e) {
      debugPrint('Error cargando clientes: $e');
      setState(() => _clients = []);
    }
  }

  Future<void> _pickStartDate() async {
    final result = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (result != null) setState(() => _startDate = result);
  }

  Future<void> _pickEndDate() async {
    final result = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (result != null) setState(() => _endDate = result);
  }

  Future<void> _pickStartTime() async {
    final result = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (result != null) setState(() => _startTime = result);
  }

  Future<void> _pickEndTime() async {
    final result = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    if (result != null) setState(() => _endTime = result);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _timeError = null);

    if (_selectedClient == null) {
      setState(() => _timeError = 'Selecciona un cliente');
      return;
    }

    final startDateTime = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
      _startTime.hour,
      _startTime.minute,
    );
    final endDateTime = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
      _endTime.hour,
      _endTime.minute,
    );

    if (startDateTime.isAfter(endDateTime)) {
      setState(
        () => _timeError =
            'La hora de inicio no puede ser posterior a la hora de fin',
      );
      return;
    }

    if (_endDate.isBefore(_startDate)) {
      setState(
        () => _timeError = 'La fecha final no puede ser anterior a la inicial',
      );
      return;
    }

    final selectedDays = _days.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();
    if (selectedDays.isEmpty) {
      setState(() => _timeError = 'Selecciona al menos un día de la semana');
      return;
    }

    setState(() => _saving = true);

    try {
      if (widget.existingSession != null) {
        // 🔹 Editar sesión existente
        final user = supa.auth.currentUser;
        if (user == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Usuario no autenticado')),
          );
          return;
        }

        final session = TrainingSession(
          id: widget.existingSession!.id?.toString() ?? '',
          trainerId: user.id.toString(), // ✅ conversión explícita
          startTime: startDateTime,
          endTime: endDateTime,
          notes: _noteCtrl.text.trim(),
          clientId: _selectedClient!,
        );

        await _repo.updateSession(session);
      } else {
        // 🔹 Crear múltiples sesiones nuevas
        final sessionsToCreate = <Future>[];

        for (
          var d = _startDate;
          !d.isAfter(_endDate);
          d = d.add(const Duration(days: 1))
        ) {
          final weekdayLetter = _weekdayToLetter(d.weekday);
          if (selectedDays.contains(weekdayLetter)) {
            final start = DateTime(
              d.year,
              d.month,
              d.day,
              _startTime.hour,
              _startTime.minute,
            );
            final end = DateTime(
              d.year,
              d.month,
              d.day,
              _endTime.hour,
              _endTime.minute,
            );

            sessionsToCreate.add(
              _repo.addSession(
                startTime: start,
                endTime: end,
                notes: _noteCtrl.text.trim(),
                clientId: _selectedClient,
              ),
            );
          }
        }

        await Future.wait(sessionsToCreate);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _weekdayToLetter(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'L';
      case DateTime.tuesday:
        return 'M';
      case DateTime.wednesday:
        return 'X';
      case DateTime.thursday:
        return 'J';
      case DateTime.friday:
        return 'V';
      case DateTime.saturday:
        return 'S';
      case DateTime.sunday:
        return 'D';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFF111111);
    const accent = Color(0xFFBF5AF2);
    const textColor = Color(0xFFD9D9D9);

    final dateFmt = DateFormat('EEE d MMM', 'es_ES');

    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 16,
          left: 16,
          right: 16,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade700,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    widget.existingSession != null
                        ? 'Editar sesión'
                        : 'Nueva sesión',
                    style: const TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 📅 Fechas
                _darkTile(
                  Icons.calendar_today,
                  'Inicio: ${dateFmt.format(_startDate)}',
                  _pickStartDate,
                ),
                _darkTile(
                  Icons.calendar_month,
                  'Fin: ${dateFmt.format(_endDate)}',
                  _pickEndDate,
                ),

                // ⏰ Horas
                _darkTile(
                  Icons.access_time,
                  'Hora inicio: ${_startTime.format(context)}',
                  _pickStartTime,
                ),
                _darkTile(
                  Icons.access_time_filled,
                  'Hora fin: ${_endTime.format(context)}',
                  _pickEndTime,
                ),

                if (_timeError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
                    child: Text(
                      _timeError!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),

                // 🗓️ Días
                const Text(
                  'Días de la semana',
                  style: TextStyle(color: textColor),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  children: _days.keys.map((d) {
                    return FilterChip(
                      label: Text(d, style: const TextStyle(color: textColor)),
                      backgroundColor: Colors.white10,
                      selectedColor: accent.withOpacity(0.4),
                      selected: _days[d]!,
                      onSelected: (v) => setState(() => _days[d] = v),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // 🧍 Cliente
                DropdownButtonFormField<String>(
                  dropdownColor: background,
                  decoration: const InputDecoration(
                    labelText: 'Cliente',
                    labelStyle: TextStyle(color: Colors.white70),
                    border: OutlineInputBorder(),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: accent),
                    ),
                  ),
                  style: const TextStyle(color: textColor),
                  value: _selectedClient,
                  items: _clients
                      .map(
                        (c) => DropdownMenuItem(
                          value: c['id'] as String,
                          child: Text(
                            c['name'],
                            style: const TextStyle(color: textColor),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (val) => setState(() => _selectedClient = val),
                ),
                const SizedBox(height: 12),

                // 📝 Nota
                TextFormField(
                  controller: _noteCtrl,
                  style: const TextStyle(color: textColor),
                  decoration: const InputDecoration(
                    labelText: 'Nota o descripción',
                    labelStyle: TextStyle(color: Colors.white70),
                    border: OutlineInputBorder(),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: accent),
                    ),
                  ),
                  maxLines: 2,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Agrega una nota breve'
                      : null,
                ),
                const SizedBox(height: 16),

                // 💾 Botón
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: accent),
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.check, color: Colors.white),
                    label: Text(
                      _saving
                          ? (widget.existingSession != null
                                ? 'Actualizando...'
                                : 'Agendando...')
                          : (widget.existingSession != null
                                ? 'Guardar cambios'
                                : 'Guardar sesiones'),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _darkTile(IconData icon, String text, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(text, style: const TextStyle(color: Colors.white)),
      onTap: onTap,
    );
  }
}

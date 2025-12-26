import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import '../../../common/data/repositories/training_sessions_repo.dart';
import '../../../common/data/models/training_session.dart';

class AddSessionDialog extends StatefulWidget {
  final Appointment? existingSession;
  final DateTime? initialDate;

  const AddSessionDialog({super.key, this.existingSession, this.initialDate});

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
    _initializeDates();
  }

  void _initializeDates() {
    // 1. Si estamos editando, precargar datos existentes
    if (widget.existingSession != null) {
      _prefillIfEditing();
      return;
    }

    // 2. Si venimos de un clic en el calendario (Nueva sesión en hora específica)
    if (widget.initialDate != null) {
      final d = widget.initialDate!;

      // Configurar fechas
      _startDate = DateTime(d.year, d.month, d.day);
      // Por defecto dejamos la fecha fin igual a la inicio (o +7 días si prefieres mantener tu lógica de rangos)
      _endDate = _startDate.add(const Duration(days: 7));

      // --- CORRECCIÓN AQUÍ ---
      // Actualizamos la hora de inicio con la hora de la celda tocada
      _startTime = TimeOfDay.fromDateTime(d);

      // Calculamos la hora fin (por ejemplo, 1 hora después)
      final endD = d.add(const Duration(hours: 1));
      _endTime = TimeOfDay.fromDateTime(endD);

      // Opcional: Marcar automáticamente el día de la semana correspondiente
      // Si toqué un Martes, que se active la 'M' automáticamente
      final wdLetter = _weekdayToLetter(d.weekday);
      if (_days.containsKey(wdLetter)) {
        _days[wdLetter] = true;
      }
    }
  }

  void _prefillIfEditing() {
    final s = widget.existingSession;
    if (s != null) {
      final localStart = s.startTime.toLocal();
      final localEnd = s.endTime.toLocal();

      _startDate = DateTime(localStart.year, localStart.month, localStart.day);
      _endDate = DateTime(localEnd.year, localEnd.month, localEnd.day);

      _startTime = TimeOfDay.fromDateTime(localStart);
      _endTime = TimeOfDay.fromDateTime(localEnd);

      _noteCtrl.text = s.subject;
    }
  }

  Future<void> _loadClients() async {
    try {
      final user = supa.auth.currentUser;
      if (user == null) return;

      final appUser = await supa
          .from('app_user')
          .select('id, full_name, email')
          .eq('email', user.email!)
          .maybeSingle();

      if (appUser == null) {
        throw 'El usuario no existe. Debe registrarse primero.';
      }

      final appUserId = appUser['id'] as String;

      final res = await supa
          .from('client_trainer')
          .select('client_id, client:client_id(name)')
          .eq('trainer_id', appUserId);

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
      }
    } catch (e) {
      debugPrint('Error cargando clientes: $e');
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
    final t = await showTimePicker(context: context, initialTime: _startTime);

    if (t != null) setState(() => _startTime = t);
  }

  Future<void> _pickEndTime() async {
    final t = await showTimePicker(context: context, initialTime: _endTime);

    if (t != null) setState(() => _endTime = t);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _timeError = null;

    if (_selectedClient == null) {
      setState(() => _timeError = 'Selecciona un cliente');
      return;
    }

    final startDateTimeLocal = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
      _startTime.hour,
      _startTime.minute,
    );

    final endDateTimeLocal = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
      _endTime.hour,
      _endTime.minute,
    );

    if (startDateTimeLocal.isAfter(endDateTimeLocal)) {
      setState(
        () => _timeError = 'La hora de inicio no puede ser mayor a la de fin',
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
      setState(() => _timeError = 'Selecciona al menos un día');
      return;
    }

    setState(() => _saving = true);

    try {
      if (widget.existingSession != null) {
        await _updateExisting(startDateTimeLocal, endDateTimeLocal);
      } else {
        await _createRange(selectedDays);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _updateExisting(DateTime start, DateTime end) async {
    final user = supa.auth.currentUser;
    if (user == null) return;

    final session = TrainingSession(
      id: widget.existingSession!.id.toString(),
      trainerId: user.id,
      clientId: _selectedClient!,
      notes: _noteCtrl.text.trim(),
      startTime: start.toUtc(),
      endTime: end.toUtc(),
      started: widget.existingSession!.location == "true",
    );

    await _repo.updateSession(session);
  }

  Future<void> _createRange(List<String> days) async {
    final futures = <Future>[];

    for (
      var d = _startDate;
      !d.isAfter(_endDate);
      d = d.add(const Duration(days: 1))
    ) {
      final wd = _weekdayToLetter(d.weekday);

      if (!days.contains(wd)) continue;

      final start = DateTime(
        d.year,
        d.month,
        d.day,
        _startTime.hour,
        _startTime.minute,
      ).toUtc();

      final end = DateTime(
        d.year,
        d.month,
        d.day,
        _endTime.hour,
        _endTime.minute,
      ).toUtc();

      futures.add(
        _repo.addSession(
          startTime: start,
          endTime: end,
          notes: _noteCtrl.text.trim(),
          clientId: _selectedClient,
        ),
      );
    }

    await Future.wait(futures);
  }

  String _weekdayToLetter(int wd) {
    switch (wd) {
      case 1:
        return 'L';
      case 2:
        return 'M';
      case 3:
        return 'X';
      case 4:
        return 'J';
      case 5:
        return 'V';
      case 6:
        return 'S';
      case 7:
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

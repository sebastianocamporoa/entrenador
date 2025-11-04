import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../common/data/repositories/training_sessions_repo.dart';

class AddSessionDialog extends StatefulWidget {
  const AddSessionDialog({super.key});

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

    // ✅ Obtener días seleccionados
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
    final dateFmt = DateFormat('EEE d MMM', 'es_ES');

    return SafeArea(
      child: Padding(
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
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Text(
                  'Nueva sesión',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),

                // 📅 Fechas
                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: Text('Inicio: ${dateFmt.format(_startDate)}'),
                  onTap: _pickStartDate,
                ),
                ListTile(
                  leading: const Icon(Icons.calendar_month),
                  title: Text('Fin: ${dateFmt.format(_endDate)}'),
                  onTap: _pickEndDate,
                ),

                // ⏰ Horas
                ListTile(
                  leading: const Icon(Icons.access_time),
                  title: Text('Hora inicio: ${_startTime.format(context)}'),
                  onTap: _pickStartTime,
                ),
                ListTile(
                  leading: const Icon(Icons.access_time_filled),
                  title: Text('Hora fin: ${_endTime.format(context)}'),
                  onTap: _pickEndTime,
                ),

                // ⚠️ Error visual
                if (_timeError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _timeError!,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                  ),

                // 🗓️ Días de la semana
                Wrap(
                  spacing: 6,
                  children: _days.keys.map((d) {
                    return FilterChip(
                      label: Text(d),
                      selected: _days[d]!,
                      onSelected: (v) => setState(() => _days[d] = v),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),

                // 🧍 Cliente
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Cliente',
                    border: OutlineInputBorder(),
                  ),
                  value: _selectedClient,
                  items: _clients
                      .map(
                        (c) => DropdownMenuItem(
                          value: c['id'] as String,
                          child: Text(c['name']),
                        ),
                      )
                      .toList(),
                  onChanged: (val) => setState(() => _selectedClient = val),
                  validator: (val) =>
                      val == null ? 'Selecciona un cliente' : null,
                ),
                const SizedBox(height: 12),

                // 📝 Nota
                TextFormField(
                  controller: _noteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nota o descripción',
                    border: OutlineInputBorder(),
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
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.check),
                    label: Text(
                      _saving ? 'Agendando sesiones...' : 'Guardar sesiones',
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
}

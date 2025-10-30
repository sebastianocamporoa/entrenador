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

  DateTime _date = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);
  final _noteCtrl = TextEditingController();

  bool _saving = false;
  String? _selectedClient;
  List<Map<String, dynamic>> _clients = [];

  // ⚠️ Mensaje de error para horas
  String? _timeError;

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

      debugPrint('Clientes asociados: $res');

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

  Future<void> _pickDate() async {
    final result = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (result != null) setState(() => _date = result);
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

    final startDateTime = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _startTime.hour,
      _startTime.minute,
    );
    final endDateTime = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _endTime.hour,
      _endTime.minute,
    );

    setState(() => _timeError = null);

    // 🔹 Validaciones visuales
    if (startDateTime.isAfter(endDateTime)) {
      setState(
        () => _timeError =
            'La hora de inicio no puede ser posterior a la hora de fin',
      );
      return;
    }

    if (startDateTime.isAtSameMomentAs(endDateTime)) {
      setState(
        () => _timeError = 'La hora de inicio y fin no pueden ser iguales',
      );
      return;
    }

    if (startDateTime.isBefore(DateTime.now())) {
      setState(() => _timeError = 'No puedes agendar una sesión en el pasado');
      return;
    }

    if (_selectedClient == null) {
      setState(() => _timeError = 'Selecciona un cliente antes de guardar');
      return;
    }

    setState(() => _saving = true);

    try {
      await _repo.addSession(
        startTime: startDateTime,
        endTime: endDateTime,
        notes: _noteCtrl.text.trim(),
        clientId: _selectedClient,
      );

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

                // 📅 Fecha
                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: Text(dateFmt.format(_date)),
                  onTap: _pickDate,
                ),

                // ⏰ Hora inicio
                ListTile(
                  leading: const Icon(Icons.access_time),
                  title: Text('Inicio: ${_startTime.format(context)}'),
                  onTap: _pickStartTime,
                ),

                // ⏰ Hora fin
                ListTile(
                  leading: const Icon(Icons.access_time_filled),
                  title: Text('Fin: ${_endTime.format(context)}'),
                  onTap: _pickEndTime,
                ),

                // ⚠️ Error visual de horas
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

                const SizedBox(height: 8),

                // 🧍‍♂️ Cliente
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

                // 💾 Botón guardar
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.check),
                    label: Text(_saving ? 'Guardando...' : 'Guardar sesión'),
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

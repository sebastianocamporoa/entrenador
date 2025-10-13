import 'package:flutter/material.dart';
import '../../common/data/repositories/admin_repo.dart';

class PromoteUserScreen extends StatefulWidget {
  const PromoteUserScreen({super.key});

  @override
  State<PromoteUserScreen> createState() => _PromoteUserScreenState();
}

class _PromoteUserScreenState extends State<PromoteUserScreen> {
  final _repo = AdminRepo();
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  String? _resultMsg;
  Map<String, dynamic>? _found;

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _resultMsg = null;
      _found = null;
    });
    try {
      final row = await _repo.findAppUserByEmail(_emailCtrl.text.trim());
      if (row == null) {
        setState(() => _resultMsg = 'No se encontró un usuario con ese email.');
      } else {
        setState(() => _found = row);
      }
    } catch (e) {
      setState(() => _resultMsg = 'Error al buscar: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _promote() async {
    if (_emailCtrl.text.trim().isEmpty) return;
    setState(() {
      _loading = true;
      _resultMsg = null;
    });
    try {
      await _repo.promoteToCoachByEmail(_emailCtrl.text.trim());
      setState(() => _resultMsg = 'Usuario promovido a COACH correctamente.');
      await _search();
    } catch (e) {
      setState(() => _resultMsg = 'Error al promover: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userInfo = _found == null
        ? const SizedBox()
        : Card(
            child: ListTile(
              title: Text(_found!['email'] ?? ''),
              subtitle: Text('Rol actual: ${_found!['role']}'),
            ),
          );

    return Scaffold(
      appBar: AppBar(title: const Text('Promover usuario')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _emailCtrl,
              decoration: const InputDecoration(
                labelText: 'Email del usuario',
                hintText: 'usuario@dominio.com',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _loading ? null : _search,
                  icon: const Icon(Icons.search),
                  label: const Text('Buscar'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _loading ? null : _promote,
                  icon: const Icon(Icons.upgrade),
                  label: const Text('Promover a Coach'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_resultMsg != null)
              Text(_resultMsg!, style: const TextStyle(color: Colors.indigo)),
            const SizedBox(height: 8),
            userInfo,
          ],
        ),
      ),
    );
  }
}

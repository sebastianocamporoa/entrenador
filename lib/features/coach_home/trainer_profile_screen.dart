import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TrainerProfileScreen extends StatefulWidget {
  const TrainerProfileScreen({super.key});

  @override
  State<TrainerProfileScreen> createState() => _TrainerProfileScreenState();
}

class _TrainerProfileScreenState extends State<TrainerProfileScreen> {
  final _supa = Supabase.instance.client;
  bool _isLoading = false;

  Future<void> _signOut() async {
    setState(() => _isLoading = true);
    try {
      await _supa.auth.signOut();
      // El AuthGate en main.dart detectará el cambio y redirigirá al Login automáticamente
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al salir: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _supa.auth.currentUser;
    final email = user?.email ?? 'Entrenador';
    // Intentamos obtener el nombre de la metadata
    final name = user?.userMetadata?['full_name'] ?? 'Coach';

    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Avatar
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFBF5AF2), width: 3),
                ),
                child: const CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.white10,
                  child: Icon(Icons.person, size: 60, color: Colors.white),
                ),
              ),
              const SizedBox(height: 20),

              // Datos
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                email,
                style: const TextStyle(color: Colors.white54, fontSize: 16),
              ),
              const SizedBox(height: 12),

              // Badge de Rol
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFBF5AF2).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  "MODO ENTRENADOR",
                  style: TextStyle(
                    color: Color(0xFFBF5AF2),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),

              const SizedBox(height: 60),

              // Botón Cerrar Sesión
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _signOut,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.withOpacity(0.1),
                    foregroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Colors.redAccent),
                    ),
                  ),
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.red,
                          ),
                        )
                      : const Icon(Icons.logout),
                  label: Text(_isLoading ? 'Cerrando...' : 'CERRAR SESIÓN'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

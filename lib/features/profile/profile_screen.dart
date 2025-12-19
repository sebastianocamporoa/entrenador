import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _supa = Supabase.instance.client;
  bool _isLoading = false;

  // --- CERRAR SESIÓN ---
  Future<void> _signOut() async {
    setState(() => _isLoading = true);
    try {
      await _supa.auth.signOut();

      if (mounted) {
        // Redirigir al Login y borrar historial de navegación
        // Asegúrate de tener definida la ruta '/login' o la que uses
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al salir: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _supa.auth.currentUser;
    final email = user?.email ?? 'Usuario';
    // Intentamos sacar el nombre de la metadata o ponemos uno por defecto
    final name = user?.userMetadata?['full_name'] ?? 'Atleta';
    final avatarUrl = user?.userMetadata?['avatar_url'];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // SafeArea para que no choque con la barra de notificaciones
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // 1. FOTO DE PERFIL
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).primaryColor,
                    width: 2,
                  ),
                ),
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey[800],
                  backgroundImage: (avatarUrl != null)
                      ? NetworkImage(avatarUrl)
                      : const NetworkImage('https://i.pravatar.cc/300?img=5'),
                ),
              ),
              const SizedBox(height: 16),

              // 2. NOMBRE Y CORREO
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                email,
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
              ),

              const SizedBox(height: 30),

              // 3. MENÚ DE OPCIONES
              _buildSectionTitle('General'),
              _buildListTile(
                icon: Icons.person_outline,
                title: 'Editar Perfil',
                onTap: () {},
              ),
              _buildListTile(
                icon: Icons.notifications_outlined,
                title: 'Notificaciones',
                onTap: () {},
              ),
              _buildListTile(
                icon: Icons.lock_outline,
                title: 'Seguridad y Privacidad',
                onTap: () {},
              ),

              const SizedBox(height: 20),
              _buildSectionTitle('Soporte'),
              _buildListTile(
                icon: Icons.help_outline,
                title: 'Ayuda y Soporte',
                onTap: () {},
              ),
              _buildListTile(
                icon: Icons.info_outline,
                title: 'Términos y Condiciones',
                onTap: () {},
              ),

              const SizedBox(height: 30),

              // 4. BOTÓN CERRAR SESIÓN
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _signOut,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.withOpacity(
                      0.1,
                    ), // Fondo rojo suave
                    foregroundColor: Colors.redAccent, // Texto rojo
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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
              const SizedBox(height: 20),
              Text(
                'Versión 1.0.0',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGETS DE DISEÑO ---

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10, left: 4),
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E), // Color de tarjeta oscuro
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: Colors.white70),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        trailing: const Icon(Icons.chevron_right, color: Colors.white24),
      ),
    );
  }
}

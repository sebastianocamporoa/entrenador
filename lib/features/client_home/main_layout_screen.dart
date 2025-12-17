import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// IMPORTA TUS PANTALLAS AQUÍ
import 'today_workout_screen.dart';

class MainLayoutScreen extends StatefulWidget {
  const MainLayoutScreen({super.key});

  @override
  State<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends State<MainLayoutScreen> {
  int _currentIndex = 0;
  final SupabaseClient _supabase = Supabase.instance.client;

  // --- LISTA DE PANTALLAS ---
  // Aquí defines qué pantalla se muestra en cada pestaña
  final List<Widget> _pages = [
    const TodayWorkoutScreen(), // 0: Home (Tu pantalla de hoy)
    const Center(
      child: Text(
        'Estadísticas (Próximamente)',
        style: TextStyle(color: Colors.white),
      ),
    ), // 1: Stats
    const Center(
      child: Text(
        'Notificaciones (Próximamente)',
        style: TextStyle(color: Colors.white),
      ),
    ), // 2: Notis
    const Center(
      child: Text('Perfil de Usuario', style: TextStyle(color: Colors.white)),
    ), // 3: Perfil
  ];

  @override
  Widget build(BuildContext context) {
    // Usamos los colores de tu tema actual
    final theme = Theme.of(context);
    final backgroundColor = theme.scaffoldBackgroundColor;
    final surfaceColor = theme.colorScheme.surface;
    final primaryColor = theme.primaryColor;

    return Scaffold(
      backgroundColor: backgroundColor,
      // EL BODY CAMBIA SEGÚN EL ÍNDICE SELECCIONADO
      body: _pages[_currentIndex],

      // BARRA DE NAVEGACIÓN PERSONALIZADA
      bottomNavigationBar: Container(
        height: 80, // Altura cómoda para el dedo
        decoration: BoxDecoration(
          color: surfaceColor, // Color gris oscuro de tus tarjetas
          border: Border(
            top: BorderSide(color: Colors.white.withOpacity(0.05)),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 1. HOME
              _buildNavItem(
                index: 0,
                icon: Icons.home_filled,
                isSelected: _currentIndex == 0,
                primaryColor: primaryColor,
              ),

              // 2. ESTADÍSTICAS
              _buildNavItem(
                index: 1,
                icon: Icons.bar_chart_rounded,
                isSelected: _currentIndex == 1,
                primaryColor: primaryColor,
              ),

              // 3. NOTIFICACIONES (Con puntito morado/rosa como la foto)
              _buildNotificationItem(index: 2, isSelected: _currentIndex == 2),

              // 4. PERFIL (Avatar Circular)
              _buildProfileItem(
                index: 3,
                isSelected: _currentIndex == 3,
                primaryColor: primaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGET: Ítem Normal (Icono) ---
  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required bool isSelected,
    required Color primaryColor,
  }) {
    return IconButton(
      onPressed: () => setState(() => _currentIndex = index),
      icon: Icon(
        icon,
        size: 28,
        // Si está seleccionado: Color Primario (o Blanco). Si no: Gris apagado
        color: isSelected ? Colors.white : Colors.white24,
      ),
    );
  }

  // --- WIDGET: Notificaciones (Con Badge) ---
  Widget _buildNotificationItem({
    required int index,
    required bool isSelected,
  }) {
    return Stack(
      alignment: Alignment.topRight,
      children: [
        IconButton(
          onPressed: () => setState(() => _currentIndex = index),
          icon: Icon(
            Icons.notifications_rounded, // O la campana que prefieras
            size: 28,
            color: isSelected ? Colors.white : Colors.white24,
          ),
        ),
        // El puntito (Badge)
        Positioned(
          top: 10,
          right: 10,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: const Color(
                0xFFD946EF,
              ), // Un morado/rosa neón como la foto
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF1E1E1E),
                width: 2,
              ), // Borde para separar del icono
            ),
          ),
        ),
      ],
    );
  }

  // --- WIDGET: Perfil (Avatar Real) ---
  Widget _buildProfileItem({
    required int index,
    required bool isSelected,
    required Color primaryColor,
  }) {
    // Obtenemos la URL del avatar de Supabase (si existe)
    final user = _supabase.auth.currentUser;
    final avatarUrl = user?.userMetadata?['avatar_url'];

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: Container(
        padding: const EdgeInsets.all(2), // Espacio para el borde de selección
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // Si está seleccionado, mostramos un anillo del color primario
          border: isSelected ? Border.all(color: primaryColor, width: 2) : null,
        ),
        child: CircleAvatar(
          radius: 14, // Tamaño del avatar
          backgroundColor: Colors.grey[800],
          backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
              ? NetworkImage(avatarUrl)
              : const NetworkImage(
                  'https://i.pravatar.cc/150?img=5',
                ), // Placeholder tipo la chica de la foto
        ),
      ),
    );
  }
}

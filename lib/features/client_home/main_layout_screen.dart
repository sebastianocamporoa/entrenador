import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// --- IMPORTS DE PANTALLAS ---
import 'today_workout_screen.dart';
// 1. Importamos la nueva pantalla de estadísticas
import '../statistics/statistics_screen.dart';
import '../profile/profile_screen.dart';

class MainLayoutScreen extends StatefulWidget {
  const MainLayoutScreen({super.key});

  @override
  State<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends State<MainLayoutScreen> {
  int _currentIndex = 0;
  final SupabaseClient _supabase = Supabase.instance.client;

  // --- LISTA DE PANTALLAS ---
  // El orden aquí debe coincidir con el orden de los botones en el BottomNavigationBar
  late final List<Widget> _pages = [
    // 0: HOME
    const TodayWorkoutScreen(),

    // 1: ESTADÍSTICAS (Ya conectada)
    const StatisticsScreen(),

    // 2: NOTIFICACIONES (Placeholder)
    const Center(
      child: Text(
        'Notificaciones (Próximamente)',
        style: TextStyle(color: Colors.white),
      ),
    ),

    // 3: PERFIL (Placeholder)
    const ProfileScreen(),
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

              // 3. NOTIFICACIONES (Con puntito morado/rosa)
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

  // --- WIDGETS AUXILIARES (Sin cambios) ---

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
        // Si está seleccionado: Color Blanco. Si no: Gris apagado
        color: isSelected ? Colors.white : Colors.white24,
      ),
    );
  }

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
            Icons.notifications_rounded,
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
              color: const Color(0xFFD946EF), // Un morado/rosa neón
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
                ), // Placeholder
        ),
      ),
    );
  }
}

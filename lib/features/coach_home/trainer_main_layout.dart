import 'package:flutter/material.dart';

// Importa tu pantalla de clientes actual y la de perfil nueva
import 'coach_home_screen.dart';
import 'trainer_profile_screen.dart';

class TrainerMainLayout extends StatefulWidget {
  const TrainerMainLayout({super.key});

  @override
  State<TrainerMainLayout> createState() => _TrainerMainLayoutState();
}

class _TrainerMainLayoutState extends State<TrainerMainLayout> {
  int _currentIndex = 0;

  // Lista de Pantallas del Entrenador
  late final List<Widget> _pages = [
    const CoachHomeScreen(), // Index 0: Clientes
    const TrainerProfileScreen(), // Index 1: Perfil
  ];

  @override
  Widget build(BuildContext context) {
    // Usamos el mismo estilo oscuro
    const navBarColor = Color(0xFF1C1C1E); // O surfaceColor
    const primaryColor = Color(0xFFBF5AF2);

    return Scaffold(
      body: _pages[_currentIndex],

      // Barra de navegación personalizada
      bottomNavigationBar: Container(
        height: 80,
        decoration: BoxDecoration(
          color: navBarColor,
          border: Border(
            top: BorderSide(color: Colors.white.withOpacity(0.05)),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 120,
          ), // Margen amplio para centrar 2 items
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildNavItem(
                index: 0,
                icon: Icons.home_filled,
                isSelected: _currentIndex == 0,
                primaryColor: primaryColor,
              ),
              _buildNavItem(
                index: 1,
                icon: Icons.person_rounded,
                isSelected: _currentIndex == 1,
                primaryColor: primaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

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
}

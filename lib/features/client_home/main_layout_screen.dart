import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'client_home_screen.dart';
import '../statistics/statistics_screen.dart';
import '../profile/profile_screen.dart';
import '../client_onboarding/client_onboarding_wizard.dart';

class MainLayoutScreen extends StatefulWidget {
  const MainLayoutScreen({super.key});

  @override
  State<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends State<MainLayoutScreen> {
  int _currentIndex = 0;
  final SupabaseClient _supabase = Supabase.instance.client;

  // 🔥 LISTA ACTUALIZADA: Solo 3 pantallas
  late final List<Widget> _pages = [
    const ClientHomeScreen(), // Índice 0
    const StatisticsScreen(), // Índice 1
    const ProfileScreen(), // Índice 2 (antes era 3)
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkOnboarding();
    });
  }

  Future<void> _checkOnboarding() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final appUser = await _supabase
          .from('app_user')
          .select('id')
          .eq('auth_user_id', user.id)
          .maybeSingle();

      if (appUser == null) return;
      final internalId = appUser['id'];

      final clientData = await _supabase
          .from('clients')
          .select('sex, phone, goal')
          .eq('app_user_id', internalId)
          .maybeSingle();

      bool needsOnboarding = false;

      if (clientData == null) {
        needsOnboarding = true;
      } else {
        needsOnboarding =
            clientData['sex'] == null ||
            clientData['phone'] == null ||
            clientData['goal'] == null;
      }

      if (needsOnboarding && mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const ClientOnboardingWizard(),
            fullscreenDialog: true,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error verificando onboarding: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = theme.scaffoldBackgroundColor;
    final surfaceColor = theme.colorScheme.surface;
    final primaryColor = theme.primaryColor;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: _pages[_currentIndex],
      bottomNavigationBar: Container(
        height: 80,
        decoration: BoxDecoration(
          color: surfaceColor,
          border: Border(
            top: BorderSide(color: Colors.white.withOpacity(0.05)),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
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
                icon: Icons.bar_chart_rounded,
                isSelected: _currentIndex == 1,
                primaryColor: primaryColor,
              ),
              // 🔥 ELIMINADO: _buildNotificationItem ya no existe aquí

              // 🔥 ACTUALIZADO: El índice de perfil ahora es 2
              _buildProfileItem(
                index: 2,
                isSelected: _currentIndex == 2,
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
        color: isSelected ? Colors.white : Colors.white24,
      ),
    );
  }

  // 🔥 ELIMINADO: La función _buildNotificationItem fue borrada completamente.

  Widget _buildProfileItem({
    required int index,
    required bool isSelected,
    required Color primaryColor,
  }) {
    final user = _supabase.auth.currentUser;
    final avatarUrl = user?.userMetadata?['avatar_url'];

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: isSelected ? Border.all(color: primaryColor, width: 2) : null,
        ),
        child: CircleAvatar(
          radius: 14,
          backgroundColor: Colors.grey[800],
          backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
              ? NetworkImage(avatarUrl)
              : null,
        ),
      ),
    );
  }
}

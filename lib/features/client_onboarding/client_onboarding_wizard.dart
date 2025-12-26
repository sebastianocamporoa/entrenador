import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ClientOnboardingWizard extends StatefulWidget {
  const ClientOnboardingWizard({super.key});

  @override
  State<ClientOnboardingWizard> createState() => _ClientOnboardingWizardState();
}

class _ClientOnboardingWizardState extends State<ClientOnboardingWizard> {
  final PageController _pageCtrl = PageController();
  final _supa = Supabase.instance.client;

  String? _selectedSex;
  final TextEditingController _heightCtrl = TextEditingController();
  final TextEditingController _weightCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  String? _activityLevel;
  final TextEditingController _goalCtrl = TextEditingController();

  int _currentPage = 0;
  bool _isLoading = false;

  final int _totalSteps = 6;

  @override
  void dispose() {
    _pageCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _phoneCtrl.dispose();
    _goalCtrl.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _totalSteps - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.fastOutSlowIn,
      );
    } else {
      _finishOnboarding();
    }
  }

  Future<void> _finishOnboarding() async {
    setState(() => _isLoading = true);
    try {
      final userId = _supa.auth.currentUser!.id;

      final appUser = await _supa
          .from('app_user')
          .select('id')
          .eq('auth_user_id', userId)
          .single();

      final internalUserId = appUser['id'];

      final clientData = await _supa
          .from('clients')
          .update({
            'sex': _selectedSex,
            'phone': _phoneCtrl.text.trim(),
            'goal': _goalCtrl.text.trim(),
            'activity_level': _activityLevel,
          })
          .eq('app_user_id', internalUserId)
          .select('id')
          .single();

      final clientId = clientData['id'];

      final double? weight = double.tryParse(
        _weightCtrl.text.replaceAll(',', '.'),
      );
      final double? height = double.tryParse(
        _heightCtrl.text.replaceAll(',', '.'),
      );

      await _supa.from('measurements').insert({
        'client_id': clientId,
        'date_at': DateTime.now().toIso8601String().split('T').first,
        'weight_kg': weight,
        'height_cm': height,
      });

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final progress = (_currentPage + 1) / _totalSteps;

    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white10,
                  valueColor: AlwaysStoppedAnimation(primaryColor),
                  minHeight: 6,
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _buildStep(
                    title: 'Comencemos',
                    subtitle: 'Esto nos ayuda a calcular tus métricas base.',
                    question: '¿Cuál es tu género biológico?',
                    isValid: _selectedSex != null,
                    content: Column(
                      children: [
                        _GenderCard(
                          label: 'Hombre',
                          icon: Icons.male,
                          isSelected: _selectedSex == 'M',
                          onTap: () => setState(() => _selectedSex = 'M'),
                          color: primaryColor,
                        ),
                        const SizedBox(height: 16),
                        _GenderCard(
                          label: 'Mujer',
                          icon: Icons.female,
                          isSelected: _selectedSex == 'F',
                          onTap: () => setState(() => _selectedSex = 'F'),
                          color: primaryColor,
                        ),
                      ],
                    ),
                  ),
                  _buildStep(
                    title: 'Datos corporales',
                    subtitle: 'Para ajustar los ejercicios a ti.',
                    question: '¿Cuál es tu estatura (cm)?',
                    isValid: _heightCtrl.text.isNotEmpty,
                    content: _NumberInput(
                      controller: _heightCtrl,
                      suffix: 'cm',
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  _buildStep(
                    title: 'Punto de partida',
                    subtitle: 'Veremos tu progreso desde aquí.',
                    question: '¿Cuál es tu peso actual (kg)?',
                    isValid: _weightCtrl.text.isNotEmpty,
                    content: _NumberInput(
                      controller: _weightCtrl,
                      suffix: 'kg',
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  _buildStep(
                    title: 'Tu ritmo actual',
                    subtitle: 'Sé honesto, esto definirá tu plan inicial.',
                    question: '¿Cuánta actividad física realizas?',
                    isValid: _activityLevel != null,
                    content: Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          children: [
                            _ActivityCard(
                              title: 'Sedentario',
                              desc: 'Poco o nada de ejercicio.',
                              value: 'sedentary',
                              groupValue: _activityLevel,
                              onTap: (v) => setState(() => _activityLevel = v),
                              color: primaryColor,
                            ),
                            const SizedBox(height: 12),
                            _ActivityCard(
                              title: 'Ligero (1-3 días)',
                              desc: 'Ejercicio suave o deportes ocasionales.',
                              value: 'light',
                              groupValue: _activityLevel,
                              onTap: (v) => setState(() => _activityLevel = v),
                              color: primaryColor,
                            ),
                            const SizedBox(height: 12),
                            _ActivityCard(
                              title: 'Moderado (3-5 días)',
                              desc: 'Ejercicio moderado o deportes semanales.',
                              value: 'moderate',
                              groupValue: _activityLevel,
                              onTap: (v) => setState(() => _activityLevel = v),
                              color: primaryColor,
                            ),
                            const SizedBox(height: 12),
                            _ActivityCard(
                              title: 'Activo (6-7 días)',
                              desc: 'Ejercicio fuerte o deportes diarios.',
                              value: 'active',
                              groupValue: _activityLevel,
                              onTap: (v) => setState(() => _activityLevel = v),
                              color: primaryColor,
                            ),
                            const SizedBox(height: 12),
                            _ActivityCard(
                              title: 'Atleta (2x al día)',
                              desc:
                                  'Entrenamientos muy intensos o doble jornada.',
                              value: 'athlete',
                              groupValue: _activityLevel,
                              onTap: (v) => setState(() => _activityLevel = v),
                              color: primaryColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _buildStep(
                    title: 'Contacto',
                    subtitle: 'Para estar comunicados.',
                    question: '¿Cuál es tu número de celular?',
                    isValid: _phoneCtrl.text.length > 6,
                    content: _TextInput(
                      controller: _phoneCtrl,
                      hint: '300 123 4567',
                      inputType: TextInputType.phone,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  _buildStep(
                    title: 'La Meta',
                    subtitle: 'Lo más importante es saber a dónde vas.',
                    question: '¿Cuál es tu objetivo principal?',
                    isValid: _goalCtrl.text.length > 3,
                    isLast: true,
                    content: _TextInput(
                      controller: _goalCtrl,
                      hint: 'Bajar de peso, ganar músculo...',
                      inputType: TextInputType.text,
                      maxLines: 3,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep({
    required String title,
    required String subtitle,
    required String question,
    required Widget content,
    required bool isValid,
    bool isLast = false,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 16, color: Colors.white54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Text(
            question,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFFD9D9D9),
            ),
          ),
          const SizedBox(height: 24),
          content is Expanded ? content : Expanded(child: content),
          const SizedBox(height: 24),
          SizedBox(
            height: 56,
            child: FilledButton(
              onPressed: (isValid && !_isLoading) ? _nextPage : null,
              style: FilledButton.styleFrom(
                backgroundColor: isValid
                    ? Theme.of(context).primaryColor
                    : Colors.white10,
                foregroundColor: isValid ? Colors.white : Colors.white38,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      isLast ? 'Finalizar' : 'Continuar',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberInput extends StatelessWidget {
  final TextEditingController controller;
  final String suffix;
  final Function(String) onChanged;

  const _NumberInput({
    required this.controller,
    required this.suffix,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      autofocus: true,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 40,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      decoration: InputDecoration(
        suffixText: suffix,
        suffixStyle: const TextStyle(fontSize: 20, color: Colors.white54),
        border: InputBorder.none,
        hintText: '0',
        hintStyle: TextStyle(color: Colors.white12),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white24),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: Theme.of(context).primaryColor,
            width: 2,
          ),
        ),
      ),
      onChanged: onChanged,
    );
  }
}

class _TextInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType inputType;
  final int maxLines;
  final Function(String) onChanged;

  const _TextInput({
    required this.controller,
    required this.hint,
    required this.inputType,
    required this.onChanged,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: inputType,
      maxLines: maxLines,
      autofocus: true,
      style: const TextStyle(fontSize: 20, color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).primaryColor),
        ),
      ),
      onChanged: onChanged,
    );
  }
}

class _GenderCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final Color color;

  const _GenderCard({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(0.2)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? color : Colors.white70, size: 28),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 18,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const Spacer(),
            if (isSelected) Icon(Icons.check_circle, color: color),
          ],
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final String title;
  final String desc;
  final String value;
  final String? groupValue;
  final Function(String) onTap;
  final Color color;

  const _ActivityCard({
    required this.title,
    required this.desc,
    required this.value,
    required this.groupValue,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == groupValue;

    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(0.2)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 16,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    style: TextStyle(
                      color: isSelected ? Colors.white70 : Colors.white38,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check_circle, color: color, size: 24),
          ],
        ),
      ),
    );
  }
}

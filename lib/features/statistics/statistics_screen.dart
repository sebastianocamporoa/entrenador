import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// IMPORTA TU NUEVO SERVICIO
import '../../common/services/diet_service.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final _supa = Supabase.instance.client;
  final _picker = ImagePicker();

  // Instancia del servicio de dietas
  final _dietService = DietService();

  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();

  File? _imgFront;
  File? _imgBack;
  File? _imgLeft;
  File? _imgRight;

  bool _isLoading = false;
  bool _isGeneratingDiet = false; // Estado específico para la dieta

  Future<void> _pickImage(String type) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 60,
      );
      if (picked == null) return;

      setState(() {
        final file = File(picked.path);
        switch (type) {
          case 'front':
            _imgFront = file;
            break;
          case 'back':
            _imgBack = file;
            break;
          case 'left':
            _imgLeft = file;
            break;
          case 'right':
            _imgRight = file;
            break;
        }
      });
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  // --- GENERAR DIETA PDF ---
  Future<void> _createDietPdf() async {
    // 1. Validaciones básicas
    if (_weightCtrl.text.isEmpty || _heightCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa peso y altura primero')),
      );
      return;
    }

    setState(() => _isGeneratingDiet = true);

    try {
      final user = _supa.auth.currentUser;
      if (user == null) return;

      final clientProfile = await _supa
          .from('app_user')
          .select('id')
          .eq('auth_user_id', user.id)
          .maybeSingle();

      if (clientProfile == null) return;

      final clientId = clientProfile['id'];

      // 2. Obtener datos del cliente (ID y Objetivo)
      final clientRes = await _supa
          .from('clients')
          .select('id, goal')
          .eq('app_user_id', clientId)
          .maybeSingle();

      if (clientRes != null) {
        final clientId = clientRes['id'];

        // --- NUEVO: OBTENER LAS FOTOS DE SUPABASE ---
        // Buscamos las últimas 4 fotos subidas por este cliente
        // para enviárselas a la IA.
        final photosRes = await _supa
            .from('progress_photos')
            .select('url')
            .eq('client_id', clientId)
            .order('taken_at', ascending: false) // Las más recientes primero
            .limit(4); // Máximo 4 fotos

        // Convertimos la respuesta de la DB a una lista de Strings limpia
        List<String> realPhotoUrls = List<String>.from(
          (photosRes as List).map((item) => item['url']),
        );

        // 3. Llamar al servicio con las fotos REALES
        await _dietService.generateAndSaveDiet(
          clientId: clientId,
          currentWeight: double.parse(_weightCtrl.text),
          height: double.parse(_heightCtrl.text),
          goal: clientRes['goal'] ?? 'Mejorar composición corporal',
          photoUrls: realPhotoUrls, // <--- ¡AQUÍ ESTÁ LA MAGIA! 📸
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Dieta generada y descargada! 📄'),
              backgroundColor: Colors.purpleAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingDiet = false);
    }
  }

  // --- GUARDAR MEDIDAS ---
  Future<void> _saveCheckIn() async {
    if (_weightCtrl.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('El peso es obligatorio')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = _supa.auth.currentUser;
      if (user == null) throw Exception('No autenticado');

      final userProfile = await _supa
          .from('app_user')
          .select('id')
          .eq('auth_user_id', user.id)
          .maybeSingle();

      if (userProfile == null) return;

      final userClientId = userProfile['id'];

      final clientRes = await _supa
          .from('clients')
          .select('id')
          .eq('app_user_id', userClientId)
          .maybeSingle();

      if (clientRes == null) throw Exception('Cliente no encontrado');
      final clientId = clientRes['id'];

      final measurementData = await _supa
          .from('measurements')
          .insert({
            'client_id': clientId,
            'weight_kg': double.tryParse(_weightCtrl.text) ?? 0,
            'height_cm': double.tryParse(_heightCtrl.text) ?? 0,
            'date_at': DateTime.now().toIso8601String(),
            'notes': 'Registro desde App',
          })
          .select('id')
          .single();

      final String measurementId = measurementData['id'];

      await Future.wait([
        if (_imgFront != null)
          _uploadAndSavePhoto(clientId, measurementId, _imgFront!, 'front'),
        if (_imgBack != null)
          _uploadAndSavePhoto(clientId, measurementId, _imgBack!, 'back'),
        if (_imgLeft != null)
          _uploadAndSavePhoto(clientId, measurementId, _imgLeft!, 'left'),
        if (_imgRight != null)
          _uploadAndSavePhoto(clientId, measurementId, _imgRight!, 'right'),
      ]);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Medición guardada y perfil actualizado!'),
            backgroundColor: Color(0xFFCCFF00),
          ),
        );
        _clearForm();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadAndSavePhoto(
    String clientId,
    String measurementId,
    File file,
    String kind,
  ) async {
    final ext = file.path.split('.').last;
    final fileName = '${clientId}_${measurementId}_$kind.$ext';
    final path = '$clientId/$fileName';

    await _supa.storage.from('progress').upload(path, file);
    final publicUrl = _supa.storage.from('progress').getPublicUrl(path);

    await _supa.from('progress_photos').insert({
      'client_id': clientId,
      'measurement_id': measurementId,
      'kind': kind,
      'url': publicUrl,
      'taken_at': DateTime.now().toIso8601String(),
    });
  }

  void _clearForm() {
    setState(() {
      _imgFront = null;
      _imgBack = null;
      _imgLeft = null;
      _imgRight = null;
      _weightCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    return Scaffold(
      appBar: AppBar(title: const Text('Registrar Progreso')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Medidas de Hoy',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildInput(
                    _weightCtrl,
                    'Peso (kg)',
                    Icons.monitor_weight,
                    theme,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildInput(
                    _heightCtrl,
                    'Estatura (cm)',
                    Icons.height,
                    theme,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),
            const Text(
              'Registro Fotográfico',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sube tus 4 ángulos para comparar.',
              style: TextStyle(fontSize: 12, color: Colors.grey[400]),
            ),
            const SizedBox(height: 16),

            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.8,
              children: [
                _buildPhotoSlot('Frente', 'front', _imgFront, primaryColor),
                _buildPhotoSlot('Espalda', 'back', _imgBack, primaryColor),
                _buildPhotoSlot('Perfil Izq.', 'left', _imgLeft, primaryColor),
                _buildPhotoSlot(
                  'Perfil Der.',
                  'right',
                  _imgRight,
                  primaryColor,
                ),
              ],
            ),

            const SizedBox(height: 40),

            // BOTÓN 1: GUARDAR REGISTRO
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveCheckIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.black)
                    : const Text(
                        'GUARDAR REGISTRO',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 20),

            // BOTÓN 2: GENERAR DIETA IA (PDF)
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: _isGeneratingDiet ? null : _createDietPdf,
                icon: _isGeneratingDiet
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(
                  _isGeneratingDiet
                      ? ' CREANDO PDF...'
                      : ' GENERAR DIETA CON IA',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9C27B0), // Morado IA
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(
    TextEditingController ctrl,
    String label,
    IconData icon,
    ThemeData theme,
  ) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: theme.primaryColor),
        filled: true,
        fillColor: const Color(0xFF1E1E1E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildPhotoSlot(String label, String kind, File? file, Color accent) {
    return GestureDetector(
      onTap: () => _pickImage(kind),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: file != null ? accent : Colors.white10),
          image: file != null
              ? DecorationImage(image: FileImage(file), fit: BoxFit.cover)
              : null,
        ),
        child: file == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.camera_alt_rounded,
                    size: 32,
                    color: accent.withOpacity(0.7),
                  ),
                  const SizedBox(height: 8),
                  Text(label, style: const TextStyle(color: Colors.white54)),
                ],
              )
            : Align(
                alignment: Alignment.topRight,
                child: Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit, size: 16, color: Colors.white),
                ),
              ),
      ),
    );
  }
}

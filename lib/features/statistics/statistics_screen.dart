import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Ajusta la ruta a tu servicio
import '../../common/services/diet_service.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final _supa = Supabase.instance.client;
  final _picker = ImagePicker();
  final _dietService = DietService();

  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();

  File? _imgFront;
  File? _imgBack;
  File? _imgLeft;
  File? _imgRight;

  bool _isLoading = false; // Cargando subida de fotos
  bool _isLoadingDiet = false; // Cargando descarga de dieta

  @override
  void initState() {
    super.initState();
    _loadLastMeasurement();
  }

  // Cargar último peso/altura para facilitar el registro
  Future<void> _loadLastMeasurement() async {
    try {
      final user = _supa.auth.currentUser;
      if (user == null) return;

      // Obtener ID de cliente
      final clientData = await _getClientId(user.id);
      if (clientData == null) return;

      final lastMeas = await _supa
          .from('measurements')
          .select('weight_kg, height_cm')
          .eq('client_id', clientData['id'])
          .order('date_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (lastMeas != null && mounted) {
        setState(() {
          _weightCtrl.text = lastMeas['weight_kg'].toString();
          _heightCtrl.text = lastMeas['height_cm'].toString();
        });
      }
    } catch (e) {
      debugPrint('Error cargando datos previos: $e');
    }
  }

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

  // --- SOLO DESCARGAR DIETA (CLIENTE) ---
  Future<void> _openExistingDiet() async {
    setState(() => _isLoadingDiet = true);
    try {
      final user = _supa.auth.currentUser;
      if (user == null) return;

      final clientRes = await _getClientId(user.id);
      if (clientRes == null) {
        if (mounted) _showSnack('Error: Perfil no encontrado', Colors.red);
        return;
      }

      // Intentamos abrir la última dieta
      final found = await _dietService.openLastDiet(clientRes['id']);

      if (!found && mounted) {
        // Mensaje diferente: Ahora depende del entrenador
        _showSnack(
          'Tu entrenador aún no ha publicado tu plan nutricional.',
          Colors.orange,
        );
      }
    } catch (e) {
      if (mounted) _showSnack('Error al abrir: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoadingDiet = false);
    }
  }

  // --- GUARDAR REGISTRO (FOTOS Y MEDIDAS) ---
  Future<void> _saveCheckIn() async {
    if (_weightCtrl.text.isEmpty) {
      _showSnack('El peso es obligatorio', Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = _supa.auth.currentUser;
      if (user == null) throw Exception('No autenticado');

      final clientData = await _getClientId(user.id);
      if (clientData == null) throw Exception('Cliente no encontrado');

      final clientId = clientData['id'];

      // 1. Insertar Medidas
      final measurementData = await _supa
          .from('measurements')
          .insert({
            'client_id': clientId,
            'weight_kg': double.tryParse(_weightCtrl.text) ?? 0,
            'height_cm': double.tryParse(_heightCtrl.text) ?? 0,
            'date_at': DateTime.now().toIso8601String(),
            'notes': 'Check-in cliente',
          })
          .select('id')
          .single();

      final String measurementId = measurementData['id'];

      // 2. Subir Fotos
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
        _showSnack(
          '¡Progreso enviado a tu entrenador!',
          const Color(0xFFCCFF00),
        );
        _clearForm();
      }
    } catch (e) {
      if (mounted) _showSnack('Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- HELPERS ---
  Future<Map<String, dynamic>?> _getClientId(String authUserId) async {
    final userProfile = await _supa
        .from('app_user')
        .select('id')
        .eq('auth_user_id', authUserId)
        .maybeSingle();

    if (userProfile == null) return null;
    final userClientId = userProfile['id'];

    return await _supa
        .from('clients')
        .select('id')
        .eq('app_user_id', userClientId)
        .maybeSingle();
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
    });
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    return Scaffold(
      appBar: AppBar(title: const Text('Mi Progreso')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SECCIÓN 1: PLAN NUTRICIONAL (Solo lectura)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.restaurant_menu, color: Colors.greenAccent),
                      SizedBox(width: 10),
                      Text(
                        "Plan Nutricional",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Descarga el plan diseñado por tu entrenador.",
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(height: 15),
                  SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: ElevatedButton.icon(
                      onPressed: _isLoadingDiet ? null : _openExistingDiet,
                      icon: _isLoadingDiet
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Icon(Icons.download_rounded),
                      label: const Text("DESCARGAR MI DIETA PDF"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.greenAccent,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),
            const Divider(color: Colors.white12),
            const SizedBox(height: 20),

            // SECCIÓN 2: REGISTRO DE PROGRESO
            const Text(
              'Actualizar Medidas',
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

            const SizedBox(height: 25),
            Text(
              'Fotos de Control',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[300],
              ),
            ),
            const SizedBox(height: 10),

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

            const SizedBox(height: 30),

            // BOTÓN DE GUARDAR
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
                        'ENVIAR REPORTE AL ENTRENADOR',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 50),
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

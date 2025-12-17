import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Asegúrate de que la ruta a tu servicio sea correcta
import '../../common/services/diet_service.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  @override
  void initState() {
    super.initState();
    // Apenas carga la pantalla, buscamos los datos anteriores
    _loadLastMeasurement();
  }

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

  bool _isLoading = false; // Cargando subida de fotos
  bool _isGeneratingDiet = false; // Cargando generación IA
  bool _isLoadingDiet = false; // Cargando descarga de dieta existente

  // --- SELECCIONAR FOTO ---
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

  // --- 1. ABRIR DIETA EXISTENTE (SIN IA) ---
  Future<void> _openExistingDiet() async {
    setState(() => _isLoadingDiet = true);
    try {
      final user = _supa.auth.currentUser;
      if (user == null) return;

      // Obtener el ID del cliente
      final clientRes = await _getClientId(user.id);
      if (clientRes == null) {
        if (mounted) _showSnack('Error: Cliente no encontrado', Colors.red);
        return;
      }

      // Llamar al servicio para buscar la última dieta
      final found = await _dietService.openLastDiet(clientRes['id']);

      if (!found && mounted) {
        _showSnack(
          'No tienes ninguna dieta guardada aún. Genera una nueva.',
          Colors.orange,
        );
      }
    } catch (e) {
      if (mounted) _showSnack('Error abriendo dieta: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoadingDiet = false);
    }
  }

  // --- CARGAR ÚLTIMO PESO/ALTURA AUTOMÁTICAMENTE ---
  Future<void> _loadLastMeasurement() async {
    try {
      final user = _supa.auth.currentUser;
      if (user == null) return;

      // 1. Obtener ID del cliente (reusamos tu helper)
      final clientData = await _getClientId(user.id);
      if (clientData == null) return;

      // 2. Buscar la medición más reciente en la base de datos
      final lastMeas = await _supa
          .from('measurements')
          .select('weight_kg, height_cm')
          .eq('client_id', clientData['id'])
          .order(
            'date_at',
            ascending: false,
          ) // Ordenar por fecha (más nuevo primero)
          .limit(1) // Solo queremos 1
          .maybeSingle();

      // 3. Si existe, rellenamos los campos de texto
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

  // --- 2. GENERAR NUEVA DIETA PDF (CON IA) ---
  Future<void> _createDietPdf() async {
    // Validaciones básicas
    if (_weightCtrl.text.isEmpty || _heightCtrl.text.isEmpty) {
      _showSnack('Ingresa peso y altura actual primero', Colors.orange);
      return;
    }

    setState(() => _isGeneratingDiet = true);

    try {
      final user = _supa.auth.currentUser;
      if (user == null) return;

      // A. Obtener datos del cliente (ID y Objetivo)
      final clientData = await _getClientId(user.id, fetchGoal: true);

      if (clientData != null) {
        final clientId = clientData['id'];

        // B. OBTENER LAS FOTOS RECIENTES DE SUPABASE
        // Buscamos las últimas 4 fotos subidas para enviárselas a la IA.
        final photosRes = await _supa
            .from('progress_photos')
            .select('url')
            .eq('client_id', clientId)
            .order('taken_at', ascending: false)
            .limit(4);

        List<String> realPhotoUrls = List<String>.from(
          (photosRes as List).map((item) => item['url']),
        );

        // C. Llamar al servicio (Edge Function)
        await _dietService.generateAndSaveDiet(
          clientId: clientId,
          currentWeight: double.parse(_weightCtrl.text),
          height: double.parse(_heightCtrl.text),
          goal: clientData['goal'] ?? 'Mejorar composición corporal',
          photoUrls: realPhotoUrls, // ¡Fotos reales! 📸
        );

        if (mounted) {
          _showSnack(
            '¡Dieta generada y guardada exitosamente! 🥗',
            Colors.purpleAccent,
          );
        }
      }
    } catch (e) {
      if (mounted) _showSnack('Error generando dieta: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isGeneratingDiet = false);
    }
  }

  // --- 3. GUARDAR REGISTRO (FOTOS Y MEDIDAS) ---
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

      // Insertar medidas
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

      // Subir fotos
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
        _showSnack('¡Registro guardado exitosamente!', const Color(0xFFCCFF00));
        _clearForm();
      }
    } catch (e) {
      if (mounted) _showSnack('Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- HELPERS ---

  // Obtener ID del cliente desde la tabla 'app_user' -> 'clients'
  Future<Map<String, dynamic>?> _getClientId(
    String authUserId, {
    bool fetchGoal = false,
  }) async {
    // 1. Buscar app_user
    final userProfile = await _supa
        .from('app_user')
        .select('id')
        .eq('auth_user_id', authUserId)
        .maybeSingle();

    if (userProfile == null) return null;
    final userClientId = userProfile['id'];

    // 2. Buscar clients
    final selectQuery = fetchGoal ? 'id, goal' : 'id';

    return await _supa
        .from('clients')
        .select(selectQuery)
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
      // No borramos peso/altura para que sea facil generar la dieta después
    });
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  // --- UI ---

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

            // --- BOTONES DE ACCIÓN ---

            // 1. GUARDAR REGISTRO (Principal)
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

            const SizedBox(height: 30),
            const Divider(color: Colors.white24),
            const SizedBox(height: 10),

            const Text(
              "Tu Plan Nutricional",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 15),

            // 2. VER DIETA ACTUAL (Botón Verde)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: _isLoadingDiet ? null : _openExistingDiet,
                icon: _isLoadingDiet
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.description, color: Colors.greenAccent),
                label: const Text("VER MI DIETA ACTUAL 🥗"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.greenAccent,
                  side: const BorderSide(color: Colors.greenAccent),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 15),

            // 3. GENERAR NUEVA DIETA (Botón Morado)
            SizedBox(
              width: double.infinity,
              height: 50,
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
                      : ' GENERAR NUEVA CON IA ✨',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
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

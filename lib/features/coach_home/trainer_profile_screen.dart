import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart'; // 1. IMPORTAR ESTO

import '../admin/exercises_screen.dart';

class TrainerProfileScreen extends StatefulWidget {
  const TrainerProfileScreen({super.key});

  @override
  State<TrainerProfileScreen> createState() => _TrainerProfileScreenState();
}

class _TrainerProfileScreenState extends State<TrainerProfileScreen> {
  final _supa = Supabase.instance.client;
  bool _isLoading = false;
  String? _localAvatarUrl; // Para mostrar la foto apenas se sube

  // --- LÓGICA DE SUBIDA DE FOTO ---
  Future<void> _uploadPhoto() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70, // Comprimir un poco para ahorrar datos
      maxWidth: 500, // Redimensionar si es muy grande
    );

    if (image == null) return; // Usuario canceló

    setState(() => _isLoading = true);

    try {
      final user = _supa.auth.currentUser;
      if (user == null) return;

      final imageBytes = await image.readAsBytes();
      final fileExt = image.path.split('.').last;
      final fileName =
          '${user.id}/avatar.${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      // 1. Subir a Supabase Storage
      await _supa.storage
          .from('avatars')
          .uploadBinary(
            fileName,
            imageBytes,
            fileOptions: const FileOptions(upsert: true),
          );

      // 2. Obtener la URL pública
      final imageUrl = _supa.storage.from('avatars').getPublicUrl(fileName);

      // 3. Actualizar metadatos del usuario (Auth)
      await _supa.auth.updateUser(
        UserAttributes(data: {'avatar_url': imageUrl}),
      );

      // 4. Actualizar tabla pública (app_user) si la usas para mostrar fotos en otros lados
      // (Opcional pero recomendado para consistencia)
      /* await _supa.from('app_user')
        .update({'avatar_url': imageUrl})
        .eq('auth_user_id', user.id);
      */

      if (mounted) {
        setState(() {
          _localAvatarUrl = imageUrl; // Actualizar vista local
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto actualizada correctamente ✅')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al subir foto: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => _isLoading = true);
    try {
      await _supa.auth.signOut();
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
    final name = user?.userMetadata?['full_name'] ?? 'Coach';

    // Usamos la URL local si acabamos de subirla, sino la guardada en Supabase
    final avatarUrl = _localAvatarUrl ?? user?.userMetadata?['avatar_url'];

    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 20),

              // --- AVATAR INTERACTIVO ---
              Stack(
                children: [
                  GestureDetector(
                    onTap: _isLoading ? null : _uploadPhoto, // Clic para subir
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFBF5AF2),
                          width: 3,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.white10,
                        backgroundImage: (avatarUrl != null)
                            ? NetworkImage(avatarUrl)
                            : null,
                        child: (avatarUrl == null)
                            ? const Icon(
                                Icons.person,
                                size: 60,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ),
                  ),
                  // Icono de camarita para indicar que se puede editar
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFBF5AF2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  // Loading spinner sobre el avatar
                  if (_isLoading)
                    const Positioned.fill(
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),

              const SizedBox(height: 20),

              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              // ... RESTO DE TU CÓDIGO ...
              const SizedBox(height: 8),
              Text(
                email,
                style: const TextStyle(color: Colors.white54, fontSize: 16),
              ),
              const SizedBox(height: 12),

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

              const SizedBox(height: 50),

              // ... TUS BOTONES SIGUEN IGUAL AQUÍ ABAJO ...
              // (Biblioteca de ejercicios, Cerrar sesión, etc. - CÓPIALOS DE TU ARCHIVO ORIGINAL)
              // Solo asegúrate de copiar el código desde 'ListTile' hacia abajo.
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFBF5AF2).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.fitness_center,
                      color: Color(0xFFBF5AF2),
                      size: 24,
                    ),
                  ),
                  title: const Text(
                    'Biblioteca de Ejercicios',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Crea tus ejercicios y consulta los globales',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.white24,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const ExercisesScreen(isCoachMode: true),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 30),

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
                  icon: const Icon(Icons.logout),
                  label: Text(_isLoading ? 'Cerrando...' : 'CERRAR SESIÓN'),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}

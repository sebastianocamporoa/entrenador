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
        // Redirigir al Login y borrar historial
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

  // --- MOSTRAR TÉRMINOS Y CONDICIONES ---
  void _showTermsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Permite que ocupe casi toda la pantalla
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85, // 85% de altura
        decoration: const BoxDecoration(
          color: Color(0xFF1C1C1E), // Mismo fondo de la app
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
        child: Column(
          children: [
            // Indicador de arrastre
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Título del Modal
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Términos y Condiciones',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(color: Colors.white10),
            // Contenido Scrollable
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 40, top: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _TermHeader(text: 'TÉRMINOS Y CONDICIONES DE USO'),
                    _TermText(
                      text:
                          'Bienvenido a nuestro servicio. Al utilizar nuestra aplicación móvil/web, usted acepta los siguientes términos que rigen la relación entre el usuario y el servicio de entrenamiento personalizado prestado.',
                    ),
                    SizedBox(height: 20),
                    _TermSection(
                      title: '1. NATURALEZA DEL SERVICIO',
                      content:
                          'Esta aplicación es una herramienta tecnológica de soporte diseñada para facilitar la prestación del servicio de entrenamiento personalizado. Sus funciones incluyen la visualización de programas, consulta de planes nutricionales, gestión de pagos y administración de agenda. La app no constituye el servicio por sí sola, sino que es el medio de gestión del programa contratado.',
                    ),
                    _TermSection(
                      title: '2. REQUISITOS DE SALUD Y RESPONSABILIDAD',
                      content:
                          'Declaración de Salud: El usuario garantiza que se encuentra en condiciones físicas aptas para el ejercicio.\n\nExoneración: El uso de las rutinas cargadas en la app fuera de la supervisión presencial del entrenador es bajo riesgo del usuario. No nos hacemos responsables por lesiones derivadas de una técnica de ejecución incorrecta por parte del cliente.',
                    ),
                    _TermSection(
                      title: '3. PLAN NUTRICIONAL PERSONALIZADO',
                      content:
                          'Toda la información dietética es personalizada según los datos suministrados (peso, edad, objetivos, patologías).\n\nLos planes son de uso estrictamente personal. Queda prohibida la distribución o venta de las dietas diseñadas por el especialista.\n\nLa precisión de los resultados depende de la veracidad de la información proporcionada por el usuario.',
                    ),
                    _TermSection(
                      title: '4. GESTIÓN DE PAGOS Y ACCESO',
                      content:
                          'El acceso a los contenidos premium (rutinas y dietas) está vinculado a una suscripción activa o plan vigente.\n\nAl expirar el plan contratado, la plataforma podrá restringir automáticamente el acceso a los módulos de entrenamiento y nutrición hasta que se procese un nuevo pago.',
                    ),
                    _TermSection(
                      title: '5. POLÍTICA DE AGENDA Y CANCELACIONES',
                      content:
                          'La reserva de sesiones se realizará exclusivamente a través del módulo de agenda de la app.\n\nCancelación Extemporánea: Toda sesión cancelada con menos de 12 horas de antelación se descontará automáticamente del saldo de clases del usuario, sin excepción ni derecho a reposición.',
                    ),
                    _TermSection(
                      title: '6. REGISTRO DE PROGRESO VISUAL (FOTOS)',
                      content:
                          'Uso Técnico: El usuario podrá cargar fotos de seguimiento. Estas imágenes se utilizarán únicamente para evaluar la evolución física y ajustar los planes.\n\nConfidencialidad: Las fotos están protegidas y no serán utilizadas con fines de marketing, publicidad o redes sociales sin una autorización previa, específica y por escrito del usuario.\n\nSeguridad: Las imágenes se alojan en servidores seguros con acceso restringido.',
                    ),
                    _TermSection(
                      title: '7. PROPIEDAD INTELECTUAL',
                      content:
                          'El diseño de la aplicación, así como los algoritmos, programas de entrenamiento y estructuras nutricionales, son propiedad intelectual de la marca. El usuario tiene una licencia de uso personal y no puede copiar, reproducir o comercializar el contenido de la plataforma.',
                    ),
                    _TermSection(
                      title: '8. MODIFICACIONES',
                      content:
                          'Nos reservamos el derecho de actualizar estos términos para adaptarlos a nuevas funciones de la app. El uso continuado del servicio implica la aceptación de las nuevas condiciones.',
                    ),
                    SizedBox(height: 20),
                    Center(
                      child: Text(
                        'Última actualización: Diciembre 2025',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _supa.auth.currentUser;
    final email = user?.email ?? 'Usuario';
    final name = user?.userMetadata?['full_name'] ?? 'Atleta';
    final avatarUrl = user?.userMetadata?['avatar_url'];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
              // --- AQUÍ CONECTAMOS LA LÓGICA DE TÉRMINOS ---
              _buildListTile(
                icon: Icons.info_outline,
                title: 'Términos y Condiciones',
                onTap: _showTermsModal, // <--- Conectado aquí
              ),

              const SizedBox(height: 30),

              // 4. BOTÓN CERRAR SESIÓN
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _signOut,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.withOpacity(0.1),
                    foregroundColor: Colors.redAccent,
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
        color: const Color(0xFF1E1E1E),
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

// --- WIDGETS PARA EL TEXTO DE TÉRMINOS (Limpieza de código) ---

class _TermHeader extends StatelessWidget {
  final String text;
  const _TermHeader({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _TermSection extends StatelessWidget {
  final String title;
  final String content;
  const _TermSection({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFBF5AF2), // Color de acento
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          _TermText(text: content),
        ],
      ),
    );
  }
}

class _TermText extends StatelessWidget {
  final String text;
  const _TermText({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 14,
        height: 1.5, // Mejor lectura
      ),
    );
  }
}

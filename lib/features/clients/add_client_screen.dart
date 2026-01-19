import 'dart:math'; // Para generar contraseña aleatoria
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart'; // <--- IMPORTANTE

class AddClientScreen extends StatefulWidget {
  const AddClientScreen({super.key});

  @override
  State<AddClientScreen> createState() => _AddClientScreenState();
}

class _AddClientScreenState extends State<AddClientScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controladores
  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final phoneCtrl = TextEditingController(); // <--- NUEVO: Para WhatsApp
  final passCtrl = TextEditingController();

  bool loading = false;
  bool passVisible = false;

  // Utilidad para generar contraseña rápida
  void _generatePassword() {
    final random = Random().nextInt(9000) + 1000;
    passCtrl.text = 'Gym$random!';
    setState(() {});
  }

  // Utilidad para abrir WhatsApp
  Future<void> _sendWhatsApp() async {
    // 1. Limpiamos el número (quitamos espacios, guiones, parentesis)
    // Asumimos código de país. Si es Colombia es 57. Puedes ajustarlo o pedirlo en el input.
    String rawPhone = phoneCtrl.text.trim().replaceAll(RegExp(r'[^0-9]'), '');

    // Si el usuario no puso el indicativo (ej: 300...), le agregamos 57.
    // Ajusta esto según tu país principal.
    if (!rawPhone.startsWith('57') && rawPhone.length == 10) {
      rawPhone = '57$rawPhone';
    }

    final name = nameCtrl.text.trim();
    final email = emailCtrl.text.trim();
    final password = passCtrl.text.trim();

    // 2. Crear el mensaje
    final message =
        "Hola $name! 💪 Bienvenido al equipo.\n\n"
        "Ya creé tu cuenta en la App. Aquí tienes tus accesos:\n"
        "📧 Usuario: $email\n"
        "🔒 Clave: $password\n\n"
        "Descarga la app y comencemos a entrenar!";

    // 3. Convertir a URL
    final encodedMessage = Uri.encodeComponent(message);
    final whatsappUrl = Uri.parse(
      "https://wa.me/$rawPhone?text=$encodedMessage",
    );

    // 4. Lanzar
    try {
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir WhatsApp')),
        );
      }
    } catch (e) {
      print('Error lanzando WhatsApp: $e');
    }
  }

  // Función principal de registro
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => loading = true);

    try {
      final supabase = Supabase.instance.client;
      final coachId = supabase.auth.currentUser?.id;

      if (coachId == null) throw 'No se pudo identificar tu sesión';

      // ---------------------------------------------------------
      // LLAMADA A TU EDGE FUNCTION (Crea el usuario en BD)
      // ---------------------------------------------------------
      final response = await supabase.functions.invoke(
        'send-email', // Mantenemos el nombre aunque ahora usaremos WhatsApp
        body: {
          'email': emailCtrl.text.trim(),
          'password': passCtrl.text.trim(),
          'fullName': nameCtrl.text.trim(),
          'coachId': coachId,
          // 'phone': phoneCtrl.text.trim(), // Opcional: si actualizas tu Edge Function para guardar el teléfono
        },
      );

      if (response.status != 200) {
        final errorBody = response.data;
        throw errorBody['error'] ?? 'Error al procesar el registro';
      }

      if (!mounted) return;

      // ---------------------------------------------------------
      // ÉXITO: MOSTRAR DIÁLOGO DE WHATSAPP
      // ---------------------------------------------------------
      setState(() => loading = false); // Paramos el loading visual

      showDialog(
        context: context,
        barrierDismissible: false, // Obliga a elegir una opción
        builder: (ctx) => AlertDialog(
          title: const Text('¡Cuenta Creada!'),
          content: const Text(
            'El usuario ha sido registrado exitosamente.\n\n'
            '¿Quieres enviarle sus credenciales ahora mismo por WhatsApp?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx); // Cierra diálogo
                Navigator.pop(context, true); // Cierra pantalla y recarga lista
              },
              child: const Text('No, salir'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.send),
              label: const Text('Enviar WhatsApp'),
              style: FilledButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () {
                _sendWhatsApp(); // Abre WhatsApp
                Navigator.pop(ctx); // Cierra diálogo
                Navigator.pop(context, true); // Cierra pantalla
              },
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
      );
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFBF5AF2);
    const inputBorderColor = Colors.white24;

    return Scaffold(
      appBar: AppBar(title: const Text('Registrar Cliente')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Datos de la cuenta',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Se creará el usuario y podrás enviar las credenciales por WhatsApp.',
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 24),

              // CAMPO NOMBRE
              TextFormField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Nombre Completo',
                  prefixIcon: Icon(Icons.person_outline, color: Colors.white54),
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: inputBorderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: accent),
                  ),
                ),
                validator: (v) =>
                    v!.isEmpty ? 'El nombre es obligatorio' : null,
              ),
              const SizedBox(height: 20),

              // CAMPO EMAIL
              TextFormField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Correo Electrónico',
                  prefixIcon: Icon(Icons.email_outlined, color: Colors.white54),
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: inputBorderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: accent),
                  ),
                ),
                validator: (v) => !v!.contains('@') ? 'Correo inválido' : null,
              ),
              const SizedBox(height: 20),

              // CAMPO CELULAR (NUEVO)
              TextFormField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Celular (WhatsApp)',
                  prefixIcon: Icon(Icons.phone_android, color: Colors.white54),
                  hintText: 'Ej: 3001234567',
                  hintStyle: TextStyle(color: Colors.white24),
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: inputBorderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: accent),
                  ),
                ),
                validator: (v) => v!.length < 7 ? 'Número inválido' : null,
              ),
              const SizedBox(height: 20),

              // CAMPO CONTRASEÑA
              TextFormField(
                controller: passCtrl,
                obscureText: !passVisible,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Asignar Contraseña',
                  prefixIcon: const Icon(
                    Icons.lock_outline,
                    color: Colors.white54,
                  ),
                  border: const OutlineInputBorder(),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: inputBorderColor),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: accent),
                  ),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          passVisible ? Icons.visibility : Icons.visibility_off,
                          color: Colors.white54,
                        ),
                        onPressed: () =>
                            setState(() => passVisible = !passVisible),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: accent),
                        tooltip: 'Generar aleatoria',
                        onPressed: _generatePassword,
                      ),
                    ],
                  ),
                ),
                validator: (v) => v!.length < 6 ? 'Mínimo 6 caracteres' : null,
              ),
              const SizedBox(height: 30),

              // BOTÓN GUARDAR
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: loading ? null : _submit,
                  style: FilledButton.styleFrom(backgroundColor: accent),
                  child: loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Registrar Cliente',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:math'; // Para generar contraseña aleatoria
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddClientScreen extends StatefulWidget {
  const AddClientScreen({super.key});

  @override
  State<AddClientScreen> createState() => _AddClientScreenState();
}

class _AddClientScreenState extends State<AddClientScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controladores para los datos que pide tu Edge Function
  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();

  bool loading = false;
  bool passVisible = false;

  // Utilidad para generar contraseña rápida si el coach lo desea
  void _generatePassword() {
    final random =
        Random().nextInt(9000) + 1000; // Genera nro entre 1000 y 9999
    passCtrl.text = 'Gym$random!'; // Ej: Gym5823!
    setState(() {});
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => loading = true);

    try {
      final supabase = Supabase.instance.client;
      final coachId = supabase.auth.currentUser?.id;

      if (coachId == null) throw 'No se pudo identificar tu sesión';

      // ---------------------------------------------------------
      // LLAMADA A TU EDGE FUNCTION 'send-email'
      // ---------------------------------------------------------
      final response = await supabase.functions.invoke(
        'send-email',
        body: {
          'email': emailCtrl.text.trim(),
          'password': passCtrl.text.trim(),
          'fullName': nameCtrl.text.trim(),
          'coachId': coachId,
        },
      );

      // Verificamos si la función respondió con error (status diferente de 2xx)
      if (response.status != 200) {
        final errorBody =
            response.data; // Supabase suele devolver el error en 'data'
        throw errorBody['error'] ?? 'Error al procesar el registro';
      }

      if (!mounted) return;

      // Éxito
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Cliente creado y correo enviado!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true); // Regresamos 'true' para recargar la lista
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFBF5AF2);
    // Mantenemos el estilo oscuro que tenías
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
                'Al guardar, se enviará un correo al cliente con estas credenciales.',
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

              // CAMPO CONTRASEÑA (Con generador)
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
                      // Botón para ver contraseña
                      IconButton(
                        icon: Icon(
                          passVisible ? Icons.visibility : Icons.visibility_off,
                          color: Colors.white54,
                        ),
                        onPressed: () =>
                            setState(() => passVisible = !passVisible),
                      ),
                      // Botón para generar aleatoria
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
                          'Registrar y Enviar Correo',
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

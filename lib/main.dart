import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// 👇 Vistas y servicios que usamos según el rol
import 'common/services/user_service.dart';
import 'features/client_home/client_home_screen.dart';
import 'features/coach_home/coach_home_screen.dart';
import 'features/clients/clients_page.dart';
import 'features/admin/admin_home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Recomendado: pasar credenciales por --dart-define
  const supaUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://vvvyopzfmjyqjnxhtjkv.supabase.co',
  );
  const supaAnon = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    // ⚠️ Puedes borrar el defaultValue en prod y usar solo --dart-define
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ2dnlvcHpmbWp5cWpueGh0amt2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk3MjExMTgsImV4cCI6MjA3NTI5NzExOH0.Zhaec_J__SAsg55cG-szjiXLClBZzHbNVaeUgHeNyAc',
  );

  await Supabase.initialize(url: supaUrl, anonKey: supaAnon);
  runApp(const EntrenadorApp());
}

class EntrenadorApp extends StatelessWidget {
  const EntrenadorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Entrenador',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const AuthGate(),
    );
  }
}

/// Si hay sesión → resolvemos rol y mostramos pantalla correspondiente.
/// Si no hay sesión → Login/Registro.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<AuthState>? _authSub;
  final _userSrv = UserService();

  @override
  void initState() {
    super.initState();
    // Redibuja cuando cambie el estado de autenticación y asegura el perfil
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((
      state,
    ) async {
      await _ensureProfileClient();
      if (mounted) setState(() {});
    });
    // También al iniciar si ya hay sesión
    _ensureProfileClient();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return const LoginPage();

    return FutureBuilder<String?>(
      future: _userSrv.getRole(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snap.hasError || snap.data == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Resolviendo rol')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No pude determinar tu rol.\n${snap.error ?? ''}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FilledButton.icon(
                          onPressed: () => setState(() {}),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reintentar'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () async {
                            await Supabase.instance.client.auth.signOut();
                          },
                          icon: const Icon(Icons.logout),
                          label: const Text('Cerrar sesión'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final role = snap.data!;
        if (role == 'admin') return const AdminHomeScreen();
        if (role == 'coach') return const CoachHomeScreen();
        return const ClientHomeScreen();
      },
    );
  }

  /// Crea/asegura un perfil en `app_user` con rol `client` (idempotente).
  Future<void> _ensureProfileClient() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final supa = Supabase.instance.client;

    try {
      final exists = await supa
          .from('app_user')
          .select('auth_user_id')
          .eq('auth_user_id', user.id)
          .maybeSingle();

      // 👇 Solo crear si no existe, no modificar si ya está
      if (exists == null) {
        await supa.from('app_user').insert({
          'auth_user_id': user.id,
          'role': 'client',
          'full_name':
              user.userMetadata?['full_name'] ?? user.email?.split('@').first,
          'email': user.email,
        });
      }
    } catch (e) {
      debugPrint('Error asegurando perfil: $e');
    }
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool isLogin = true; // alterna entre login y registro
  bool loading = false;
  String? errorMsg;

  Future<void> _submit() async {
    setState(() {
      loading = true;
      errorMsg = null;
    });

    try {
      final auth = Supabase.instance.client.auth;

      if (isLogin) {
        // LOGIN
        await auth.signInWithPassword(
          email: emailCtrl.text.trim(),
          password: passCtrl.text,
        );
      } else {
        // REGISTRO
        final resp = await auth.signUp(
          email: emailCtrl.text.trim(),
          password: passCtrl.text,
          data: {'full_name': emailCtrl.text.trim().split('@').first},
        );

        // Si el proyecto requiere verificación de email, NO habrá sesión aún
        if (resp.session == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Te enviamos un correo de verificación. Abre el enlace para activar tu cuenta e iniciar sesión.',
              ),
            ),
          );
          return; // Nos quedamos en la pantalla de login/registro
        }
      }

      // Tras login/registro con sesión activa, asegura perfil como client (idempotente)
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final supa = Supabase.instance.client;
        try {
          // Solo crear el registro si no existe
          final existing = await supa
              .from('app_user')
              .select('role')
              .eq('auth_user_id', user.id)
              .maybeSingle();

          if (existing == null) {
            await supa.from('app_user').insert({
              'auth_user_id': user.id,
              'role': 'client',
              'full_name':
                  user.userMetadata?['full_name'] ??
                  user.email?.split('@').first,
              'email': user.email,
            });
          }
        } catch (_) {
          // no bloquear el flujo si falla por RLS o existe ya
        }
      }
    } on AuthException catch (e) {
      setState(() => errorMsg = e.message);
    } catch (e) {
      setState(() => errorMsg = 'Error inesperado: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = isLogin ? 'Iniciar sesión' : 'Crear cuenta';
    final action = isLogin ? 'Entrar' : 'Registrarme';

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 16),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Contraseña'),
                ),
                const SizedBox(height: 12),
                if (errorMsg != null)
                  Text(
                    errorMsg!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: loading ? null : _submit,
                    child: Text(loading ? 'Procesando...' : action),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => setState(() => isLogin = !isLogin),
                  child: Text(
                    isLogin
                        ? '¿No tienes cuenta? Crear una'
                        : '¿Ya tienes cuenta? Inicia sesión',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ⬇️ Útil para pruebas puntuales desde el home del coach (ya tienes ClientsPage)
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Entrenador'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: FilledButton(
          onPressed: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ClientsPage()));
          },
          child: const Text('Ir a Clientes'),
        ),
      ),
    );
  }
}

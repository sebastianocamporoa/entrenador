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

  const supaUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://vvvyopzfmjyqjnxhtjkv.supabase.co',
  );
  const supaAnon = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
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
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;
  late final Animation<double> _lineMove;
  final Color _accent = const Color(0xFFBF5AF2);

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );

    _opacity = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
    );
    _scale = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOutBack),
    );
    _lineMove = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
    );

    _c.forward().whenComplete(() async {
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      final session = Supabase.instance.client.auth.currentSession;
      final next = (session == null)
          ? const OnboardingPage()
          : const AuthGate();
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => next));
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0x001c1c1e),
      body: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final width = MediaQuery.of(context).size.width;
          return Stack(
            children: [
              // Línea superior diagonal
              Positioned(
                top: MediaQuery.of(context).size.height * 0.35,
                left: -width * (1 - _lineMove.value),
                child: Transform.rotate(
                  angle: -0.05,
                  child: Container(
                    width: width * 1.2,
                    height: 1.2,
                    color: _accent,
                  ),
                ),
              ),
              // Texto central
              Center(
                child: Opacity(
                  opacity: _opacity.value,
                  child: Transform.scale(
                    scale: 0.9 + 0.1 * _scale.value,
                    child: Text(
                      'Entrenador',
                      style: const TextStyle(
                        color: Color(0xFFBF5AF2),
                        fontSize: 48,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
              // Línea inferior diagonal
              Positioned(
                bottom: MediaQuery.of(context).size.height * 0.35,
                right: -width * (1 - _lineMove.value),
                child: Transform.rotate(
                  angle: -0.05,
                  child: Container(
                    width: width * 1.2,
                    height: 1.2,
                    color: _accent,
                  ),
                ),
              ),
            ],
          );
        },
      ),
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
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((
      state,
    ) async {
      await _ensureProfileClient();
      if (mounted) setState(() {});
    });
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
  bool isLogin = true;
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
        await auth.signInWithPassword(
          email: emailCtrl.text.trim(),
          password: passCtrl.text,
        );
      } else {
        final resp = await auth.signUp(
          email: emailCtrl.text.trim(),
          password: passCtrl.text,
          data: {'full_name': emailCtrl.text.trim().split('@').first},
        );

        if (resp.session == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Te enviamos un correo de verificación. Abre el enlace para activar tu cuenta e iniciar sesión.',
              ),
            ),
          );
          return;
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
  Widget build(BuildContext context) {
    const accent = Color(0xFFBF5AF2);
    const background = Color(0xFF1C1C1E);
    const formBackground = Color(0xFF111111);
    const textColor = Color(0xFFD9D9D9);

    final title = isLogin ? 'Bienvenido de nuevo,' : 'Crea tu cuenta';
    final subtitle = isLogin ? 'Entrena con nosotros' : 'Comienza tu viaje';
    final action = isLogin ? 'Entrar' : 'Registrarme';

    return Scaffold(
      backgroundColor: background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            // 🔹 Imagen con diagonal y título
            Stack(
              children: [
                ClipPath(
                  clipper: _DiagonalClipper(),
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height * 0.52,
                    width: double.infinity,
                    child: Image.asset(
                      'assets/login_bg.jpg',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          formBackground,
                          formBackground.withOpacity(0.7),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.25, 0.8],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 24,
                  bottom: 100,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // 🔹 Solo el formulario se ajusta y hace scroll
            Flexible(
              child: Container(
                width: double.infinity,
                color: formBackground,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      TextField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: textColor),
                        decoration: InputDecoration(
                          labelText: 'Correo electrónico',
                          labelStyle: const TextStyle(color: Colors.white70),
                          enabledBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white24),
                          ),
                          focusedBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(color: accent),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: passCtrl,
                        obscureText: true,
                        style: const TextStyle(color: textColor),
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          labelStyle: const TextStyle(color: Colors.white70),
                          enabledBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white24),
                          ),
                          focusedBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(color: accent),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {},
                          child: const Text(
                            '¿Olvidaste tu contraseña?',
                            style: TextStyle(color: accent, fontSize: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          onPressed: loading ? null : _submit,
                          child: Text(
                            loading ? 'Procesando...' : action,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => setState(() => isLogin = !isLogin),
                        child: Text(
                          isLogin
                              ? '¿No tienes cuenta? Regístrate'
                              : '¿Ya tienes cuenta? Inicia sesión',
                          style: const TextStyle(color: textColor),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  //TODO: corregir vista al abrir el teclado
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

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _controller = PageController();
  int _page = 0;

  final _pages = [
    _OnboardData(
      image: 'assets/onboard1.jpg',
      title: 'Conecta con tu entrenador',
      subtitle: 'Empieza tu transformación hoy',
    ),
    _OnboardData(
      image: 'assets/onboard2.jpg',
      title: 'Planes hechos para ti',
      subtitle: 'Entrena con propósito y constancia',
    ),
    _OnboardData(
      image: 'assets/onboard3.jpg',
      title: 'Mide tu progreso',
      subtitle: 'Ve tus resultados y supera tus límites',
      showButton: true,
    ),
  ];

  void _next() {
    if (_page < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    } else {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = const Color(0xFFBF5AF2);

    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          PageView.builder(
            controller: _controller,
            onPageChanged: (i) => setState(() => _page = i),
            itemCount: _pages.length,
            itemBuilder: (_, i) => _OnboardSlide(data: _pages[i]),
          ),
          Positioned(
            bottom: 70, // 🔹 Subido un poco (antes era 40)
            child: Row(
              children: List.generate(
                _pages.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _page ? 52 : 25, // 🔹 Más ancho el activo
                  height: 4,
                  decoration: BoxDecoration(
                    color: i == _page ? accent : Colors.grey.shade700,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),

          if (_pages[_page].showButton)
            Positioned(
              bottom: 120,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 36,
                    vertical: 14,
                  ),
                ),
                onPressed: _next,
                child: const Text(
                  'Comienza ahora!',
                  style: TextStyle(
                    color: Colors.white,
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

class _OnboardData {
  final String image;
  final String title;
  final String subtitle;
  final bool showButton;

  _OnboardData({
    required this.image,
    required this.title,
    required this.subtitle,
    this.showButton = false,
  });
}

class _OnboardSlide extends StatelessWidget {
  final _OnboardData data;
  const _OnboardSlide({required this.data});

  @override
  Widget build(BuildContext context) {
    final background = const Color(0xFF1C1C1E);
    const textColor = Color(0xFFD9D9D9);

    return Container(
      color: background,
      child: Column(
        children: [
          // 🔹 Parte superior: imagen con degradado + clip diagonal
          ClipPath(
            clipper: _DiagonalClipper(),
            child: Stack(
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  width: double.infinity,
                  child: Image.asset(data.image, fit: BoxFit.cover),
                ),
                // 🔹 Degradado inferior
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.center,
                        colors: [
                          background.withOpacity(0.95),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 🔹 Parte inferior (contenido)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.start, // 🔹 texto más arriba
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(
                    height: 20,
                  ), // 🔹 controla cuánto sube visualmente
                  Text(
                    data.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFD9D9D9),
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    data.subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFD9D9D9),
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagonalClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    // 🔹 Empieza arriba a la izquierda
    path.lineTo(0, size.height);
    // 🔹 Línea diagonal: baja más del lado derecho
    path.lineTo(size.width, size.height - 100);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

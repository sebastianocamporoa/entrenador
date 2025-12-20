import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

// --- SERVICIOS ---
import 'common/services/user_service.dart';

// --- PANTALLAS ---
import 'features/client_home/main_layout_screen.dart';
import 'features/coach_home/coach_home_screen.dart';
import 'features/coach_home/trainer_main_layout.dart'; // <--- IMPORT NUEVO
import 'features/clients/clients_page.dart';
import 'features/admin/admin_home_screen.dart';

Future<void> main() async {
  // 1. Aseguramos binding y preservamos el Splash Nativo
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

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

  // 2. Quitamos el Splash nativo cuando todo esté listo
  FlutterNativeSplash.remove();

  runApp(const EntrenadorApp());
}

class EntrenadorApp extends StatelessWidget {
  const EntrenadorApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFBF5AF2);
    const backgroundColor = Color(0xFF1C1C1E);
    const surfaceColor = Color(0xFF2C2C2E);
    const errorColor = Colors.redAccent;

    return MaterialApp(
      title: 'Entrenador',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: backgroundColor,
        primaryColor: primaryColor,
        colorScheme: const ColorScheme.dark(
          primary: primaryColor,
          secondary: primaryColor,
          surface: surfaceColor,
          background: backgroundColor,
          error: errorColor,
          onSurface: Color(0xFFD9D9D9),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: backgroundColor,
          elevation: 0,
          centerTitle: false,
          scrolledUnderElevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          titleTextStyle: TextStyle(
            color: Color(0xFFD9D9D9),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          labelStyle: TextStyle(color: Colors.white70),
          hintStyle: TextStyle(color: Colors.white38),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.white24),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: primaryColor),
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Color(0xFF111111),
          modalBackgroundColor: Color(0xFF111111),
        ),
        dialogTheme: const DialogThemeData(backgroundColor: Color(0xFF111111)),
      ),
      // 3. Usamos el Wrapper para decidir la primera pantalla
      home: const RootWrapper(),
    );
  }
}

// --- Wrapper que decide si mostramos Login o App ---
class RootWrapper extends StatelessWidget {
  const RootWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;

    // Si no hay sesión, mostramos Onboarding (o Login)
    if (session == null) {
      return const OnboardingPage();
    }

    // Si hay sesión, vamos al Gate que decide el rol
    return const AuthGate();
  }
}

// --- Gate que decide qué pantalla mostrar según el ROL ---
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
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<String?> _initializeAndGetRole() async {
    await _ensureProfileClient();
    return await _userSrv.getRole();
  }

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return const LoginPage();

    return FutureBuilder<String?>(
      future: _initializeAndGetRole(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snap.hasError || !snap.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('Resolviendo rol')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Theme.of(context).colorScheme.error,
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

        final role = snap.data;

        // --- LÓGICA DE RUTEO POR ROL ---

        if (role == 'admin') return const AdminHomeScreen();

        // ¡CAMBIO AQUÍ!
        // Si es entrenador, usamos el nuevo Layout con barra inferior
        if (role == 'coach') return const TrainerMainLayout();

        // Si es cliente, cargamos la estructura normal de cliente
        return const MainLayoutScreen();
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
          .select('auth_user_id, role')
          .eq('auth_user_id', user.id)
          .maybeSingle();

      if (exists == null) {
        await supa.from('app_user').insert({
          'auth_user_id': user.id,
          'role': 'coach', // Default temporal si te registras por primera vez
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
        final response = await auth.signInWithPassword(
          email: emailCtrl.text.trim(),
          password: passCtrl.text,
        );

        if (response.session == null) {
          throw AuthException('No se pudo iniciar sesión.');
        }

        if (!mounted) return;
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => const AuthGate()));
      } else {
        final resp = await auth.signUp(
          email: emailCtrl.text.trim(),
          password: passCtrl.text,
          data: {
            'full_name': emailCtrl.text.trim().split('@').first,
            'role': 'coach',
          },
        );

        if (resp.session == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Te enviamos un correo de verificación. Abre el enlace para activar tu cuenta.',
              ),
            ),
          );
          return;
        }

        if (!mounted) return;
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => const AuthGate()));
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
    final theme = Theme.of(context);
    final formBackground = const Color(0xFF111111);

    final title = isLogin ? 'Bienvenido de nuevo,' : 'Crea tu cuenta';
    final subtitle = isLogin ? 'Entrena con nosotros' : 'Comienza tu viaje';
    final action = isLogin ? 'Entrar' : 'Registrarme';

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
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
                      if (errorMsg != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            errorMsg!,
                            style: TextStyle(
                              color: theme.colorScheme.error,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      TextField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Correo electrónico',
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: passCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Contraseña',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {},
                          child: Text(
                            '¿Olvidaste tu contraseña?',
                            style: TextStyle(
                              color: theme.primaryColor,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: loading ? null : _submit,
                          child: Text(
                            loading ? 'Procesando...' : action,
                            style: const TextStyle(
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
                          style: TextStyle(color: theme.colorScheme.onSurface),
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
    final theme = Theme.of(context);
    final accent = theme.primaryColor;

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
            bottom: 70,
            child: Row(
              children: List.generate(
                _pages.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _page ? 52 : 25,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 36,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
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
    final background = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).colorScheme.onSurface;

    return Container(
      color: background,
      child: Column(
        children: [
          ClipPath(
            clipper: _DiagonalClipper(),
            child: Stack(
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  width: double.infinity,
                  child: Image.asset(data.image, fit: BoxFit.cover),
                ),
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
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  Text(
                    data.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    data.subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textColor,
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
    path.lineTo(0, size.height);
    path.lineTo(size.width, size.height - 100);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

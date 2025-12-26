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
import 'features/coach_home/trainer_main_layout.dart';
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

    if (session == null) {
      return const OnboardingPage();
    }

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

        if (role == 'admin') return const AdminHomeScreen();
        if (role == 'coach') return const TrainerMainLayout();
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
          'role': 'coach',
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

    final title = isLogin ? 'Nadie va a entrenar por ti.' : 'Crea tu cuenta';
    final subtitle = isLogin
        ? 'Entra, cumple y evoluciona.'
        : 'Comienza tu viaje';
    final action = isLogin ? 'Entrar' : 'Registrarme';

    // 1. Detectar si el teclado está abierto
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            Stack(
              children: [
                ClipPath(
                  clipper: _DiagonalClipper(),
                  // 2. Usar AnimatedContainer para suavizar el cambio de altura
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    // Si el teclado está abierto, reducimos la altura al 25%, si no, 52%
                    height: isKeyboardOpen
                        ? size.height * 0.25
                        : size.height * 0.52,
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
                // 3. Ocultar el texto grande cuando el teclado está abierto
                // para que no estorbe visualmente en el espacio reducido
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  left: 24,
                  // Movemos el texto un poco más abajo si el teclado está abierto, o lo ocultamos
                  bottom: isKeyboardOpen ? 20 : 100,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: isKeyboardOpen
                        ? 0.0
                        : 1.0, // Desaparece al escribir
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
      title: 'Cada entrenamiento que completas aquí es una victoria real.',
      subtitle: 'Avanza hoy, tu progreso ya empezó.',
    ),
    _OnboardData(
      image: 'assets/onboard2.jpg',
      title: 'Entrenar no es castigo, es autocuidado.',
      subtitle:
          'Estás construyendo una versión de ti que se siente mejor cada día.',
    ),
    _OnboardData(
      image: 'assets/onboard3.jpg',
      title: 'No entrenas solo.',
      subtitle:
          'Aquí hay un plan, un seguimiento y un sistema diseñado para apoyarte.',
      showButton: true,
    ),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Esto precarga todas las imágenes en la memoria caché del dispositivo
    // para que al deslizar ya estén listas y no haya retraso.
    for (final page in _pages) {
      precacheImage(AssetImage(page.image), context);
    }
  }

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
            // AQUÍ PASAMOS LA FUNCIÓN _next
            itemBuilder: (_, i) =>
                _OnboardSlide(data: _pages[i], onNext: _next),
          ),
          // Indicadores (Puntos)
          Positioned(
            bottom: 40, // Los bajé un poco más (antes 70)
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
          // ¡YA NO EXISTE EL POSITIONED DEL BOTÓN AQUÍ!
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
  final VoidCallback? onNext;

  const _OnboardSlide({required this.data, this.onNext});

  @override
  Widget build(BuildContext context) {
    final background = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final size = MediaQuery.of(context).size;

    return Container(
      color: background,
      child: Column(
        children: [
          ClipPath(
            clipper: _DiagonalClipper(),
            child: Stack(
              children: [
                SizedBox(
                  // 2. REDUCIMOS AL 50% (antes 0.6) para dar espacio al texto
                  height: size.height * 0.6,
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
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      data.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 29,
                        // CAMBIO 1: Título en Negrita fuerte
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      data.subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 19,
                        // CAMBIO 2: Subtítulo un poco más grueso (SemiBold)
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),

                    if (data.showButton) ...[
                      const SizedBox(height: 40),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 36,
                            vertical: 14,
                          ),
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50),
                          ),
                        ),
                        onPressed: onNext,
                        child: const Text(
                          'Comienza ahora!',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 50),
                    ],
                  ],
                ),
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

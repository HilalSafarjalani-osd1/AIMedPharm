import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'firebase_options.dart';
import 'data/datasources/medicine_remote_data_source.dart';
import 'data/repositories/medicine_repository_impl.dart';
import 'domain/usecases/analyze_image_usecase.dart';
import 'presentation/providers/medicine_provider.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/login_screen.dart';

Future<void> main() async {
  // 1. Hold the Native Splash (Teal Screen)
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // 2. Load heavy data in parallel (Fastest way)
  final results = await Future.wait([
    Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
    availableCameras(),
    SharedPreferences.getInstance(),
  ]);

  final cameras = results[1] as List<CameraDescription>;
  final prefs = results[2] as SharedPreferences;

  // 3. Setup Architecture
  final dataSource = MedicineRemoteDataSource();
  final repository = MedicineRepositoryImpl(dataSource);
  final useCase = AnalyzeImageUseCase(repository);

  // 4. Determine Target Screen
  final bool isGuest = prefs.getBool('is_guest_mode') ?? false;
  final user = FirebaseAuth.instance.currentUser;

  Widget targetScreen;
  if (user != null || isGuest) {
    targetScreen = HomeScreen(cameras: cameras);
  } else {
    targetScreen = LoginScreen(cameras: cameras);
  }

  // 5. The Magic Moment!
  // Remove Native Splash -> App shows BeautifulSplash immediately
  FlutterNativeSplash.remove();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => MedicineProvider(
            analyzeImageUseCase: useCase,
            repository: repository,
          ),
        ),
      ],
      child: MyApp(nextScreen: targetScreen),
    ),
  );
}

class MyApp extends StatelessWidget {
  final Widget nextScreen;

  const MyApp({super.key, required this.nextScreen});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MedicineProvider>();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pharmacy AI',
      locale: provider.locale,
      // 👇👇 UPDATED SUPPORTED LOCALES (4 Languages) 👇👇
      supportedLocales: const [
        Locale('en', 'US'), // English
        Locale('ar', 'AE'), // Arabic
        Locale('fr', 'FR'), // French
        Locale('tr', 'TR'), // Turkish
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        primarySwatch: Colors.teal,
        useMaterial3: true,
        fontFamily: 'Arial',
        scaffoldBackgroundColor: Colors.grey[50],
      ),
      // Start with the Animated Splash
      home: BeautifulSplashScreen(nextScreen: nextScreen),
    );
  }
}

// =============================================================================
// ✨ BEAUTIFUL ANIMATED SPLASH (Seamless Transition)
// =============================================================================
class BeautifulSplashScreen extends StatefulWidget {
  final Widget nextScreen;
  const BeautifulSplashScreen({super.key, required this.nextScreen});

  @override
  State<BeautifulSplashScreen> createState() => _BeautifulSplashScreenState();
}

class _BeautifulSplashScreenState extends State<BeautifulSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Short duration for a snappy feel (1.2 seconds)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Pulse effect (Scale up)
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutBack),
    );

    // Fade in text
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();

    // Navigate after animation
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => widget.nextScreen,
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 🎨 MAGIC: Background color MUST match Native Splash color
    return Scaffold(
      backgroundColor: Colors.teal,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated Logo
            ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.medication_liquid_rounded,
                    size: 80, color: Colors.teal),
              ),
            ),

            const SizedBox(height: 30),

            // Fading Text
            FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  const Text(
                    "Pharmacy AI",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "مساعدك الصيدلي الذكي",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

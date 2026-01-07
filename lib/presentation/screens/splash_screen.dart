import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
// 🔥 استيراد مكتبة التحقق والمصادقة
import 'package:firebase_auth/firebase_auth.dart';

import 'home_screen.dart';
import 'login_screen.dart'; // 👈 استيراد شاشة الدخول

class SplashScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const SplashScreen({super.key, required this.cameras});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    // 1. إعداد أنيميشن الظهور (Fade In)
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );

    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();

    // 2. المؤقت الذكي للانتقال
    // ننتظر 3 ثواني لإعطاء وقت للأنيميشن ولتحميل حالة المستخدم
    Timer(const Duration(seconds: 3), () {
      _checkAuthAndNavigate();
    });
  }

  // 🔥 دالة الفحص الذكي: تقرر إلى أين يذهب المستخدم
  void _checkAuthAndNavigate() {
    // نفحص هل يوجد مستخدم حالي في فايربيس؟
    final user = FirebaseAuth.instance.currentUser;

    // نحدد الشاشة القادمة
    Widget nextScreen;
    if (user != null) {
      // ✅ المستخدم مسجل دخول -> نذهب للصفحة الرئيسية
      nextScreen = HomeScreen(cameras: widget.cameras);
    } else {
      // ❌ المستخدم غير مسجل -> نذهب لصفحة تسجيل الدخول
      nextScreen = LoginScreen(cameras: widget.cameras);
    }

    // تنفيذ الانتقال (إذا كانت الشاشة لا تزال معروضة)
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => nextScreen,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // خلفية متدرجة جميلة
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF16A085), // لون التركواز الغامق
              Color(0xFF82E0AA), // لون فاتح متناسق
            ],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _animation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // اللوجو
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.health_and_safety_outlined,
                    size: 80,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),

                // اسم التطبيق
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
                const Text(
                  "مساعدك الدوائي الذكي",
                  style: TextStyle(fontSize: 16, color: Colors.white70),
                ),
                const SizedBox(height: 50),

                // مؤشر تحميل صغير
                const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

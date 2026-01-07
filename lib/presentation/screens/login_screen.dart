import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';

import 'home_screen.dart';
import '../../core/utils/account_manager.dart';
import '../providers/medicine_provider.dart';

class LoginScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final String? initialEmail;

  const LoginScreen({
    super.key,
    required this.cameras,
    this.initialEmail,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialEmail != null) {
      _emailController.text = widget.initialEmail!;
    }
  }

  // 🌍 Helper for Internal Translations (To support 4 languages easily)
  String getText(String key, String langCode) {
    final Map<String, Map<String, String>> localizedValues = {
      'enter_name': {
        'en': 'Please enter full name',
        'ar': 'يرجى إدخال الاسم الكامل',
        'fr': 'Veuillez entrer le nom complet',
        'tr': 'Lütfen tam adınızı girin'
      },
      'error': {
        'en': 'An error occurred',
        'ar': 'حدث خطأ',
        'fr': 'Une erreur est survenue',
        'tr': 'Bir hata oluştu'
      },
      'welcome': {
        'en': 'Welcome Back',
        'ar': 'مرحباً بعودتك',
        'fr': 'Bon retour',
        'tr': 'Tekrar Hoşgeldiniz'
      },
      'create_acc': {
        'en': 'Create Account',
        'ar': 'إنشاء حساب جديد',
        'fr': 'Créer un compte',
        'tr': 'Hesap Oluştur'
      },
      'first_name': {
        'en': 'First Name',
        'ar': 'الاسم الأول',
        'fr': 'Prénom',
        'tr': 'Ad'
      },
      'last_name': {
        'en': 'Last Name',
        'ar': 'اسم العائلة',
        'fr': 'Nom',
        'tr': 'Soyad'
      },
      'email': {
        'en': 'Email',
        'ar': 'البريد الإلكتروني',
        'fr': 'E-mail',
        'tr': 'E-posta'
      },
      'password': {
        'en': 'Password',
        'ar': 'كلمة المرور',
        'fr': 'Mot de passe',
        'tr': 'Şifre'
      },
      'login': {
        'en': 'Login',
        'ar': 'تسجيل الدخول',
        'fr': 'Connexion',
        'tr': 'Giriş Yap'
      },
      'register': {
        'en': 'Register',
        'ar': 'تسجيل جديد',
        'fr': "S'inscrire",
        'tr': 'Kayıt Ol'
      },
      'no_account': {
        'en': "Don't have an account? Sign Up",
        'ar': "ليس لديك حساب؟ سجل الآن",
        'fr': "Pas de compte ? S'inscrire",
        'tr': "Hesabınız yok mu? Kayıt Olun"
      },
      'have_account': {
        'en': "Already have an account? Login",
        'ar': "لديك حساب؟ سجل دخول",
        'fr': "Déjà un compte ? Connexion",
        'tr': "Zaten hesabınız var mı? Giriş"
      },
      'skip': {
        'en': "Skip as Guest",
        'ar': "تخطي والمتابعة كزائر",
        'fr': "Continuer en tant qu'invité",
        'tr': "Misafir olarak devam et"
      },
    };
    return localizedValues[key]?[langCode] ?? localizedValues[key]?['en'] ?? '';
  }

  // 🌍 Language Selector Modal
  void _showLanguageSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Select Language / اختر اللغة",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              _buildLangOption(context, 'English', 'en', '🇺🇸'),
              _buildLangOption(context, 'العربية', 'ar', '🇦🇪'),
              _buildLangOption(context, 'Français', 'fr', '🇫🇷'),
              _buildLangOption(context, 'Türkçe', 'tr', '🇹🇷'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLangOption(
      BuildContext context, String name, String code, String flag) {
    return ListTile(
      leading: Text(flag, style: const TextStyle(fontSize: 24)),
      title: Text(name),
      onTap: () {
        context.read<MedicineProvider>().changeLanguage(code);
        Navigator.pop(context);
      },
    );
  }

  Future<void> _submit() async {
    final lang = context.read<MedicineProvider>().locale.languageCode;

    // 🛡️ Basic Validation
    if (!_isLogin &&
        (_firstNameController.text.trim().isEmpty ||
            _lastNameController.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(getText('enter_name', lang)),
          backgroundColor: Colors.red));
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (_isLogin) {
        // 🚀 Login
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        // 🆕 Register
        UserCredential cred =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        // 🔥🔥 1. Save User Info to Firestore
        String fullName =
            "${_firstNameController.text.trim()} ${_lastNameController.text.trim()}";

        if (cred.user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(cred.user!.uid)
              .set({
            'first_name': _firstNameController.text.trim(),
            'last_name': _lastNameController.text.trim(),
            'email': _emailController.text.trim(),
            'created_at': FieldValue.serverTimestamp(),
          });

          // 🔥🔥 2. Update Auth Profile
          await cred.user!.updateDisplayName(fullName);
        }

        // 🔥🔥 3. Save Name Locally
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_full_name', fullName);
      }

      // Save Account for Switcher
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.email != null) {
        await AccountManager.saveUser(user.email!, user.uid);
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HomeScreen(cameras: widget.cameras)),
      );
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(e.message ?? getText('error', lang)),
            backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 Get Current Language
    final provider = context.watch<MedicineProvider>();
    final lang = provider.locale.languageCode;

    // Display label for the button
    String langLabel;
    switch (lang) {
      case 'ar':
        langLabel = 'عربي';
        break;
      case 'fr':
        langLabel = 'FR';
        break;
      case 'tr':
        langLabel = 'TR';
        break;
      default:
        langLabel = 'EN';
    }

    return Scaffold(
      backgroundColor: Colors.teal,
      // 🔥 Add AppBar for the Language Switcher
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: null, // No back button
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: GestureDetector(
              onTap: () {
                _showLanguageSelector(context); // 👈 Opens the 4-language menu
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white60),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.language, color: Colors.white, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      langLabel,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 10,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_person_rounded,
                      size: 80, color: Colors.teal),
                  const SizedBox(height: 20),
                  Text(
                    _isLogin
                        ? getText('welcome', lang)
                        : getText('create_acc', lang),
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),

                  // 🔥 Name Fields (Only if Registering)
                  if (!_isLogin) ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _firstNameController,
                            decoration: InputDecoration(
                              labelText: getText('first_name', lang),
                              prefixIcon: const Icon(Icons.person),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _lastNameController,
                            decoration: InputDecoration(
                              labelText: getText('last_name', lang),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: getText('email', lang),
                      prefixIcon: const Icon(Icons.email),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: getText('password', lang),
                      prefixIcon: const Icon(Icons.lock),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_isLoading)
                    const CircularProgressIndicator()
                  else
                    ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(_isLogin
                          ? getText('login', lang)
                          : getText('register', lang)),
                    ),
                  TextButton(
                    onPressed: () => setState(() => _isLogin = !_isLogin),
                    child: Text(_isLogin
                        ? getText('no_account', lang)
                        : getText('have_account', lang)),
                  ),

                  // Guest Mode Skip Button
                  const SizedBox(height: 10),
                  const Divider(),
                  TextButton.icon(
                    onPressed: () async {
                      // 🔥🔥 Save "Guest Mode" flag so app skips login next time
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('is_guest_mode', true);

                      if (!mounted) return;
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => HomeScreen(cameras: widget.cameras),
                        ),
                      );
                    },
                    icon: const Icon(Icons.arrow_forward_rounded,
                        color: Colors.grey),
                    label: Text(
                      getText('skip', lang),
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

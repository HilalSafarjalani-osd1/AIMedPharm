import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'login_screen.dart';
import '../../core/utils/app_strings.dart';
import '../../domain/entities/medicine.dart';
import '../providers/medicine_provider.dart';
import 'camera_screen.dart';
import 'results_screen.dart';
import '../widgets/hsoub_banner.dart';

class HomeScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const HomeScreen({super.key, required this.cameras});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ImagePicker _picker = ImagePicker();

  String _displayName = "Guest";
  String _displayEmail = "Local Mode";
  bool _isPremium = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MedicineProvider>().loadHistory();
      _loadUserProfile();
    });
  }

  Future<void> _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    final prefs = await SharedPreferences.getInstance();

    String localName = "";
    bool premiumStatus = false;

    if (user != null) {
      localName = prefs.getString('user_full_name') ?? "";
    }

    premiumStatus = prefs.getBool('is_premium') ?? false;
    context.read<MedicineProvider>().setPremiumStatus(premiumStatus);

    setState(() {
      _isPremium = premiumStatus;
      if (user != null) {
        _displayName =
            localName.isNotEmpty ? localName : (user.displayName ?? "User");
        _displayEmail = user.email ?? "";
      } else {
        _displayName = "Guest";
        _displayEmail = "Guest Mode";
      }
    });
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

  void _editNameDialog() {
    final lang = context.read<MedicineProvider>().locale.languageCode;
    String txt(String key) => AppStrings.get(key, lang);

    final TextEditingController nameController =
        TextEditingController(text: _displayName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(txt('edit_name')),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: "Name"),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(txt('cancel'))),
          ElevatedButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString(
                  'user_full_name', nameController.text.trim());
              _loadUserProfile();
              Navigator.pop(context);
            },
            child: Text(txt('save')),
          )
        ],
      ),
    );
  }

  void _showPremiumDialog() {
    final lang = context.read<MedicineProvider>().locale.languageCode;
    final isAr = lang == 'ar';
    String txt(String key) => AppStrings.get(key, lang);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(25),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.workspace_premium_rounded,
                  size: 40, color: Colors.amber),
            ),
            const SizedBox(height: 20),
            Text(
              isAr
                  ? "إزالة الإعلانات وسجل لا محدود"
                  : "Remove Ads & Unlimited History",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              isAr
                  ? "احصل على تجربة خالية من الإعلانات، سجل كامل، ودعم فني."
                  : "Get an ad-free experience, full history, and priority support.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('is_premium', true);
                  setState(() => _isPremium = true);
                  context.read<MedicineProvider>().setPremiumStatus(true);

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(txt('premium_activated'))),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF264653),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 5,
                ),
                child: Text(
                  txt('subscribe') + " (\$4.99/mo)",
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                txt('cancel'),
                style: TextStyle(color: Colors.grey[500]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String txt(String key) {
    final lang = context.read<MedicineProvider>().locale.languageCode;
    return AppStrings.get(key, lang);
  }

  String get _greetingMessage {
    var hour = DateTime.now().hour;
    final lang = context.read<MedicineProvider>().locale.languageCode;
    String name = (_displayName == "Guest" ||
            _displayName == "زائر" ||
            _displayName == "Invité" ||
            _displayName == "Misafir")
        ? ""
        : " $_displayName";

    String key;
    String icon;

    if (hour < 12) {
      key = 'greeting_morning';
      icon = ' ☀️';
    } else if (hour < 17) {
      key = 'greeting_afternoon';
      icon = ' 🌤️';
    } else {
      key = 'greeting_evening';
      icon = ' 🌙';
    }

    return "${AppStrings.get(key, lang)}$name$icon";
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
      );
      if (pickedFile != null && mounted) _analyzeAndNavigate(pickedFile.path);
    } catch (e) {
      debugPrint("Gallery Error: $e");
    }
  }

  Future<void> _analyzeAndNavigate(String path) async {
    final provider = context.read<MedicineProvider>();
    final lang = provider.locale.languageCode;

    if (!_isPremium && provider.recentHistory.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.get('notice_limit', lang)),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppStrings.get('analyzing', lang)),
        backgroundColor: const Color(0xFF2A9D8F),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    await provider.analyzeMedicine(path);

    if (!mounted) return;

    if (provider.state == MedicineState.success && provider.medicine != null) {
      // 🔥🔥 CASE: MULTIPLE DRUGS DETECTED 🔥🔥
      if (provider.medicine!.isMultiple) {
        _showMultiDrugSelectionDialog(provider.medicine!.candidates, path);
      }
      // ✅ CASE: SINGLE DRUG (Normal)
      else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ResultScreen(
                data: provider.medicine!,
                imagePath: path,
                isPremium: _isPremium),
          ),
        );
      }
    } else if (provider.state == MedicineState.error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.message), backgroundColor: Colors.red),
      );
    }
  }

  // ✨ Beautiful Selection Dialog for Multiple Drugs
  void _showMultiDrugSelectionDialog(List<String> drugs, String imagePath) {
    final lang = context.read<MedicineProvider>().locale.languageCode;
    final isAr = lang == 'ar';

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.layers_rounded, color: Colors.teal, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isAr
                        ? "تم اكتشاف ${drugs.length} أدوية"
                        : "${drugs.length} Drugs Detected",
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              isAr
                  ? "يرجى اختيار الدواء الذي تريد فحصه:"
                  : "Please choose which one to analyze:",
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),

            // 💊 The List
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: drugs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context); // Close sheet
                      // 🚀 Re-analyze specifically for this drug
                      _analyzeSpecificDrug(imagePath, drugs[index]);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 15, horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.teal.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              drugs[index],
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal),
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded,
                              size: 16, color: Colors.teal),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            // Cancel Button
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.read<MedicineProvider>().resetState();
                },
                child: Text(isAr ? "إلغاء" : "Cancel",
                    style: const TextStyle(color: Colors.grey)),
              ),
            )
          ],
        ),
      ),
    );
  }

  // 🔄 Helper to analyze specific drug
  Future<void> _analyzeSpecificDrug(String path, String drugName) async {
    final provider = context.read<MedicineProvider>();
    final lang = provider.locale.languageCode;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppStrings.get('analyzing', lang) + " ($drugName)"),
        backgroundColor: const Color(0xFF2A9D8F),
        behavior: SnackBarBehavior.floating,
      ),
    );

    // Call analyze again but pass the specific name
    await provider.analyzeMedicine(path, specificDrugName: drugName);

    if (!mounted) return;

    // Once finished, navigate directly
    if (provider.state == MedicineState.success && provider.medicine != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResultScreen(
              data: provider.medicine!, imagePath: path, isPremium: _isPremium),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MedicineProvider>();
    final isLoading = provider.state == MedicineState.loading;
    final lang = provider.locale.languageCode;
    final recentHistory = provider.recentHistory;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _displayName = AppStrings.get('guest', lang);
    }

    final displayHistory =
        _isPremium ? recentHistory : recentHistory.take(5).toList();

    // 🌍 Determine Language Label
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
      backgroundColor: const Color(0xFFF4F7F6),
      body: isLoading
          ? _buildLoadingState(txt('analyzing'))
          : Stack(
              children: [
                const _BackgroundHeader(),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),

                        // HEADER ROW
                        Directionality(
                          textDirection: lang == 'ar'
                              ? TextDirection.rtl
                              : TextDirection.ltr,
                          child: Row(
                            children: [
                              // 1. Profile Info
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => _showProfileOptions(user),
                                  child: Row(
                                    children: [
                                      const CircleAvatar(
                                        backgroundColor: Colors.white,
                                        radius: 20,
                                        child: Icon(Icons.person,
                                            color: Color(0xFF2A9D8F)),
                                      ),
                                      const SizedBox(width: 10),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _displayName,
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14),
                                          ),
                                          Text(
                                            user == null
                                                ? txt('guest')
                                                : txt('user'),
                                            style: TextStyle(
                                                color: Colors.white
                                                    .withOpacity(0.8),
                                                fontSize: 10),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // 2. PREMIUM ICON
                              GestureDetector(
                                onTap: _showPremiumDialog,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: Colors.amber.withOpacity(0.5)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                          Icons.workspace_premium_rounded,
                                          color: Colors.amber,
                                          size: 20),
                                      const SizedBox(width: 5),
                                      Text(
                                        lang == 'ar'
                                            ? "اشتراك"
                                            : lang == 'fr'
                                                ? "S'abonner"
                                                : lang == 'tr'
                                                    ? "Abone Ol"
                                                    : "Subscribe",
                                        style: const TextStyle(
                                            color: Colors.amber,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(width: 10),

                              // 3. Language Switch
                              GestureDetector(
                                onTap: () {
                                  _showLanguageSelector(context);
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white30),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.language,
                                          color: Colors.white, size: 20),
                                      const SizedBox(width: 5),
                                      Text(
                                        langLabel,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 30),
                        Text(
                          _greetingMessage,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          txt('subtitle').split('\n')[0],
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 40),
                        Row(
                          children: [
                            Expanded(
                              child: _ActionCard(
                                title: txt('camera_btn'),
                                subtitle: txt('camera_sub'),
                                icon: Icons.center_focus_strong_rounded,
                                color: const Color(0xFF264653),
                                iconColor: const Color(0xFF2A9D8F),
                                onTap: () async {
                                  context.read<MedicineProvider>().resetState();

                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          CameraScreen(cameras: widget.cameras),
                                    ),
                                  );

                                  if (result != null && result is String) {
                                    if (!mounted) return;
                                    _analyzeAndNavigate(result);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _ActionCard(
                                title: txt('gallery_btn'),
                                subtitle: txt('gallery_sub'),
                                icon: Icons.image_rounded,
                                color: Colors.white,
                                isLight: true,
                                iconColor: const Color(0xFFE76F51),
                                onTap: () {
                                  context.read<MedicineProvider>().resetState();
                                  _pickImageFromGallery();
                                },
                              ),
                            ),
                          ],
                        ),
                        if (recentHistory.isNotEmpty) ...[
                          const SizedBox(height: 30),

                          // 🧠 Title Row Logic
                          // Always LTR for the row structure itself,
                          // but the text inside might be RTL if Arabic.
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text.rich(
                                TextSpan(
                                  text: "${txt('history')} ",
                                  children: [
                                    if (!_isPremium)
                                      TextSpan(
                                        text: "(${recentHistory.length}/5)",
                                        style: TextStyle(
                                            fontSize: 14,
                                            color: recentHistory.length >= 5
                                                ? Colors.red
                                                : Colors.grey),
                                      )
                                  ],
                                ),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF264653),
                                ),
                              ),
                              Icon(
                                Icons.history_rounded,
                                color: Colors.grey[400],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // 🧭 1️⃣ RECENT MEDICINES — LAYOUT LOGIC
                          // Enforcing visual order based on language:
                          // ARABIC (RTL): [Oldest] ... [Newest] (Newest on Right)
                          // OTHERS (LTR): [Newest] ... [Oldest] (Newest on Left)
                          Expanded(
                            child: Directionality(
                              // ⚠️ FORCE visual direction based on language
                              textDirection: lang == 'ar'
                                  ? TextDirection.rtl
                                  : TextDirection.ltr,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                // Order of items: Newest is index 0
                                itemCount: displayHistory.length +
                                    (_isPremium ? 0 : 1),
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 16),
                                itemBuilder: (context, index) {
                                  if (index == displayHistory.length) {
                                    return _buildLockCard(lang);
                                  }
                                  return _ModernHistoryCard(
                                    medicine: displayHistory[index],
                                    lang: lang,
                                    isPremium: _isPremium,
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 100),
                        ] else
                          Expanded(
                            child: Center(
                              child: Icon(
                                Icons.medication_liquid_sharp,
                                size: 80,
                                color: Colors.grey[300],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // 💰 ADS SECTION
                if (!_isPremium) ...[
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 120,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black12,
                              blurRadius: 10,
                              offset: Offset(0, -5))
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: _showPremiumDialog,
                            child: Text(
                              txt(''),
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 5),
                          const SizedBox(
                            width: double.infinity,
                            height: 60,
                            child: HsoubBanner(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 100,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: GestureDetector(
                        onTap: _showPremiumDialog,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF264653),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.block_flipped,
                                  size: 14, color: Colors.amber),
                              const SizedBox(width: 6),
                              Text(
                                txt('remove_ads'),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildLockCard(String lang) {
    return GestureDetector(
      onTap: _showPremiumDialog,
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(bottom: 10, left: 2, right: 2),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.amber.withOpacity(0.5), width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle),
              child:
                  const Icon(Icons.lock_rounded, color: Colors.amber, size: 30),
            ),
            const SizedBox(height: 10),
            Text(
              AppStrings.get('view_more', lang),
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            Text(
              AppStrings.get('upgrade_pro', lang),
              style: const TextStyle(
                  fontSize: 10,
                  color: Colors.amber,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  void _showProfileOptions(User? user) {
    final lang = context.read<MedicineProvider>().locale.languageCode;
    String txt(String key) => AppStrings.get(key, lang);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(user == null ? txt('guest') : txt('user'),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const Divider(),
              if (user == null)
                ListTile(
                  leading: const Icon(Icons.login, color: Colors.teal),
                  title: Text(txt('sign_in')),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (_) => LoginScreen(cameras: widget.cameras)),
                    );
                  },
                )
              else ...[
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: Text(txt('edit_name')),
                  onTap: () {
                    Navigator.pop(context);
                    _editNameDialog();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: Text(txt('logout')),
                  onTap: () async {
                    Navigator.pop(context);
                    context.read<MedicineProvider>().clearUserData();
                    await FirebaseAuth.instance.signOut();
                    if (!mounted) return;
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LoginScreen(cameras: widget.cameras),
                      ),
                      (route) => false,
                    );
                  },
                ),
              ]
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadingState(String text) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFF2A9D8F)),
          const SizedBox(height: 20),
          Text(text,
              style: const TextStyle(
                  color: Color(0xFF264653), fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// 🎨 COMPONENTS (ActionCard, BouncingCard etc. remain unchanged)
class _BouncingCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _BouncingCard({required this.child, required this.onTap});
  @override
  State<_BouncingCard> createState() => _BouncingCardState();
}

class _BouncingCardState extends State<_BouncingCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        _controller.forward();
        HapticFeedback.lightImpact();
      },
      onTapCancel: () {
        _controller.reverse();
      },
      onTapUp: (_) async {
        await _controller.reverse();
        Future.delayed(const Duration(milliseconds: 80), () {
          widget.onTap();
        });
      },
      child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
    );
  }
}

class _BackgroundHeader extends StatelessWidget {
  const _BackgroundHeader();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 320,
      decoration: const BoxDecoration(
          color: Color(0xFF2A9D8F),
          borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(50),
              bottomRight: Radius.circular(50))),
      child: Stack(children: [
        Positioned(
            top: -50,
            right: -50,
            child: CircleAvatar(
                radius: 100, backgroundColor: Colors.white.withOpacity(0.1))),
        Positioned(
            bottom: 50,
            left: -30,
            child: CircleAvatar(
                radius: 60, backgroundColor: Colors.white.withOpacity(0.1))),
      ]),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;
  final bool isLight;
  const _ActionCard(
      {required this.title,
      required this.subtitle,
      required this.icon,
      required this.color,
      required this.iconColor,
      required this.onTap,
      this.isLight = false});
  @override
  Widget build(BuildContext context) {
    return _BouncingCard(
      onTap: onTap,
      child: Container(
        height: 180,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFF2A9D8F).withOpacity(0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 10))
            ]),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: isLight
                          ? const Color(0xFFF4F7F6)
                          : Colors.white.withOpacity(0.1),
                      shape: BoxShape.circle),
                  child: Icon(icon, color: iconColor, size: 28)),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color:
                            isLight ? const Color(0xFF264653) : Colors.white)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 12,
                        color: isLight ? Colors.grey[600] : Colors.white70))
              ]),
            ]),
      ),
    );
  }
}

class _ModernHistoryCard extends StatefulWidget {
  final Medicine medicine;
  final String lang;
  final bool isPremium;
  const _ModernHistoryCard(
      {required this.medicine, required this.lang, required this.isPremium});
  @override
  State<_ModernHistoryCard> createState() => _ModernHistoryCardState();
}

class _ModernHistoryCardState extends State<_ModernHistoryCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOutBack));
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _slideAnimation = Tween<Offset>(
            begin: Offset.zero, end: const Offset(0, -0.5))
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _requestDelete() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            const Icon(Icons.delete_forever_rounded, color: Colors.red),
            const SizedBox(width: 10),
            Text(AppStrings.get('delete_confirm', widget.lang)),
          ],
        ),
        content: Text(
          AppStrings.get('delete_msg', widget.lang),
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppStrings.get('cancel', widget.lang),
                style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(AppStrings.get('delete', widget.lang),
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isDeleting = true);
      await _controller.forward();
      if (!mounted) return;
      context.read<MedicineProvider>().deleteItem(widget.medicine);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasImage = widget.medicine.imagePath != null &&
        widget.medicine.imagePath!.isNotEmpty &&
        File(widget.medicine.imagePath!).existsSync();
    final Alignment suckDirection =
        widget.lang == 'ar' ? Alignment.topLeft : Alignment.topRight;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          alignment: suckDirection,
          child: Opacity(
              opacity: _fadeAnimation.value,
              child: SlideTransition(position: _slideAnimation, child: child))),
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(bottom: 10, left: 2, right: 2),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.grey.withOpacity(0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 5))
            ],
            image: hasImage
                ? DecorationImage(
                    image: FileImage(File(widget.medicine.imagePath!)),
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(
                        Colors.black.withOpacity(0.4), BlendMode.darken))
                : null),
        child: Material(
            color: Colors.transparent,
            child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => ResultScreen(
                              data: widget.medicine,
                              imagePath: widget.medicine.imagePath ?? "",
                              isPremium: widget.isPremium)));
                },
                child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                CircleAvatar(
                                    radius: 14,
                                    backgroundColor: hasImage
                                        ? Colors.white24
                                        : const Color(0xFFE9F5F3),
                                    child: Icon(Icons.medication_rounded,
                                        size: 16,
                                        color: hasImage
                                            ? Colors.white
                                            : const Color(0xFF2A9D8F))),
                                GestureDetector(
                                    onTap: _requestDelete,
                                    child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 300),
                                        padding:
                                            EdgeInsets.all(_isDeleting ? 8 : 4),
                                        decoration: BoxDecoration(
                                            color: _isDeleting
                                                ? Colors.red.withOpacity(0.2)
                                                : Colors.transparent,
                                            shape: BoxShape.circle),
                                        child: Icon(
                                            _isDeleting
                                                ? Icons.delete_forever_rounded
                                                : Icons.delete_outline_rounded,
                                            size: _isDeleting ? 24 : 20,
                                            color: _isDeleting
                                                ? Colors.red
                                                : (hasImage
                                                    ? Colors.white70
                                                    : Colors.red)))),
                              ]),
                          const Spacer(),
                          Text(widget.medicine.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: hasImage
                                      ? Colors.white
                                      : const Color(0xFF264653),
                                  height: 1.2,
                                  shadows: hasImage
                                      ? [
                                          const BoxShadow(
                                              blurRadius: 4,
                                              color: Colors.black)
                                        ]
                                      : [])),
                          const SizedBox(height: 6),
                          Text(
                              widget.medicine.strength.isNotEmpty
                                  ? widget.medicine.strength
                                  : AppStrings.get('general', widget.lang),
                              style: TextStyle(
                                  fontSize: 12,
                                  color: hasImage
                                      ? Colors.white70
                                      : Colors.grey[400])),
                        ])))),
      ),
    );
  }
}

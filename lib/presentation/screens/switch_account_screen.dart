import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';

import '../../core/utils/account_manager.dart'; // تأكد من المسار
import '../providers/medicine_provider.dart';
import 'login_screen.dart';

class SwitchAccountScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const SwitchAccountScreen({super.key, required this.cameras});

  @override
  State<SwitchAccountScreen> createState() => _SwitchAccountScreenState();
}

class _SwitchAccountScreenState extends State<SwitchAccountScreen> {
  List<SavedAccount> savedAccounts = [];
  final String? currentEmail = FirebaseAuth.instance.currentUser?.email;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final list = await AccountManager.getSavedAccounts();
    setState(() {
      savedAccounts = list;
    });
  }

  Future<void> _handleAccountTap(SavedAccount account) async {
    // 1. إذا كان هو الحساب الحالي، لا نفعل شيئاً
    if (account.email == currentEmail) return;

    // 2. إذا حساب مختلف: نسجل خروج ونذهب لشاشة الدخول (مع تعبئة الإيميل)
    // ملاحظة: لأسباب أمنية، يجب إعادة إدخال كلمة المرور

    // تنظيف بيانات البروفايدر
    context.read<MedicineProvider>().clearUserData();
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => LoginScreen(
          cameras: widget.cameras,
          initialEmail: account.email, // 👈 نمرر الإيميل
        ),
      ),
      (route) => false,
    );
  }

  Future<void> _addNewAccount() async {
    context.read<MedicineProvider>().clearUserData();
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => LoginScreen(cameras: widget.cameras),
      ),
      (route) => false,
    );
  }

  Future<void> _removeAccount(String email) async {
    await AccountManager.removeAccount(email);
    _loadAccounts(); // تحديث القائمة
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("تبديل الحساب"),
        centerTitle: true,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          // القائمة
          Expanded(
            child: ListView.builder(
              itemCount: savedAccounts.length,
              itemBuilder: (context, index) {
                final account = savedAccounts[index];
                final bool isActive = account.email == currentEmail;

                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  elevation: isActive ? 4 : 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                    side: isActive
                        ? const BorderSide(color: Colors.teal, width: 2)
                        : BorderSide.none,
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    onTap: () => _handleAccountTap(account),
                    leading: CircleAvatar(
                      backgroundColor:
                          isActive ? Colors.teal : Colors.grey[300],
                      radius: 25,
                      child: Icon(
                        Icons.person,
                        color: isActive ? Colors.white : Colors.grey[600],
                      ),
                    ),
                    title: Text(
                      account.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: isActive ? Colors.teal : Colors.black87,
                      ),
                    ),
                    subtitle: Text(account.email),
                    trailing: isActive
                        ? const Icon(Icons.check_circle, color: Colors.teal)
                        : IconButton(
                            icon: const Icon(Icons.close, color: Colors.grey),
                            onPressed: () => _removeAccount(account.email),
                          ),
                  ),
                );
              },
            ),
          ),

          // زر إضافة حساب جديد
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: _addNewAccount,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.teal,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                    side: const BorderSide(color: Colors.teal),
                  ),
                ),
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text(
                  "إضافة حساب جديد",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

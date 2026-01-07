import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SavedAccount {
  final String email;
  final String name;
  final String uid;

  SavedAccount({required this.email, required this.name, required this.uid});

  Map<String, dynamic> toMap() => {'email': email, 'name': name, 'uid': uid};

  factory SavedAccount.fromMap(Map<String, dynamic> map) {
    return SavedAccount(
      email: map['email'] ?? '',
      name: map['name'] ?? 'User',
      uid: map['uid'] ?? '',
    );
  }
}

class AccountManager {
  static const String _key = 'saved_accounts';

  // حفظ مستخدم جديد
  static Future<void> saveUser(String email, String uid) async {
    final prefs = await SharedPreferences.getInstance();
    List<SavedAccount> accounts = await getSavedAccounts();

    // التحقق هل المستخدم موجود مسبقاً؟
    final index = accounts.indexWhere((acc) => acc.email == email);

    // اسم افتراضي (يمكنك تحسينه بجلب الاسم من فايربيس)
    final newAccount =
        SavedAccount(email: email, name: email.split('@')[0], uid: uid);

    if (index != -1) {
      accounts[index] = newAccount; // تحديث
    } else {
      accounts.add(newAccount); // إضافة
    }

    // تحويل القائمة لنص وحفظها
    final String encoded = jsonEncode(accounts.map((e) => e.toMap()).toList());
    await prefs.setString(_key, encoded);
  }

  // جلب كل الحسابات
  static Future<List<SavedAccount>> getSavedAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_key);
    if (data == null) return [];

    final List<dynamic> decoded = jsonDecode(data);
    return decoded.map((e) => SavedAccount.fromMap(e)).toList();
  }

  // حذف حساب
  static Future<void> removeAccount(String email) async {
    final prefs = await SharedPreferences.getInstance();
    List<SavedAccount> accounts = await getSavedAccounts();

    accounts.removeWhere((acc) => acc.email == email);

    final String encoded = jsonEncode(accounts.map((e) => e.toMap()).toList());
    await prefs.setString(_key, encoded);
  }
}

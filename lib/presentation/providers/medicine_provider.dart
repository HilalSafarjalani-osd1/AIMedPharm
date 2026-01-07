import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants.dart';
import '../../domain/entities/medicine.dart';
import '../../data/models/medicine_model.dart';
import '../../domain/repositories/medicine_repository.dart';
import '../../domain/usecases/analyze_image_usecase.dart';

enum MedicineState { initial, loading, success, error }

class MedicineProvider extends ChangeNotifier {
  final AnalyzeImageUseCase analyzeImageUseCase;
  final MedicineRepository repository;

  MedicineProvider({
    required this.analyzeImageUseCase,
    required this.repository,
  });

  MedicineState _state = MedicineState.initial;
  Medicine? _medicine;
  String _message = '';
  Locale _locale = const Locale('en', 'US');

  List<Medicine> _recentHistory = [];
  bool _isPremium = false;

  MedicineState get state => _state;
  Medicine? get medicine => _medicine;
  String get message => _message;
  Locale get locale => _locale;
  List<Medicine> get recentHistory => _recentHistory;
  bool get isPremium => _isPremium;

  void setPremiumStatus(bool status) {
    _isPremium = status;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // 💾 STRICT ARCHITECTURE: HISTORY MANAGEMENT
  // ---------------------------------------------------------------------------

  Future<void> loadHistory() async {
    _recentHistory = [];
    notifyListeners();

    final user = FirebaseAuth.instance.currentUser;

    try {
      if (user != null) {
        // 🔐 AUTHENTICATED USER FLOW
        final String userKey = 'history_${user.uid}';
        print(
            "🔐 Authenticated Mode: Checking Local Storage for ${user.uid}...");

        // ✅ Rule #3: Local Storage is Source of Truth
        List<Medicine> localData = await _loadListFromLocalKey(userKey);

        if (localData.isNotEmpty) {
          _recentHistory = localData;
        } else {
          // ✅ Rule #5: New Device Sync (One-Time)
          print("⚠️ No Local Data. Attempting One-Time Firebase Sync...");
          List<Medicine> remoteData =
              await repository.getRemoteHistory(user.uid);

          if (remoteData.isNotEmpty) {
            _recentHistory = remoteData;
            await _saveListToLocalKey(remoteData, userKey);
          }
        }
      } else {
        // 👽 GUEST FLOW
        print("👽 Guest Mode: Loading Guest Storage...");
        _recentHistory = await _loadListFromLocalKey('history_guest');
      }
    } catch (e) {
      print("❌ Critical Error loading history: $e");
    }

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // 📸 ANALYZE LOGIC (With Isolated Storage)
  // ---------------------------------------------------------------------------

  Future<void> analyzeMedicine(String imagePath,
      {String? specificDrugName}) async {
    _state = MedicineState.loading;
    _message = 'Analyzing...';
    notifyListeners();

    try {
      if (Constants.apiKey.isEmpty) await fetchApiKeys();
      if (Constants.apiKey.isEmpty) throw Exception("Failed to fetch API Key.");

      // 1. Analyze Image
      final result = await analyzeImageUseCase(
        imagePath,
        _locale.languageCode,
        targetDrug: specificDrugName,
      );

      // 2. 🔐 Rule #1: ISOLATED LOCAL STORAGE
      String finalImagePath = imagePath;

      if (result.isFound &&
          !result.isMultiple &&
          !imagePath.contains('app_flutter')) {
        final user = FirebaseAuth.instance.currentUser;
        final Directory appDocDir = await getApplicationDocumentsDirectory();
        final String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';

        // 📁 Define Isolated Directory
        final Directory isolatedDir;
        if (user != null) {
          isolatedDir = Directory('${appDocDir.path}/users/${user.uid}');
        } else {
          isolatedDir = Directory('${appDocDir.path}/guest');
        }

        if (!await isolatedDir.exists()) {
          await isolatedDir.create(recursive: true);
        }

        final String permanentPath = '${isolatedDir.path}/$fileName';
        await File(imagePath).copy(permanentPath);
        finalImagePath = permanentPath;
      }

      // 3. Update Medicine Object
      final resultWithImage = result.copyWith(
        imagePath: finalImagePath,
        date: DateTime.now().toIso8601String(),
      );

      _medicine = resultWithImage;
      _state = MedicineState.success;

      if (resultWithImage.isMultiple) {
        notifyListeners();
        return;
      }

      // 4. Save to History
      if (resultWithImage.isFound) {
        if (!_isPremium && _recentHistory.length >= 5) {
          print("🚫 History Limit Reached.");
        } else {
          _recentHistory
              .removeWhere((item) => item.name == resultWithImage.name);
          _recentHistory.insert(0, resultWithImage);

          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            await _saveListToLocalKey(_recentHistory, 'history_${user.uid}');
            await repository.addMedicine(resultWithImage, user.uid);
          } else {
            await _saveListToLocalKey(_recentHistory, 'history_guest');
          }
        }
      }
    } catch (e) {
      _state = MedicineState.error;
      _message = e.toString();
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // 🗑️ STRICT DELETION LOGIC (Guest vs User)
  // ---------------------------------------------------------------------------
  Future<void> deleteItem(Medicine item) async {
    // 1. Remove from RAM immediately (UI Update)
    _recentHistory.remove(item);
    notifyListeners();

    final user = FirebaseAuth.instance.currentUser;

    try {
      // 🗑️ PHYSICAL FILE DELETION (Common Step)
      if (item.imagePath != null) {
        final file = File(item.imagePath!);
        if (await file.exists()) {
          await file.delete();
          print("🗑️ File Deleted: ${item.imagePath}");
        }
      }

      if (user != null) {
        // 🔐 USER MODE: Full Synced Deletion
        print("🗑️ Deleting for User ${user.uid}...");

        // A. Delete from Local Storage (Disk)
        await _saveListToLocalKey(_recentHistory, 'history_${user.uid}');

        // B. Delete from Firebase (Cloud)
        // Note: Repository handles the Firestore call
        await repository.deleteMedicine(item, user.uid);
      } else {
        // 👽 GUEST MODE: Permanent Local Deletion
        print("🗑️ Deleting Guest Data...");

        // A. Delete from Local Storage (Disk)
        await _saveListToLocalKey(_recentHistory, 'history_guest');

        // No Firebase interaction allowed for guests
      }
    } catch (e) {
      print("❌ Critical Deletion Error: $e");
      // Ideally, re-add item to RAM if delete failed, but for now we assume UI optimism
    }
  }

  // ---------------------------------------------------------------------------
  // 📥 INTERNAL HELPERS
  // ---------------------------------------------------------------------------

  Future<void> _saveListToLocalKey(List<Medicine> list, String key) async {
    final prefs = await SharedPreferences.getInstance();
    final String jsonString = jsonEncode(list.map((e) {
      if (e is MedicineModel) return e.toJson();
      return (e as dynamic).toJson();
    }).toList());
    await prefs.setString(key, jsonString);
  }

  Future<List<Medicine>> _loadListFromLocalKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(key);

    if (jsonString != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        return jsonList.map((e) => MedicineModel.fromJson(e)).toList();
      } catch (e) {
        print("❌ JSON Load Error: $e");
        return [];
      }
    }
    return [];
  }

  // ---------------------------------------------------------------------------
  // ⚙️ APP HELPERS
  // ---------------------------------------------------------------------------

  Future<void> fetchApiKeys() async {
    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('openai_config')
          .doc('openai_config')
          .get();

      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data()!;
        Constants.apiKey = (data['api_key'] ?? "").trim();
        Constants.baseUrl = (data['base_url'] ?? "").trim();
        Constants.modelName =
            (data['model_name'] ?? "gemini-2.5-flash-lite").trim();
      }
    } catch (e) {
      print("❌ Failed to fetch config: $e");
    }
  }

  void changeLanguage(String code) {
    switch (code) {
      case 'ar':
        _locale = const Locale('ar', 'AE');
        break;
      case 'fr':
        _locale = const Locale('fr', 'FR');
        break;
      case 'tr':
        _locale = const Locale('tr', 'TR');
        break;
      case 'en':
      default:
        _locale = const Locale('en', 'US');
        break;
    }
    notifyListeners();
  }

  void resetState() {
    _state = MedicineState.initial;
    _medicine = null;
    _message = '';
    notifyListeners();
  }

  void clearUserData() {
    _recentHistory.clear();
    _medicine = null;
    _state = MedicineState.initial;
    notifyListeners();
  }

  Future<void> clearHistory() async {
    // 1. Delete all physical files for current context
    for (var item in _recentHistory) {
      if (item.imagePath != null) {
        final file = File(item.imagePath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
    }

    _recentHistory.clear();
    notifyListeners();

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _saveListToLocalKey([], 'history_${user.uid}');
      // Optional: Add logic to clear Firestore collection if needed
    } else {
      await _saveListToLocalKey([], 'history_guest');
    }
  }
}

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/error/exceptions.dart';
import '../../domain/entities/medicine.dart';
import '../../domain/repositories/medicine_repository.dart';
import '../datasources/medicine_remote_data_source.dart';
import '../models/medicine_model.dart';

class MedicineRepositoryImpl implements MedicineRepository {
  final MedicineRemoteDataSource remoteDataSource;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  MedicineRepositoryImpl(this.remoteDataSource);

  @override
  Future<Medicine> analyzeImage(String imagePath, String langCode,
      {String? targetDrug}) async {
    try {
      return await remoteDataSource.analyze(imagePath, langCode,
          targetDrug: targetDrug);
    } on ServerException catch (e) {
      return MedicineModel.notFound(
        langCode == 'ar'
            ? "خطأ في الخادم: ${e.message}"
            : "Server Error: ${e.message}",
      );
    } on OcrException catch (e) {
      return MedicineModel.notFound(
        langCode == 'ar'
            ? "فشل قراءة النص: ${e.message}"
            : "Text Read Failed: ${e.message}",
      );
    } on AiAnalysisException catch (e) {
      return MedicineModel.notFound(
        langCode == 'ar'
            ? "خطأ في التحليل الذكي: ${e.message}"
            : "AI Analysis Error: ${e.message}",
      );
    } catch (e) {
      return MedicineModel.notFound(
        langCode == 'ar' ? "حدث خطأ غير متوقع: $e" : "Unexpected Error: $e",
      );
    }
  }

  // ===========================================================================
  // 💾 LOCAL STORAGE METHODS (Legacy/Helpers)
  // ===========================================================================

  @override
  Future<List<Medicine>> getLocalHistory() async {
    // Note: Provider now handles segregation, this is a fallback
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString('cached_medicines_history');
      if (jsonString != null) {
        final List<dynamic> jsonList = json.decode(jsonString);
        return jsonList.map((e) => MedicineModel.fromJson(e)).toList();
      }
    } catch (e) {
      print("Local Storage Error: $e");
    }
    return [];
  }

  @override
  Future<void> saveListToLocal(List<Medicine> medicines) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String jsonString = json.encode(
        medicines.map((e) => (e as MedicineModel).toJson()).toList(),
      );
      await prefs.setString('cached_medicines_history', jsonString);
    } catch (e) {
      print("Error saving to local: $e");
    }
  }

  // ===========================================================================
  // ☁️ FIRESTORE METHODS
  // ===========================================================================

  @override
  Future<List<Medicine>> getRemoteHistory(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('medicines')
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        // Inject ID so we can delete it later
        data['id'] = doc.id;
        return MedicineModel.fromJson(data);
      }).toList();
    } catch (e) {
      print("Firestore Fetch Error: $e");
      return [];
    }
  }

  // ✅ FIX: Returns the new ID
  @override
  Future<String?> addMedicine(Medicine medicine, String? userId) async {
    if (userId == null) return null;

    try {
      final docRef = await _firestore
          .collection('users')
          .doc(userId)
          .collection('medicines')
          .add((medicine as MedicineModel).toJson());

      print("✅ Added to Firestore with ID: ${docRef.id}");
      return docRef.id; // Return the generated ID
    } catch (e) {
      print("❌ Error adding to Firestore: $e");
      return null;
    }
    // Note: We REMOVED local saving here. Provider handles it now.
  }

  @override
  Future<void> deleteMedicine(Medicine medicine, String? userId) async {
    if (userId != null && medicine.id != null) {
      try {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('medicines')
            .doc(medicine.id) // This requires ID to be present!
            .delete();
        print("🔥 Deleted from Firestore: ${medicine.id}");
      } catch (e) {
        print("❌ Error deleting from Firestore: $e");
      }
    } else {
      print("⚠️ Cannot delete from Firestore: UserID or MedicineID is null");
    }
  }
}

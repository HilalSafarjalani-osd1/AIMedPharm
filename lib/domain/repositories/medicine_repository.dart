import '../entities/medicine.dart';

abstract class MedicineRepository {
  // 📸 Updated: Accepts [targetDrug] for specific analysis
  Future<Medicine> analyzeImage(String imagePath, String langCode,
      {String? targetDrug});

  // ===========================================================================
  // 💾 Storage Functions
  // ===========================================================================

  Future<List<Medicine>> getLocalHistory();

  Future<void> saveListToLocal(List<Medicine> medicines);

  Future<List<Medicine>> getRemoteHistory(String userId);

  // ✅ FIX: Return String? (The ID) instead of void
  Future<String?> addMedicine(Medicine medicine, String? userId);

  Future<void> deleteMedicine(Medicine medicine, String? userId);
}

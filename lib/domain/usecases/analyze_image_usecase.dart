import '../entities/medicine.dart';
import '../repositories/medicine_repository.dart';

class AnalyzeImageUseCase {
  final MedicineRepository repository;

  AnalyzeImageUseCase(this.repository);

  // ✅ Update: Added [targetDrug] optional parameter
  Future<Medicine> call(String imagePath, String langCode,
      {String? targetDrug}) async {
    return await repository.analyzeImage(imagePath, langCode,
        targetDrug: targetDrug);
  }
}

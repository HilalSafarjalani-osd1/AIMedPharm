import '../../domain/entities/medicine.dart';

class MedicineModel extends Medicine {
  const MedicineModel({
    super.id,
    required super.date,
    required super.name,
    super.strength,
    required super.ingredients,
    required super.dosageDuration,
    required super.primaryUses,
    required super.commonSideEffects,
    required super.seriousSymptoms,
    required super.contraindications,
    required super.interactions,
    required super.storageDisposal,
    required super.missedDose,
    required super.overdoseResponse,
    super.isFound,
    super.imagePath,
    super.isMultiple = false,
    super.candidates = const [],
  });

  factory MedicineModel.fromJson(Map<String, dynamic> json) {
    // 1. 🔥 CHECK FOR MULTIPLE DRUGS 🔥
    if (json.containsKey('multiple_detected') &&
        json['multiple_detected'] == true) {
      return MedicineModel(
        id: json['id'],
        date: json['date'] ?? DateTime.now().toIso8601String(),
        name: "Multiple Drugs Detected",
        isFound: true,
        isMultiple: true,
        candidates: _parseList(json['options']),
        strength: '',
        ingredients: const [],
        dosageDuration: const [],
        primaryUses: const [],
        commonSideEffects: const [],
        seriousSymptoms: const [],
        contraindications: const [],
        interactions: const [],
        storageDisposal: const [],
        missedDose: const [],
        overdoseResponse: const [],
        // ✅ FIX: Check both key formats for image
        imagePath: json['image_path'] ?? json['imagePath'],
      );
    }

    // 2. Standard Single Drug Logic
    return MedicineModel(
      id: json['id'],
      date: json['date'] ?? DateTime.now().toIso8601String(),

      // ✅ FIX: Check 'brand_name' (AI) AND 'name' (Local Storage)
      name: _parseString(json['brand_name'] ?? json['name']),
      strength: _parseString(json['strength']),

      ingredients: _parseList(json['ingredients']),
      dosageDuration:
          _parseList(json['dosage_duration'] ?? json['dosageDuration']),
      primaryUses: _parseList(json['primary_uses'] ?? json['primaryUses']),
      commonSideEffects:
          _parseList(json['common_side_effects'] ?? json['commonSideEffects']),
      seriousSymptoms:
          _parseList(json['serious_symptoms'] ?? json['seriousSymptoms']),
      contraindications: _parseList(json['contraindications']),
      interactions: _parseList(json['interactions']),
      storageDisposal:
          _parseList(json['storage_disposal'] ?? json['storageDisposal']),
      missedDose: _parseList(json['missed_dose'] ?? json['missedDose']),
      overdoseResponse:
          _parseList(json['overdose_response'] ?? json['overdoseResponse']),

      isFound: json['is_found'] ?? json['isFound'] ?? true,
      // ✅ FIX: Check both formats
      imagePath: json['image_path'] ?? json['imagePath'],

      isMultiple: false,
      candidates: const [],
    );
  }

  // ✅ CRITICAL FIX: Save Keys matching BOTH Medicine and AI formats
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date,

      // 🔑 Save as BOTH to prevent "Unknown" bug
      'brand_name': name,
      'name': name,

      'strength': strength,
      'ingredients': ingredients,

      // 🔑 Save Detailed Fields (Both Formats)
      'dosage_duration': dosageDuration,
      'dosageDuration': dosageDuration,

      'primary_uses': primaryUses,
      'primaryUses': primaryUses,

      'common_side_effects': commonSideEffects,
      'commonSideEffects': commonSideEffects,

      'serious_symptoms': seriousSymptoms,
      'seriousSymptoms': seriousSymptoms,

      'contraindications': contraindications,
      'interactions': interactions,

      'storage_disposal': storageDisposal,
      'storageDisposal': storageDisposal,

      'missed_dose': missedDose,
      'missedDose': missedDose,

      'overdose_response': overdoseResponse,
      'overdoseResponse': overdoseResponse,

      'is_found': isFound,
      'isFound': isFound,

      // 🔑 Save Image Path (Both Formats)
      'image_path': imagePath,
      'imagePath': imagePath,

      'multiple_detected': isMultiple,
      'options': candidates,
    };
  }

  // Same copyWith as before...
  @override
  MedicineModel copyWith({
    String? id,
    String? date,
    String? name,
    String? strength,
    List<String>? ingredients,
    List<String>? dosageDuration,
    List<String>? primaryUses,
    List<String>? commonSideEffects,
    List<String>? seriousSymptoms,
    List<String>? contraindications,
    List<String>? interactions,
    List<String>? storageDisposal,
    List<String>? missedDose,
    List<String>? overdoseResponse,
    bool? isFound,
    String? imagePath,
    bool? isMultiple,
    List<String>? candidates,
  }) {
    return MedicineModel(
      id: id ?? this.id,
      date: date ?? this.date,
      name: name ?? this.name,
      strength: strength ?? this.strength,
      ingredients: ingredients ?? this.ingredients,
      dosageDuration: dosageDuration ?? this.dosageDuration,
      primaryUses: primaryUses ?? this.primaryUses,
      commonSideEffects: commonSideEffects ?? this.commonSideEffects,
      seriousSymptoms: seriousSymptoms ?? this.seriousSymptoms,
      contraindications: contraindications ?? this.contraindications,
      interactions: interactions ?? this.interactions,
      storageDisposal: storageDisposal ?? this.storageDisposal,
      missedDose: missedDose ?? this.missedDose,
      overdoseResponse: overdoseResponse ?? this.overdoseResponse,
      isFound: isFound ?? this.isFound,
      imagePath: imagePath ?? this.imagePath,
      isMultiple: isMultiple ?? this.isMultiple,
      candidates: candidates ?? this.candidates,
    );
  }

  factory MedicineModel.notFound(String message) {
    return MedicineModel(
      date: DateTime.now().toIso8601String(),
      name: message,
      strength: '',
      ingredients: const [],
      dosageDuration: const [],
      primaryUses: const [],
      commonSideEffects: const [],
      seriousSymptoms: const [],
      contraindications: const [],
      interactions: const [],
      storageDisposal: const [],
      missedDose: const [],
      overdoseResponse: const [],
      isFound: false,
    );
  }

  static String _parseString(dynamic input) {
    if (input == null) return '';
    if (input is List) {
      return input.isNotEmpty
          ? input.first.toString().replaceAll(RegExp(r'[\[\]"]'), '')
          : '';
    }
    return input.toString().replaceAll(RegExp(r'[\[\]"]'), '').trim();
  }

  static List<String> _parseList(dynamic input) {
    if (input == null) return [];
    if (input is List) {
      return input
          .map((e) => e.toString().replaceAll(RegExp(r'[\[\]"]'), '').trim())
          .toList();
    }
    String str = input.toString().trim();
    if (str.isEmpty) return [];
    return [str.replaceAll(RegExp(r'[\[\]"]'), '')];
  }
}

import 'package:equatable/equatable.dart';

class Medicine extends Equatable {
  // 🆔 FIELDS FOR STORAGE & SYNC
  final String? id;
  final String date;

  // 🏷️ Basic Info
  final String name;
  final String strength;

  // 1️⃣ Ingredients (UNTOUCHABLE)
  final List<String> ingredients;

  // 2️⃣ Dosage and Duration
  final List<String> dosageDuration;

  // 3️⃣ Primary Uses (Indications)
  final List<String> primaryUses;

  // 4️⃣ Common Side Effects
  final List<String> commonSideEffects;

  // 5️⃣ Serious Symptoms (Seek Medical Help)
  final List<String> seriousSymptoms;

  // 6️⃣ Contraindications
  final List<String> contraindications;

  // 7️⃣ Interactions (Drug, Food & Alcohol)
  final List<String> interactions;

  // 8️⃣ Storage & Disposal
  final List<String> storageDisposal;

  // 9️⃣ Missed Dose Instructions
  final List<String> missedDose;

  // 🔟 Overdose Response
  final List<String> overdoseResponse;

  // 🖼️ Meta Info
  final bool isFound;
  final String? imagePath;
  final bool isMultiple;
  final List<String> candidates;

  const Medicine({
    this.id,
    required this.date,
    required this.name,
    this.strength = '',
    required this.ingredients,
    required this.dosageDuration,
    required this.primaryUses,
    required this.commonSideEffects,
    required this.seriousSymptoms,
    required this.contraindications,
    required this.interactions,
    required this.storageDisposal,
    required this.missedDose,
    required this.overdoseResponse,
    this.isFound = true,
    this.imagePath,
    this.isMultiple = false,
    this.candidates = const [],
  });

  // 📋 FROM JSON
  factory Medicine.fromJson(Map<String, dynamic> json) {
    return Medicine(
      id: json['id'],
      date: json['date'] ?? DateTime.now().toIso8601String(),
      name: json['name'] ?? 'Unknown',
      strength: json['strength'] ?? '',
      ingredients: List<String>.from(json['ingredients'] ?? []),
      dosageDuration: List<String>.from(json['dosageDuration'] ?? []),
      primaryUses: List<String>.from(json['primaryUses'] ?? []),
      commonSideEffects: List<String>.from(json['commonSideEffects'] ?? []),
      seriousSymptoms: List<String>.from(json['seriousSymptoms'] ?? []),
      contraindications: List<String>.from(json['contraindications'] ?? []),
      interactions: List<String>.from(json['interactions'] ?? []),
      storageDisposal: List<String>.from(json['storageDisposal'] ?? []),
      missedDose: List<String>.from(json['missedDose'] ?? []),
      overdoseResponse: List<String>.from(json['overdoseResponse'] ?? []),
      isFound: json['isFound'] ?? true,
      imagePath: json['imagePath'],
      isMultiple: json['isMultiple'] ?? false,
      candidates: List<String>.from(json['candidates'] ?? []),
    );
  }

  // 📋 TO JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date,
      'name': name,
      'strength': strength,
      'ingredients': ingredients,
      'dosageDuration': dosageDuration,
      'primaryUses': primaryUses,
      'commonSideEffects': commonSideEffects,
      'seriousSymptoms': seriousSymptoms,
      'contraindications': contraindications,
      'interactions': interactions,
      'storageDisposal': storageDisposal,
      'missedDose': missedDose,
      'overdoseResponse': overdoseResponse,
      'isFound': isFound,
      'imagePath': imagePath,
      'isMultiple': isMultiple,
      'candidates': candidates,
    };
  }

  Medicine copyWith({
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
    return Medicine(
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

  @override
  List<Object?> get props => [
        id,
        date,
        name,
        strength,
        ingredients,
        dosageDuration,
        primaryUses,
        commonSideEffects,
        seriousSymptoms,
        contraindications,
        interactions,
        storageDisposal,
        missedDose,
        overdoseResponse,
        isFound,
        imagePath,
        isMultiple,
        candidates,
      ];
}

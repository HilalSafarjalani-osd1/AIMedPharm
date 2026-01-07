import 'dart:convert';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;
import 'package:medpharm/core/constants.dart';
import '../../core/error/exceptions.dart';
import '../models/medicine_model.dart';

class MedicineRemoteDataSource {
  // ---------------------------------------------------------------------------
  // 🚀 Main Analysis Function
  // ---------------------------------------------------------------------------
  Future<MedicineModel> analyze(String imagePath, String langCode,
      {String? targetDrug}) async {
    try {
      // -------------------------------------------------------
      // Step 1: Optical Character Recognition (Offline ML Kit)
      // -------------------------------------------------------
      print("📸 1. Starting Offline ML Kit Analysis...");
      String rawText = await _performOfflineOcr(imagePath);

      if (rawText.isEmpty || rawText.length < 3) {
        String errorMsg;
        switch (langCode) {
          case 'ar':
            errorMsg = "لم يتم قراءة أي نص.";
            break;
          case 'fr':
            errorMsg = "Aucun texte détecté.";
            break;
          case 'tr':
            errorMsg = "Metin algılanamadı.";
            break;
          default:
            errorMsg = "No text detected.";
        }
        return MedicineModel.notFound(errorMsg);
      }

      print("📝 OCR Read: ${rawText.replaceAll('\n', ' ')}");

      // -------------------------------------------------------
      // Step 2: Gemini (via OpenAI Compatibility Mode)
      // -------------------------------------------------------
      print("⚡ 2. Sending to Gemini (via OpenAI Protocol)...");
      return await _analyzeWithGemini(rawText, langCode, targetDrug);
    } catch (e) {
      print("❌ Error: $e");
      if (e is ServerException ||
          e is OcrException ||
          e is AiAnalysisException) {
        rethrow;
      }
      throw ServerException(e.toString());
    }
  }

  // ===========================================================================
  // 👁️ Helper: Offline OCR (ML Kit)
  // ===========================================================================
  Future<String> _performOfflineOcr(String path) async {
    final inputImage = InputImage.fromFilePath(path);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final res = await textRecognizer.processImage(inputImage);
      return res.text;
    } catch (e) {
      throw OcrException("ML Kit Error: $e");
    } finally {
      textRecognizer.close();
    }
  }

  // ===========================================================================
  // 🧠 Helper: Gemini Analysis (OpenAI Compatibility Mode)
  // ===========================================================================
  Future<MedicineModel> _analyzeWithGemini(
      String rawText, String langCode, String? targetDrug) async {
    // 🌍 Determine Output Language
    String targetLang;
    switch (langCode) {
      case 'ar':
        targetLang = "ARABIC";
        break;
      case 'fr':
        targetLang = "FRENCH";
        break;
      case 'tr':
        targetLang = "TURKISH";
        break;
      default:
        targetLang = "ENGLISH";
    }

    // 🧠 Dynamic Context Instruction
    String contextInstruction;

    if (targetDrug != null) {
      // 🎯 CASE A: User selected a specific drug
      contextInstruction = """
      USER SELECTION: The user specifically chose to analyze '$targetDrug'.
      TASK: 
      1. Ignore all other brand names.
      2. Focus ONLY on '$targetDrug'.
      3. FORCE OUTPUT SCHEME B (Full Report).
      """;
    } else {
      // 🔍 CASE B: Initial Scan (CRITICAL UPDATE)
      contextInstruction = """
      TASK: INITIAL SCANNING.
      1. Scan text for Pharmaceutical Brand Names.
      2. 🧹 FILTERING RULES:
         - Ignore manufacturer names (GSK, Pfizer).
         - Ignore generic names IF a brand name exists.
         - 'Panadol' and 'Panadol Extra' count as DIFFERENT brands.
         - 'Panadol' and 'Paracetamol' count as THE SAME drug (Panadol).

      3. 🚦 DECISION NODE:
         - IF you see 2 or more DISTINCT BRAND NAMES (e.g. 'Advil' AND 'Tylenol'):
           -> YOU MUST USE OUTPUT SCHEME A (Multiple Detected).
           -> DO NOT GENERATE A FULL REPORT.
           
         - ELSE (Single Drug):
           -> USE OUTPUT SCHEME B (Full Report).
      """;
    }

    // 📝 The Master System Prompt (Updated to support 2 Distinct Schemas)
    final systemInstruction = """
    You are a Senior Clinical Pharmacist AI.
    OUTPUT LANGUAGE: $targetLang

    --- 🛡️ STEP 1: SAFETY GUARDRAIL ---
    Does the text represent a MEDICINE, VITAMIN, or DIETARY SUPPLEMENT?
    IF NOT: Return { "error": "not_a_drug" }

    --- 🚦 STEP 2: CONTEXT ---
    $contextInstruction

    --- 📤 STEP 3: OUTPUT SCHEMAS (CHOOSE ONE ONLY) ---

    🔴 SCHEME A: MULTIPLE DRUGS DETECTED
    Use this if more than 1 distinct brand is found.
    {
      "multiple_detected": true,
      "options": ["Brand Name 1", "Brand Name 2"]
    }

    🔵 SCHEME B: FULL MEDICAL REPORT (Single Drug)
    Use this if only 1 drug is found OR user selected a specific drug.
    NO SUMMARIES. EXACT INGREDIENTS.
    {
      "multiple_detected": false,
      "brand_name": "String",
      "strength": "String (or N/A)",
      "ingredients": ["Exact ingredient list"],
      
      "dosage_duration": [
          "Recommended dosage (adult/pediatric)",
          "Frequency",
          "Route of administration",
          "Duration",
          "Adjustments"
      ],
      "primary_uses": ["Approved indications", "Off-label uses"],
      "common_side_effects": ["Categorized list", "Frequency"],
      "serious_symptoms": ["Life-threatening reactions", "Seek help immediately"],
      "contraindications": ["Absolute/Relative", "Pregnancy/Children/Elderly"],
      "interactions": ["Drug-Drug", "Drug-Food", "Drug-Alcohol"],
      "storage_disposal": ["Temp", "Light", "Shelf-life", "Disposal"],
      "missed_dose": ["Immediate actions", "What NOT to do"],
      "overdose_response": ["Symptoms", "Emergency actions", "Poison control"]
    }
    """;

    try {
      final url = Uri.parse("${Constants.baseUrl}chat/completions");

      if (Constants.apiKey.isEmpty) {
        throw AiAnalysisException("API Key is MISSING! Check Firebase config.");
      }

      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer ${Constants.apiKey}",
        },
        body: jsonEncode({
          "model": Constants.modelName,
          "messages": [
            {"role": "system", "content": systemInstruction},
            {"role": "user", "content": "OCR Text Input: $rawText"}
          ],
          "temperature": 0.0,
          "response_format": {"type": "json_object"}
        }),
      );

      if (response.statusCode == 200) {
        final decodedBody = jsonDecode(utf8.decode(response.bodyBytes));
        final String? contentText =
            decodedBody['choices']?[0]['message']?['content'];

        if (contentText == null) {
          throw AiAnalysisException("AI returned empty content.");
        }

        final cleanJson =
            contentText.replaceAll(RegExp(r'```json|```'), '').trim();
        final Map<String, dynamic> jsonResponse = jsonDecode(cleanJson);

        if (jsonResponse.containsKey('error')) {
          String errorType = jsonResponse['error'];
          String userMsg;

          if (errorType == 'not_a_drug') {
            switch (langCode) {
              case 'ar':
                userMsg = "عذراً، الصورة لا تبدو لدواء أو مكمل غذائي 🚫";
                break;
              case 'fr':
                userMsg = "Désolé, ce n'est pas un médicament 🚫";
                break;
              case 'tr':
                userMsg = "Üzgünüm, bu bir ilaç değil 🚫";
                break;
              default:
                userMsg = "Sorry, this is not a medicine 🚫";
            }
            return MedicineModel.notFound(userMsg);
          } else {
            return MedicineModel.notFound(langCode == 'ar'
                ? "لم يتم التعرف على الدواء."
                : "Medicine not identified.");
          }
        }

        return MedicineModel.fromJson(jsonResponse);
      } else {
        throw AiAnalysisException(
          "OpenAI API Error: ${response.statusCode} - ${response.body}",
        );
      }
    } catch (e) {
      print("AI Connection Error: $e");
      throw AiAnalysisException("Processing Failed: $e");
    }
  }
}

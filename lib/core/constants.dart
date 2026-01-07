class Constants {
  // ===========================================================================
  // ⚡ AI API Configuration (Loaded dynamically from Firebase)
  // ===========================================================================

  // سيتم ملء هذه القيم تلقائياً عند بدء التطبيق من Firestore
  static String apiKey = "";
  static String baseUrl = "";

  static String modelName = "";

  // ===========================================================================
  // 🌍 OpenFDA (Optional/Legacy - kept just in case)
  // ===========================================================================
  static const String openFdaBaseUrl = "https://api.fda.gov/drug/label.json";
}

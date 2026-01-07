/// Thrown when the server returns a non-200 status code or fails to connect.
class ServerException implements Exception {
  final String message;
  ServerException([this.message = "Server Error"]);

  @override
  String toString() => "ServerException: $message";
}

/// Thrown when Google Cloud Vision fails to read text.
class OcrException implements Exception {
  final String message;
  OcrException([this.message = "OCR Analysis Failed"]);

  @override
  String toString() => "OcrException: $message";
}

/// Thrown when the AI (Groq) fails to process the text or JSON.
class AiAnalysisException implements Exception {
  final String message;
  AiAnalysisException([this.message = "AI Processing Failed"]);

  @override
  String toString() => "AiAnalysisException: $message";
}

/// Thrown when local data cache fails (if you add offline mode later).
class CacheException implements Exception {}

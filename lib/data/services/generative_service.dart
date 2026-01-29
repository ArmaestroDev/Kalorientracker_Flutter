import 'dart:typed_data';

/// Abstract interface for generative AI services (Gemini, Claude)
abstract class GenerativeService {
  Future<String?> getApiResponse(String prompt);
  Future<String?> getApiResponseWithImage(String prompt, Uint8List imageBytes);
}

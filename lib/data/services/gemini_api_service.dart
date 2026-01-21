import 'package:google_generative_ai/google_generative_ai.dart';
import 'generative_service.dart';

/// Gemini AI API service implementation
class GeminiApiService implements GenerativeService {
  late final GenerativeModel _model;

  GeminiApiService(String apiKey) {
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(responseMimeType: 'application/json'),
      safetySettings: [
        SafetySetting(HarmCategory.harassment, HarmBlockThreshold.high),
        SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.high),
        SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.high),
        SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.high),
      ],
    );
  }

  @override
  Future<String?> getApiResponse(String prompt) async {
    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      return response.text;
    } catch (e) {
      print('GeminiError: Error fetching data from API: $e');
      throw Exception('Gemini API Error: $e');
    }
  }
}

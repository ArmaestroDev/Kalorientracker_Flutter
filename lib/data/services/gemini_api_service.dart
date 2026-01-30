import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'generative_service.dart';

/// Gemini AI API service implementation
class GeminiApiService implements GenerativeService {
  late final GenerativeModel _model;
  late final GenerativeModel _textModel;

  GeminiApiService(String apiKey) {
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(responseMimeType: 'application/json'),
      safetySettings: _safetySettings,
    );
    _textModel = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
      // No responseMimeType enforcement for text model
      safetySettings: _safetySettings,
    );
  }

  static final _safetySettings = [
    SafetySetting(HarmCategory.harassment, HarmBlockThreshold.high),
    SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.high),
    SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.high),
    SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.high),
  ];

  @override
  Future<String?> getApiResponse(String prompt, {bool forceJson = true}) async {
    try {
      final content = [Content.text(prompt)];
      final modelToUse = forceJson ? _model : _textModel;
      final response = await modelToUse.generateContent(content);
      return response.text;
    } catch (e) {
      print('GeminiError: Error fetching data from API: $e');
      throw Exception('Gemini API Error: $e');
    }
  }

  @override
  Future<String?> getApiResponseWithImage(
    String prompt,
    Uint8List imageBytes,
  ) async {
    try {
      final content = [
        Content.multi([TextPart(prompt), DataPart('image/jpeg', imageBytes)]),
      ];
      final response = await _model.generateContent(content);
      return response.text;
    } catch (e) {
      print('GeminiError: Error fetching image data from API: $e');
      throw Exception('Gemini API Error: $e');
    }
  }
}

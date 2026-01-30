import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'generative_service.dart';

/// Grok (xAI) API service implementation
class GrokApiService implements GenerativeService {
  final String _apiKey;
  static const String _baseUrl = 'https://api.x.ai/v1/chat/completions';
  static const String _model = 'grok-4-0709'; // Or grok-beta

  GrokApiService(this._apiKey);

  @override
  Future<String?> getApiResponse(String prompt) async {
    try {
      final response = await http
          .post(
            Uri.parse(_baseUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_apiKey',
            },
            body: jsonEncode({
              'model': _model,
              'messages': [
                {
                  'role': 'system',
                  'content': 'You are a helpful nutrition assistant.',
                },
                {'role': 'user', 'content': prompt},
              ],
              'temperature': 0.7,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final json =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final choices = json['choices'] as List<dynamic>;
        if (choices.isNotEmpty) {
          return choices[0]['message']['content'] as String?;
        }
      } else {
        print('GrokError: HTTP ${response.statusCode} - ${response.body}');
        throw Exception(
          'Grok API Error: ${response.statusCode} - ${response.body}',
        );
      }
      return null;
    } catch (e) {
      print('GrokError: Error fetching data from Grok API: $e');
      rethrow;
    }
  }

  @override
  Future<String?> getApiResponseWithImage(
    String prompt,
    Uint8List imageBytes,
  ) async {
    try {
      final base64Image = base64Encode(imageBytes);
      final response = await http
          .post(
            Uri.parse(_baseUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_apiKey',
            },
            body: jsonEncode({
              'model': _model,
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': prompt},
                    {
                      'type': 'image_url',
                      'image_url': {
                        'url': 'data:image/jpeg;base64,$base64Image',
                      },
                    },
                  ],
                },
              ],
              // Grok currently supports vision in grok-2-vision, check if latest covers it,
              // otherwise might need specific model. Assuming grok-2-latest is multimodal or similar.
              // If not, this might fail, but standard OpenAI format is used.
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final json =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final choices = json['choices'] as List<dynamic>;
        if (choices.isNotEmpty) {
          return choices[0]['message']['content'] as String?;
        }
      } else {
        print('GrokError: HTTP ${response.statusCode} - ${response.body}');
        throw Exception(
          'Grok API Error: ${response.statusCode} - ${response.body}',
        );
      }
      return null;
    } catch (e) {
      print('GrokError: Error fetching image data from Grok API: $e');
      rethrow;
    }
  }
}

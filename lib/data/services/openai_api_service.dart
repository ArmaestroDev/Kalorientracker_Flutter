import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'generative_service.dart';

/// OpenAI API service implementation
class OpenAiApiService implements GenerativeService {
  final String _apiKey;
  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';
  static const String _model = 'gpt-4o';

  OpenAiApiService(this._apiKey);

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
        print('OpenAiError: HTTP ${response.statusCode} - ${response.body}');
        throw Exception(
          'OpenAI API Error: ${response.statusCode} - ${response.body}',
        );
      }
      return null;
    } catch (e) {
      print('OpenAiError: Error fetching data from OpenAI API: $e');
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
              'max_tokens': 1000,
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
        print('OpenAiError: HTTP ${response.statusCode} - ${response.body}');
        throw Exception(
          'OpenAI API Error: ${response.statusCode} - ${response.body}',
        );
      }
      return null;
    } catch (e) {
      print('OpenAiError: Error fetching image data from OpenAI API: $e');
      rethrow;
    }
  }
}

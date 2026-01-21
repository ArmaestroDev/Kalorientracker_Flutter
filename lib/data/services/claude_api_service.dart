import 'dart:convert';
import 'package:http/http.dart' as http;
import 'generative_service.dart';

/// Claude AI API service implementation
class ClaudeApiService implements GenerativeService {
  final String _apiKey;
  static const String _baseUrl = 'https://api.anthropic.com/v1/messages';

  ClaudeApiService(this._apiKey);

  @override
  Future<String?> getApiResponse(String prompt) async {
    try {
      final response = await http
          .post(
            Uri.parse(_baseUrl),
            headers: {
              'Content-Type': 'application/json',
              'x-api-key': _apiKey,
              'anthropic-version': '2023-06-01',
            },
            body: jsonEncode({
              'model': 'claude-3-5-sonnet-20240620',
              'max_tokens': 1024,
              'messages': [
                {'role': 'user', 'content': prompt},
              ],
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final content = json['content'] as List<dynamic>;
        if (content.isNotEmpty) {
          return content[0]['text'] as String?;
        }
      } else {
        print('ClaudeError: HTTP ${response.statusCode} - ${response.body}');
        throw Exception(
          'Claude API Error: ${response.statusCode} - ${response.body}',
        );
      }
      return null;
    } catch (e) {
      print('ClaudeError: Error fetching data from Claude API: $e');
      rethrow;
    }
  }
}

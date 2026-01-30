import 'dart:typed_data';

abstract class GenerativeService {
  Future<String?> getApiResponse(String prompt, {bool forceJson = true});
  Future<String?> getApiResponseWithImage(String prompt, Uint8List imageBytes);
}

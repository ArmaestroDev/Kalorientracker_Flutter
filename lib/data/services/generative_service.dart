/// Abstract interface for generative AI services (Gemini, Claude)
abstract class GenerativeService {
  Future<String?> getApiResponse(String prompt);
}

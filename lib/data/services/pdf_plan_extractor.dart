import 'dart:typed_data';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class PdfExtractionResult {
  final String text;
  final int pageCount;

  const PdfExtractionResult({required this.text, required this.pageCount});

  bool get hasMeaningfulText => text.replaceAll(RegExp(r'\s+'), '').length >= 40;
}

class PdfPlanExtractor {
  static PdfExtractionResult extractText(Uint8List bytes) {
    final document = PdfDocument(inputBytes: bytes);
    try {
      final pageCount = document.pages.count;
      final extractor = PdfTextExtractor(document);
      final buffer = StringBuffer();
      for (var i = 0; i < pageCount; i++) {
        final pageText = extractor.extractText(
          startPageIndex: i,
          endPageIndex: i,
        );
        final cleaned = _normalize(pageText);
        if (cleaned.isNotEmpty) {
          if (buffer.isNotEmpty) buffer.writeln('\n');
          if (pageCount > 1) buffer.writeln('--- Seite ${i + 1} ---');
          buffer.write(cleaned);
        }
      }
      return PdfExtractionResult(
        text: buffer.toString().trim(),
        pageCount: pageCount,
      );
    } finally {
      document.dispose();
    }
  }

  static String _normalize(String raw) {
    return raw
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .map((line) => line.trimRight())
        .join('\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../data/services/food_api_service.dart';
import '../theme/tokens.dart';
import '../widgets/app_text_field.dart';
import '../widgets/kit/kit.dart';
import 'barcode_scanner_screen.dart';

/// Screen for photo-based input: unified barcode scanning + food photo AI estimation.
/// Any taken or picked photo is checked for a barcode first; if none is found
/// (or no product matches), it falls back to normal AI calorie estimation.
class PhotoInputScreen extends StatefulWidget {
  final Function(String barcode) onBarcodeScanned;
  final Future<bool> Function(Uint8List imageBytes, String? description)
  onPhotoTaken;
  final Future<FoodNutritionInfo?> Function(String barcode)? onLookupBarcode;
  final void Function(FoodNutritionInfo info)? onBarcodeProductFound;

  const PhotoInputScreen({
    super.key,
    required this.onBarcodeScanned,
    required this.onPhotoTaken,
    this.onLookupBarcode,
    this.onBarcodeProductFound,
  });

  @override
  State<PhotoInputScreen> createState() => _PhotoInputScreenState();
}

class _PhotoInputScreenState extends State<PhotoInputScreen> {
  final _descriptionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  Uint8List? _capturedImage;
  bool _isProcessing = false;
  bool _checkingBarcode = false;
  String? _detectedUnknownBarcode;

  static bool get _supportsLiveScanner {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  static bool get _supportsAnalyzeImage {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _openBarcodeScanner() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => BarcodeScannerScreen(
          onBarcodeScanned: (barcode) {
            Navigator.of(context).pop(barcode);
          },
          onTakePhoto: _takePhoto,
          onPickGallery: _pickFromGallery,
        ),
      ),
    );

    if (result != null && mounted) {
      widget.onBarcodeScanned(result);
      Navigator.of(context).pop();
    }
  }

  Future<void> _handlePickedFile(XFile photo) async {
    final bytes = await photo.readAsBytes();
    if (!mounted) return;

    String? detectedBarcode;
    if (_supportsAnalyzeImage && photo.path.isNotEmpty) {
      setState(() {
        _checkingBarcode = true;
        _detectedUnknownBarcode = null;
      });
      try {
        final analyzer = MobileScannerController(
          autoStart: false,
          formats: retailBarcodeFormats,
        );
        try {
          final capture = await analyzer.analyzeImage(
            photo.path,
            formats: retailBarcodeFormats,
          );
          detectedBarcode = capture?.barcodes.firstOrNull?.rawValue?.trim();
        } finally {
          await analyzer.dispose();
        }
      } catch (_) {
        detectedBarcode = null;
      }
    }

    if (detectedBarcode != null && detectedBarcode.isNotEmpty && mounted) {
      if (widget.onLookupBarcode != null &&
          widget.onBarcodeProductFound != null) {
        final product = await widget.onLookupBarcode!(detectedBarcode);
        if (!mounted) return;
        if (product != null && product.calories >= 0) {
          setState(() => _checkingBarcode = false);
          widget.onBarcodeProductFound!(product);
          Navigator.of(context).pop();
          return;
        }
        setState(() {
          _checkingBarcode = false;
          _detectedUnknownBarcode = detectedBarcode;
          _capturedImage = bytes;
        });
        return;
      }
      setState(() => _checkingBarcode = false);
      widget.onBarcodeScanned(detectedBarcode);
      Navigator.of(context).pop();
      return;
    }

    if (mounted) {
      setState(() {
        _checkingBarcode = false;
        _detectedUnknownBarcode = null;
        _capturedImage = bytes;
      });
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (photo != null) {
        await _handlePickedFile(photo);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _checkingBarcode = false);
        AppFeedback.error(context, 'Fehler beim Aufnehmen: $e');
      }
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (photo != null) {
        await _handlePickedFile(photo);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _checkingBarcode = false);
        AppFeedback.error(context, 'Fehler beim Auswählen: $e');
      }
    }
  }

  Future<void> _submitPhoto() async {
    if (_capturedImage == null || _isProcessing) return;
    setState(() => _isProcessing = true);
    final desc = _descriptionController.text.trim();
    final ok = await widget.onPhotoTaken(
      _capturedImage!,
      desc.isEmpty ? null : desc,
    );
    if (!mounted) return;
    setState(() => _isProcessing = false);
    if (ok) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Foto & Barcode')),
      body: Column(
        children: [
          if (_checkingBarcode) ...[
            const LinearProgressIndicator(),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.screenX,
                Space.sm,
                Space.screenX,
                0,
              ),
              child: Text(
                'Prüfe Bild auf Barcode …',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
          Expanded(
            child: _capturedImage == null
                ? _buildSelectionView()
                : _buildPreviewView(),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionView() {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Space.screenX,
        Space.sm,
        Space.screenX,
        Space.xxl,
      ),
      children: [
        const SectionHeader('Wähle eine Option', padding: EdgeInsets.zero),
        const SizedBox(height: Space.xs),
        Text(
          'Barcodes in Fotos werden automatisch erkannt – ohne Barcode schätzt die KI die Kalorien.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Space.lg),
        if (_supportsLiveScanner) ...[
          _OptionCard(
            icon: Icons.qr_code_scanner_rounded,
            title: 'Kamera (Barcode & Foto)',
            subtitle: 'Live-Barcode-Scanner oder direkt Foto aufnehmen',
            onTap: _openBarcodeScanner,
          ),
          const SizedBox(height: Space.md),
        ],
        _OptionCard(
          icon: Icons.photo_camera_outlined,
          title: 'Foto aufnehmen',
          subtitle: 'Erkennt Barcode automatisch, sonst KI-Schätzung',
          onTap: _takePhoto,
        ),
        const SizedBox(height: Space.md),
        _OptionCard(
          icon: Icons.photo_library_outlined,
          title: 'Aus Galerie wählen',
          subtitle: 'Erkennt Barcode automatisch, sonst KI-Schätzung',
          onTap: _pickFromGallery,
        ),
      ],
    );
  }

  Widget _buildPreviewView() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Space.screenX,
        Space.sm,
        Space.screenX,
        Space.xxl,
      ),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(Corner.lg),
          child: Image.memory(_capturedImage!, height: 300, fit: BoxFit.cover),
        ),
        if (_detectedUnknownBarcode != null) ...[
          const SizedBox(height: Space.md),
          Notice(
            message:
                'Barcode $_detectedUnknownBarcode nicht in der Datenbank gefunden – schätze das Foto jetzt einfach direkt mit KI.',
          ),
        ],
        const SizedBox(height: Space.lg),
        AppTextField(
          controller: _descriptionController,
          label: 'Beschreibung (optional)',
          hint: 'z. B. Schnitzel mit Pommes, ca. 300 g',
          textCapitalization: TextCapitalization.sentences,
          maxLines: 3,
          minLines: 1,
        ),
        const SizedBox(height: Space.sm),
        Text(
          'Die KI analysiert das Bild und schätzt die Kalorien.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Space.lg),
        FilledButton.icon(
          onPressed: _isProcessing ? null : _submitPhoto,
          icon: _isProcessing
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.analytics_outlined),
          label: const Text('Analysieren'),
        ),
        const SizedBox(height: Space.md),
        OutlinedButton.icon(
          onPressed: _isProcessing
              ? null
              : () {
                  setState(() {
                    _capturedImage = null;
                    _detectedUnknownBarcode = null;
                    _descriptionController.clear();
                  });
                },
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Neues Foto'),
        ),
      ],
    );
  }
}

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(Space.lg),
      child: Row(
        children: [
          Icon(icon, size: 24, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: Space.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../data/services/food_api_service.dart';
import '../widgets/app_text_field.dart';
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fehler beim Aufnehmen: $e')));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fehler beim Auswählen: $e')));
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
    return Scaffold(
      appBar: AppBar(title: const Text('Foto & Barcode')),
      body: Stack(
        children: [
          _capturedImage == null
              ? _buildSelectionView()
              : _buildPreviewView(),
          if (_checkingBarcode)
            Container(
              color: Colors.black38,
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Prüfe Bild auf Barcode …'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSelectionView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Wähle eine Option:',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Barcodes in Fotos werden automatisch erkannt – ohne Barcode schätzt die KI die Kalorien.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          if (_supportsLiveScanner) ...[
            _OptionCard(
              icon: Icons.qr_code_scanner,
              title: 'Kamera (Barcode & Foto)',
              subtitle: 'Live-Barcode-Scanner oder direkt Foto aufnehmen',
              onTap: _openBarcodeScanner,
            ),
            const SizedBox(height: 16),
          ],
          _OptionCard(
            icon: Icons.camera_alt,
            title: 'Foto aufnehmen',
            subtitle: 'Erkennt Barcode automatisch, sonst KI-Schätzung',
            onTap: _takePhoto,
          ),
          const SizedBox(height: 16),
          _OptionCard(
            icon: Icons.photo_library,
            title: 'Aus Galerie wählen',
            subtitle: 'Erkennt Barcode automatisch, sonst KI-Schätzung',
            onTap: _pickFromGallery,
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewView() {
    final colorScheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              _capturedImage!,
              height: 300,
              fit: BoxFit.cover,
            ),
          ),
          if (_detectedUnknownBarcode != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Barcode $_detectedUnknownBarcode nicht in der Datenbank gefunden – schätze das Foto jetzt einfach direkt mit KI.',
                style: TextStyle(color: colorScheme.onSecondaryContainer),
              ),
            ),
          ],
          const SizedBox(height: 16),
          AppTextField(
            controller: _descriptionController,
            label: 'Beschreibung (optional)',
            hint: 'z. B. Schnitzel mit Pommes, ca. 300 g',
            textCapitalization: TextCapitalization.sentences,
            maxLines: 3,
            minLines: 1,
          ),
          const SizedBox(height: 8),
          Text(
            'Die KI analysiert das Bild und schätzt die Kalorien.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isProcessing
                      ? null
                      : () {
                          setState(() {
                            _capturedImage = null;
                            _detectedUnknownBarcode = null;
                            _descriptionController.clear();
                          });
                        },
                  child: const Text('Neues Foto'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton(
                  onPressed: _isProcessing ? null : _submitPhoto,
                  child: _isProcessing
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Analysieren'),
                ),
              ),
            ],
          ),
        ],
      ),
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
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(
                icon,
                size: 40,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

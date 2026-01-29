import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'barcode_scanner_screen.dart';

/// Screen for photo-based input: either barcode scanning or food photo
class PhotoInputScreen extends StatefulWidget {
  final Function(String barcode) onBarcodeScanned;
  final Function(Uint8List imageBytes, String? description) onPhotoTaken;

  const PhotoInputScreen({
    super.key,
    required this.onBarcodeScanned,
    required this.onPhotoTaken,
  });

  @override
  State<PhotoInputScreen> createState() => _PhotoInputScreenState();
}

class _PhotoInputScreenState extends State<PhotoInputScreen> {
  final _descriptionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  Uint8List? _capturedImage;
  bool _isProcessing = false;

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
            // Return the barcode via Navigator instead of calling callback directly
            Navigator.of(context).pop(barcode);
          },
        ),
      ),
    );

    // If a barcode was scanned, call the callback and close this screen
    if (result != null && mounted) {
      widget.onBarcodeScanned(result);
      Navigator.of(context).pop();
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
        final bytes = await photo.readAsBytes();
        setState(() {
          _capturedImage = bytes;
        });
      }
    } catch (e) {
      if (mounted) {
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
        final bytes = await photo.readAsBytes();
        setState(() {
          _capturedImage = bytes;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fehler beim Auswählen: $e')));
      }
    }
  }

  void _submitPhoto() {
    if (_capturedImage != null) {
      setState(() => _isProcessing = true);
      widget.onPhotoTaken(
        _capturedImage!,
        _descriptionController.text.isEmpty
            ? null
            : _descriptionController.text,
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Foto-Eingabe')),
      body: _capturedImage == null
          ? _buildSelectionView()
          : _buildPreviewView(),
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
          const SizedBox(height: 32),
          _OptionCard(
            icon: Icons.qr_code_scanner,
            title: 'Barcode scannen',
            subtitle: 'Produkt-Barcode einscannen',
            onTap: _openBarcodeScanner,
          ),
          const SizedBox(height: 16),
          _OptionCard(
            icon: Icons.camera_alt,
            title: 'Foto aufnehmen',
            subtitle: 'Essen fotografieren für KI-Schätzung',
            onTap: _takePhoto,
          ),
          const SizedBox(height: 16),
          _OptionCard(
            icon: Icons.photo_library,
            title: 'Aus Galerie wählen',
            subtitle: 'Vorhandenes Foto auswählen',
            onTap: _pickFromGallery,
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewView() {
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
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Beschreibung (optional)',
              hintText: 'z.B. Schnitzel mit Pommes',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 8),
          Text(
            'Die KI analysiert das Bild und schätzt die Kalorien.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _capturedImage = null;
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

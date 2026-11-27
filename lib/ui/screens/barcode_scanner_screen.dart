import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../theme/tokens.dart';

const List<BarcodeFormat> retailBarcodeFormats = [
  BarcodeFormat.ean13,
  BarcodeFormat.ean8,
  BarcodeFormat.upcA,
  BarcodeFormat.upcE,
  BarcodeFormat.code128,
  BarcodeFormat.code39,
  BarcodeFormat.itf,
];

class BarcodeScannerScreen extends StatefulWidget {
  final Function(String barcode) onBarcodeScanned;
  final VoidCallback? onTakePhoto;
  final VoidCallback? onPickGallery;

  const BarcodeScannerScreen({
    super.key,
    required this.onBarcodeScanned,
    this.onTakePhoto,
    this.onPickGallery,
  });

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: retailBarcodeFormats,
  );
  bool _hasScanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (_hasScanned) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.trim().isEmpty) return;
    _hasScanned = true;
    widget.onBarcodeScanned(raw.trim());
  }

  Future<void> _switchToPhoto(VoidCallback action) async {
    await _controller.stop();
    if (!mounted) return;
    Navigator.of(context).pop();
    action();
  }

  @override
  Widget build(BuildContext context) {
    final hasPhotoActions =
        widget.onTakePhoto != null || widget.onPickGallery != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(hasPhotoActions ? 'Kamera & Barcode' : 'Barcode scannen'),
        actions: [
          IconButton(
            tooltip: 'Blitz',
            icon: ValueListenableBuilder(
              valueListenable: _controller,
              builder: (context, state, child) {
                return Icon(
                  state.torchState == TorchState.on
                      ? Icons.flashlight_on_outlined
                      : Icons.flashlight_off_outlined,
                );
              },
            ),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            tooltip: 'Kamera wechseln',
            icon: const Icon(Icons.cameraswitch_outlined),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final scanSize = (constraints.biggest.shortestSide * 0.7).clamp(
            180.0,
            280.0,
          );
          final scanWindow = Rect.fromCenter(
            center: Offset(
              constraints.maxWidth / 2,
              constraints.maxHeight / 2 - (hasPhotoActions ? 36 : 0),
            ),
            width: scanSize,
            height: scanSize,
          );

          return Stack(
            children: [
              MobileScanner(
                controller: _controller,
                scanWindow: scanWindow,
                onDetect: _onBarcodeDetected,
                errorBuilder: (context, error, _) {
                  return Center(
                                            child: Padding(
                      padding: const EdgeInsets.all(Space.xl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.videocam_off_outlined,
                            size: 48,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(height: Space.md),
                          Text(
                            error.errorCode ==
                                    MobileScannerErrorCode.permissionDenied
                                ? 'Kamera-Berechtigung wurde verweigert. Bitte in den App-Einstellungen erlauben.'
                                : 'Kamera konnte nicht gestartet werden (${error.errorCode.name}).',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              Positioned.fromRect(
                rect: scanWindow,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: Stroke.emphasis,
                    ),
                    borderRadius: BorderRadius.circular(Corner.lg),
                  ),
                ),
              ),
              Positioned(
                bottom: hasPhotoActions ? Space.xxl : Space.xxl + Space.lg,
                left: Space.screenX,
                right: Space.screenX,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Space.lg,
                        vertical: Space.sm,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.inverseSurface,
                        borderRadius: BorderRadius.circular(Corner.full),
                      ),
                      child: Text(
                        hasPhotoActions
                            ? 'Barcode wird automatisch erkannt – sonst Foto aufnehmen'
                            : 'Richte die Kamera auf den Barcode',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onInverseSurface,
                        ),
                      ),
                    ),
                    if (hasPhotoActions) ...[
                      const SizedBox(height: Space.lg),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (widget.onPickGallery != null)
                            FilledButton.tonalIcon(
                              onPressed: () =>
                                  _switchToPhoto(widget.onPickGallery!),
                              icon: const Icon(Icons.photo_library_outlined),
                              label: const Text('Galerie'),
                            ),
                          if (widget.onPickGallery != null &&
                              widget.onTakePhoto != null)
                            const SizedBox(width: Space.md),
                          if (widget.onTakePhoto != null)
                            FilledButton.icon(
                              onPressed: () =>
                                  _switchToPhoto(widget.onTakePhoto!),
                              icon: const Icon(Icons.photo_camera_outlined),
                              label: const Text('Foto aufnehmen'),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

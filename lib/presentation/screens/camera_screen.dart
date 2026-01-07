import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const CameraScreen({super.key, required this.cameras});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;

  // 🔍 Zoom Variables
  bool _isFlashOn = false;
  double _currentZoom = 1.0;
  double _maxZoom = 1.0;
  double _minZoom = 1.0;
  double _baseZoom = 1.0; // Needed for Pinch calculation
  bool _isTakingPicture = false; // Added to prevent double taps

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  Future<void> _initCamera() async {
    if (widget.cameras.isEmpty) return;

    _controller = CameraController(
      widget.cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => widget.cameras.first,
      ),
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    _initializeControllerFuture = _controller!.initialize().then((_) async {
      if (!mounted) return;
      _maxZoom = await _controller!.getMaxZoomLevel();
      _minZoom = await _controller!.getMinZoomLevel();
      _controller!.setFlashMode(FlashMode.off);
      setState(() {});
    }).catchError((Object e) {
      if (e is CameraException) {
        debugPrint("Camera Init Error: ${e.description}");
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  // 🔍 Unified Zoom Logic
  Future<void> _setZoom(double zoom) async {
    if (_controller == null) return;
    final newZoom = zoom.clamp(_minZoom, _maxZoom);
    if (newZoom != _currentZoom) {
      setState(() {
        _currentZoom = newZoom;
      });
      await _controller!.setZoomLevel(newZoom);
    }
  }

  Future<void> _toggleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    try {
      setState(() {
        _isFlashOn = !_isFlashOn;
      });
      await _controller!.setFlashMode(
        _isFlashOn ? FlashMode.torch : FlashMode.off,
      );
    } catch (e) {
      debugPrint("Flash Error: $e");
    }
  }

  // ✅ Crop ONLY what’s inside the scanner box, ignore outside
  Future<String?> _cropToScannerBox(String imagePath, Size screenSize) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      img.Image? original = img.decodeImage(bytes);
      if (original == null) return null;

      // Fix orientation from EXIF (very important on many devices)
      original = img.bakeOrientation(original);

      final int imgW = original.width;
      final int imgH = original.height;

      // Scanner box in screen coordinates (same as your overlay)
      final double boxW = screenSize.width * 0.8;
      final double boxH = screenSize.width * 0.8 * 1.2;
      final double boxLeft = (screenSize.width - boxW) / 2.0;
      final double boxTop = (screenSize.height - boxH) / 2.0;

      // Assume the preview behaves like BoxFit.cover for mapping
      // Compute how the image would cover the screen
      final double scale = (screenSize.width / imgW > screenSize.height / imgH)
          ? (screenSize.width / imgW)
          : (screenSize.height / imgH);

      final double scaledW = imgW * scale;
      final double scaledH = imgH * scale;

      // Center-crop offsets (what gets cut off on left/top when covering)
      final double offsetX = (scaledW - screenSize.width) / 2.0;
      final double offsetY = (scaledH - screenSize.height) / 2.0;

      // Convert screen rect -> image rect
      int cropX = ((boxLeft + offsetX) / scale).round();
      int cropY = ((boxTop + offsetY) / scale).round();
      int cropW = (boxW / scale).round();
      int cropH = (boxH / scale).round();

      // Clamp to image bounds
      cropX = cropX.clamp(0, imgW - 1);
      cropY = cropY.clamp(0, imgH - 1);

      if (cropX + cropW > imgW) cropW = imgW - cropX;
      if (cropY + cropH > imgH) cropH = imgH - cropY;

      if (cropW <= 1 || cropH <= 1) return null;

      final img.Image cropped = img.copyCrop(
        original,
        x: cropX,
        y: cropY,
        width: cropW,
        height: cropH,
      );

      final String dir = p.dirname(imagePath);
      final String name = p.basenameWithoutExtension(imagePath);
      final String outPath = p.join(dir, "${name}_cropped.jpg");

      final outBytes = img.encodeJpg(cropped, quality: 92);
      await File(outPath).writeAsBytes(outBytes, flush: true);

      return outPath;
    } catch (e) {
      debugPrint("Crop Error: $e");
      return null;
    }
  }

  // 🔥🔥 UPDATED LOGIC: CAPTURE + CROP TO BOX + RETURN 🔥🔥
  Future<void> _takePictureAndReturn() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isTakingPicture) return;

    HapticFeedback.mediumImpact();

    try {
      setState(() {
        _isTakingPicture = true;
      });

      // Turn off flash briefly before capture to avoid glare (optional)
      if (_isFlashOn) {
        await _controller!.setFlashMode(FlashMode.off);
        await Future.delayed(const Duration(milliseconds: 100));
      }

      final XFile image = await _controller!.takePicture();

      // Restore flash if it was on
      if (_isFlashOn) await _controller!.setFlashMode(FlashMode.torch);

      if (!mounted) return;

      // ✅ Crop to scanner box only
      final Size screenSize = MediaQuery.of(context).size;
      final String? croppedPath =
          await _cropToScannerBox(image.path, screenSize);

      // 🚀 Return cropped image path (fallback to original if crop fails)
      Navigator.pop(context, croppedPath ?? image.path);
    } catch (e) {
      debugPrint("Camera Capture Error: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isTakingPicture = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final deviceRatio = size.width / size.height;

    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done &&
              _controller != null &&
              _controller!.value.isInitialized) {
            return GestureDetector(
              behavior: HitTestBehavior.translucent,
              onScaleStart: (details) {
                _baseZoom = _currentZoom;
              },
              onScaleUpdate: (details) {
                _setZoom(_baseZoom * details.scale);
              },
              child: Stack(
                children: [
                  // 1. Camera Preview
                  Center(
                    child: Transform.scale(
                      scale: 1 / (_controller!.value.aspectRatio * deviceRatio),
                      child: CameraPreview(_controller!),
                    ),
                  ),

                  // 2. Overlay (Scanner Box)
                  _buildScannerOverlay(),

                  // 3. Top Controls (Close & Flash)
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildGlassIconButton(
                            icon: Icons.close_rounded,
                            onTap: () => Navigator.pop(context),
                          ),
                          _buildGlassIconButton(
                            icon: _isFlashOn
                                ? Icons.flash_on_rounded
                                : Icons.flash_off_rounded,
                            color:
                                _isFlashOn ? Colors.yellowAccent : Colors.white,
                            onTap: _toggleFlash,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 4. Bottom Controls (Zoom Buttons + Shutter)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: _buildBottomControls(_isTakingPicture),
                  ),
                ],
              ),
            );
          } else {
            return Container(
              color: Colors.black,
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFF2A9D8F)),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildScannerOverlay() {
    return ColorFiltered(
      colorFilter: ColorFilter.mode(
        Colors.black.withOpacity(0.5),
        BlendMode.srcOut,
      ),
      child: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(color: Colors.transparent),
            child: Align(
              alignment: Alignment.center,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.8,
                height: MediaQuery.of(context).size.width * 0.8 * 1.2,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.8),
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(bool isProcessing) {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withOpacity(0.9), Colors.transparent],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Zoom Buttons
            if (!isProcessing)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildZoomButton(1.0, "1x"),
                      const SizedBox(width: 8),
                      _buildZoomButton(2.0, "2x"),
                      if (_maxZoom >= 3.0) ...[
                        const SizedBox(width: 8),
                        _buildZoomButton(3.0, "3x"),
                      ],
                    ],
                  ),
                ),
              ),

            Text(
              "امسح عبوة الدواء داخل الإطار",
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),

            // Shutter Button
            GestureDetector(
              onTap: isProcessing ? null : _takePictureAndReturn,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 80,
                width: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(isProcessing ? 0.2 : 1.0),
                    width: 4,
                  ),
                ),
                child: isProcessing
                    ? const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(
                          color: Color(0xFF2A9D8F),
                          strokeWidth: 3,
                        ),
                      )
                    : Container(
                        margin: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildZoomButton(double zoomValue, String label) {
    final isSelected = (_currentZoom - zoomValue).abs() < 0.5;
    return GestureDetector(
      onTap: () => _setZoom(zoomValue),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2A9D8F) : Colors.transparent,
          shape: BoxShape.circle,
          border: isSelected
              ? null
              : Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white.withOpacity(0.8),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassIconButton({
    required IconData icon,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }
}

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../services/page_number_ocr_service.dart';
import 'mushaf_navigation.dart';

class MushafScannerScreen extends StatefulWidget {
  const MushafScannerScreen({super.key});

  @override
  State<MushafScannerScreen> createState() => _MushafScannerScreenState();
}

class _MushafScannerScreenState extends State<MushafScannerScreen> {
  CameraController? _cameraController;
  String? _cameraError;
  bool _isProcessing = false;
  int? _detectedPage;
  String? _ocrError;
  Uint8List? _debugCropBytes;
  String? _debugRawText;

  static const double _roiLeft = 0.35;
  static const double _roiTop = 0.45;
  static const double _roiWidth = 0.30;
  static const double _roiHeight = 0.10;

  final _ocrService = PageNumberOcrService();

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _cameraError = AppLocalizations.of(context)!.noCamera);
        return;
      }
      final controller = CameraController(cameras[0], ResolutionPreset.medium);
      await controller.initialize();
      if (mounted) setState(() => _cameraController = controller);
    } on CameraException catch (e) {
      if (mounted) {
        setState(
          () => _cameraError = '${AppLocalizations.of(context)!.cameraError} ${e.description ?? e.code}',
        );
      }
    } catch (e) {
      if (mounted) setState(() => _cameraError = '$e');
    }
  }

  Future<void> _captureAndOcr() async {
    if (_cameraController == null || _isProcessing) return;

    setState(() {
      _isProcessing = true;
      _detectedPage = null;
      _ocrError = null;
      _debugCropBytes = null;
      _debugRawText = null;
    });

    try {
      final xfile = await _cameraController!.takePicture();
      final bytes = await xfile.readAsBytes();
      var image = img.decodeImage(bytes);

      if (image == null) {
        if (mounted) setState(() => _ocrError = AppLocalizations.of(context)!.imageDecodeError);
        return;
      }

      image = img.bakeOrientation(image);

      final roiX = (image.width * _roiLeft).round();
      final roiY = (image.height * _roiTop).round();
      final roiW = (image.width * _roiWidth).round();
      final roiH = (image.height * _roiHeight).round();

      final debugDir = (await getApplicationDocumentsDirectory()).path;
      final result = await _ocrService.readPageNumber(
        image,
        x: roiX,
        y: roiY,
        width: roiW,
        height: roiH,
        debugDir: debugDir,
      );

      if (result.debugCropPath != null) {
        final cropFile = File(result.debugCropPath!);
        if (await cropFile.exists()) {
          final cropBytes = await cropFile.readAsBytes();
          if (mounted) setState(() => _debugCropBytes = cropBytes);
        }
      }

      if (mounted) setState(() => _debugRawText = result.rawText);

      if (result.cleanedText.isEmpty) {
        if (mounted) setState(() => _ocrError = AppLocalizations.of(context)!.pageNotRecognized);
        return;
      }

      final pageInt = PageNumberOcrService.toWesternInt(result.cleanedText);
      if (pageInt == null || pageInt < 1 || pageInt > 604) {
        if (mounted) {
          setState(() => _ocrError = '${AppLocalizations.of(context)!.invalidPageNumber} ${result.cleanedText}');
        }
        return;
      }

      if (mounted) setState(() => _detectedPage = pageInt);
    } catch (e) {
      if (mounted) setState(() => _ocrError = '${AppLocalizations.of(context)!.ocrError} $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Stack(
        children: [
          _buildCameraArea(),
          _buildTopBar(),
          if (_detectedPage != null) _buildDetectedPageOverlay(),
          _buildFloatingControls(),
          if (_isProcessing)
            Container(
              color: Colors.black45,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              GlassContainer(
                borderRadius: 20,
                blur: 6,
                opacity: 0.08,
                padding: EdgeInsets.zero,
                width: 40,
                height: 40,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Text(
                AppLocalizations.of(context)!.scanPageNumber,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraArea() {
    if (_cameraError != null) {
      return Center(
        child: Text(
          _cameraError!,
          style: AppTextStyles.englishBody.copyWith(
            color: AppColors.white.withValues(alpha: 0.7),
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final cw = constraints.maxWidth;
        final ch = constraints.maxHeight;
        return Stack(
          children: [
            CameraPreview(_cameraController!),
            CustomPaint(
              size: Size(cw, ch),
              painter: _RoiOverlayPainter(
                rect: Rect.fromLTWH(
                  cw * _roiLeft,
                  ch * _roiTop,
                  cw * _roiWidth,
                  ch * _roiHeight,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFloatingControls() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_ocrError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _ocrError!,
                    style: AppTextStyles.englishBody.copyWith(
                      color: AppColors.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

              if (_debugCropBytes != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white24),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Image.memory(
                          _debugCropBytes!,
                          height: 60,
                          fit: BoxFit.contain,
                        ),
                      ),
                      if (_debugRawText != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child:                           Text(
                            'raw: "$_debugRawText"',
                            style: AppTextStyles.englishBody.copyWith(
                              color: AppColors.white.withValues(alpha: 0.5),
                              fontSize: 11,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                ),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _captureAndOcr,
                  icon: const Icon(Icons.document_scanner),
                  label: Text(
                    _isProcessing ? AppLocalizations.of(context)!.processing : AppLocalizations.of(context)!.scanPageNumber,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: AppColors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetectedPageOverlay() {
    return Positioned(
      top: 80,
      left: 0,
      right: 0,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
            decoration: BoxDecoration(
              color: AppColors.darkBg.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primaryGreen, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 36,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '$_detectedPage',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      MushafNavigation.open(
                        context,
                        MushafNavigation.forPage(_detectedPage!),
                        replace: true,
                      );
                    },
                    icon: const Icon(Icons.arrow_forward, size: 20),
                    label: Text(
                      AppLocalizations.of(context)!.goToPage,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: AppColors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoiOverlayPainter extends CustomPainter {
  final Rect rect;

  _RoiOverlayPainter({required this.rect});

  @override
  void paint(Canvas canvas, Size size) {
    final maskPaint = Paint()..color = const Color(0x88000000);
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()
          ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8))),
      ),
      maskPaint,
    );

    final borderPaint = Paint()
      ..color = AppColors.primaryGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(_RoiOverlayPainter oldDelegate) =>
      rect != oldDelegate.rect;
}

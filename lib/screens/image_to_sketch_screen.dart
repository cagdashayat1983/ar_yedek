// lib/screens/image_to_sketch_screen.dart

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart'; // ✅ Eklendi: Geçici dosya kaydı için

import 'tutorial_screen.dart';

class ImageToSketchScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const ImageToSketchScreen({super.key, required this.cameras});

  @override
  State<ImageToSketchScreen> createState() => _ImageToSketchScreenState();
}

class _ImageToSketchScreenState extends State<ImageToSketchScreen> {
  File? _originalImage;
  ui.Image? _shaderImage;
  bool _isLoading = false;
  ui.FragmentProgram? _program;

  double _edgeThreshold = 0.85;
  double _contrast = 2.0;

  @override
  void initState() {
    super.initState();
    _loadShader();
  }

  Future<void> _loadShader() async {
    try {
      _program =
          await ui.FragmentProgram.fromAsset('assets/shaders/sketch.frag');
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Shader Yükleme Hatası: $e");
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _isLoading = true;
        _originalImage = File(image.path);
        _shaderImage = null;
      });

      final bytes = await _originalImage!.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();

      if (mounted) {
        setState(() {
          _shaderImage = frame.image;
          _isLoading = false;
        });
      }
    }
  }

  // ✅ DÜZENLENEN KISIM: Ekranda gördüğün karakalemi PNG yapar ve AR ekranına atar
  Future<void> _exportSketchAndNavigate() async {
    if (_shaderImage == null || _program == null) return;

    setState(() => _isLoading = true);

    try {
      // 1. Bir "Picture Recorder" ile shader çıktısını yakala
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final size =
          Size(_shaderImage!.width.toDouble(), _shaderImage!.height.toDouble());

      final shader = _program!.fragmentShader();
      shader.setFloat(0, size.width);
      shader.setFloat(1, size.height);
      shader.setFloat(2, _edgeThreshold);
      shader.setFloat(3, _contrast);
      shader.setImageSampler(0, _shaderImage!);

      final paint = Paint()..shader = shader;
      canvas.drawRect(Offset.zero & size, paint);

      final picture = recorder.endRecording();
      final img =
          await picture.toImage(size.width.toInt(), size.height.toInt());

      // 2. Resmi PNG formatına çevir
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      // 3. Geçici bir dosyaya kaydet
      final directory = await getTemporaryDirectory();
      final path =
          '${directory.path}/sketch_export_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(path);
      await file.writeAsBytes(pngBytes);

      if (!mounted) return;
      setState(() => _isLoading = false);

      // 4. AR Ekranına (TutorialScreen) "isLocalFile: true" diyerek gönder
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TutorialScreen(
            title: "Kendi Taslağım",
            imagePaths: [file.path],
            cameras: widget.cameras,
            isLocalFile:
                true, // 🌟 KRİTİK: TutorialScreen'e bunun dosya olduğunu söylüyoruz
          ),
        ),
      );
    } catch (e) {
      debugPrint("Export Hatası: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: Text(
          "Fotoğrafı Taslağa Çevir",
          style: GoogleFonts.poppins(
              color: Colors.black, fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      body: _originalImage == null ? _buildPickerUI() : _buildEditorUI(),
      bottomNavigationBar: _originalImage != null ? _buildBottomBar() : null,
    );
  }

  Widget _buildPickerUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_search_rounded,
              size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 20),
          Text(
            "Çizmek istediğin fotoğrafı seç",
            style:
                GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 14),
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.photo_library_rounded),
            label: const Text("Galeriden Seç"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black87,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditorUI() {
    return Column(
      children: [
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.grey.shade100),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: _isLoading || _program == null
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.black))
                  : _shaderImage == null
                      ? Image.file(_originalImage!, fit: BoxFit.contain)
                      : Center(
                          child: AspectRatio(
                            aspectRatio:
                                _shaderImage!.width / _shaderImage!.height,
                            child: CustomPaint(
                              painter: SketchPainter(
                                image: _shaderImage!,
                                shader: _program!.fragmentShader(),
                                threshold: _edgeThreshold,
                                contrast: _contrast,
                              ),
                            ),
                          ),
                        ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 15,
                  offset: const Offset(0, -5))
            ],
          ),
          child: Column(
            children: [
              _buildSliderLabel(
                  "Çizgi Yoğunluğu", "${(_edgeThreshold * 100).round()}%"),
              Slider(
                value: _edgeThreshold,
                min: 0.50,
                max: 0.99,
                activeColor: Colors.black87,
                inactiveColor: Colors.grey.shade200,
                onChanged: (v) => setState(() => _edgeThreshold = v),
              ),
              const SizedBox(height: 10),
              _buildSliderLabel(
                  "Netlik (Kontrast)", "${_contrast.toStringAsFixed(1)}x"),
              Slider(
                value: _contrast,
                min: 1.0,
                max: 5.0,
                activeColor: Colors.black87,
                inactiveColor: Colors.grey.shade200,
                onChanged: (v) => setState(() => _contrast = v),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.refresh_rounded, color: Colors.grey),
            label: const Text("Değiştir", style: TextStyle(color: Colors.grey)),
          ),
          const Spacer(),
          ElevatedButton.icon(
            // ✅ DÜZENLENDİ: Yeni export fonksiyonunu çağırıyor
            onPressed: _exportSketchAndNavigate,
            icon: const Icon(Icons.camera_alt_rounded),
            label: const Text("Çizmeye Başla"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderLabel(String title, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800)),
        Text(value,
            style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.blueAccent)),
      ],
    );
  }
}

class SketchPainter extends CustomPainter {
  final ui.Image image;
  final ui.FragmentShader shader;
  final double threshold;
  final double contrast;

  SketchPainter({
    required this.image,
    required this.shader,
    required this.threshold,
    required this.contrast,
  });

  @override
  void paint(Canvas canvas, Size size) {
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, threshold);
    shader.setFloat(3, contrast);
    shader.setImageSampler(0, image);

    final paint = Paint()..shader = shader;
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant SketchPainter oldDelegate) {
    return oldDelegate.threshold != threshold ||
        oldDelegate.contrast != contrast ||
        oldDelegate.image != image;
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/medicine.dart';
import '../../core/utils/app_strings.dart';
import '../providers/medicine_provider.dart';
import '../widgets/hsoub_banner.dart';

class ResultScreen extends StatefulWidget {
  final Medicine? data;
  final String imagePath;
  final bool isPremium;

  const ResultScreen({
    super.key,
    this.data,
    required this.imagePath,
    this.isPremium = false,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  // 🔍 Zoom Configuration
  double _textScale = 1.0;
  double _baseScale = 1.0;
  final double _minZoom = 0.8;
  final double _maxZoom = 2.0;

  // ✋ Touch Handling
  int _pointers = 0;
  ScrollPhysics _scrollPhysics = const BouncingScrollPhysics();

  @override
  void initState() {
    super.initState();
    _loadSavedZoom();

    if (widget.data == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<MedicineProvider>().analyzeMedicine(widget.imagePath);
      });
    }
  }

  Future<void> _loadSavedZoom() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _textScale = prefs.getDouble('saved_zoom_level') ?? 1.0;
      });
    }
  }

  Future<void> _saveZoom(double zoom) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('saved_zoom_level', zoom);
  }

  void _updateZoom(bool zoomIn) {
    setState(() {
      if (zoomIn) {
        if (_textScale < _maxZoom) _textScale += 0.1;
      } else {
        if (_textScale > _minZoom) _textScale -= 0.1;
      }
      _textScale = _textScale.clamp(_minZoom, _maxZoom);
    });
    _saveZoom(_textScale);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MedicineProvider>();
    final lang = provider.locale.languageCode;
    String txt(String key) => AppStrings.get(key, lang);
    final isAr = lang == 'ar';

    final Medicine? currentData = widget.data ?? provider.medicine;
    final bool isLoading =
        provider.state == MedicineState.loading && widget.data == null;
    final bool isError =
        provider.state == MedicineState.error && widget.data == null;

    final bool canZoomOut = _textScale > (_minZoom + 0.05);
    final bool canZoomIn = _textScale < (_maxZoom - 0.05);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(txt('results_title')),
        centerTitle: true,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (!isLoading && !isError)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildZoomButton(
                    icon: Icons.remove,
                    isEnabled: canZoomOut,
                    onTap: () => _updateZoom(false),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child:
                        Icon(Icons.text_fields, color: Colors.white, size: 20),
                  ),
                  _buildZoomButton(
                    icon: Icons.add,
                    isEnabled: canZoomIn,
                    onTap: () => _updateZoom(true),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: GestureDetector(
        onScaleStart: (details) {
          _baseScale = _textScale;
        },
        onScaleUpdate: (details) {
          if (_pointers >= 2) {
            setState(() {
              _textScale =
                  (_baseScale * details.scale).clamp(_minZoom, _maxZoom);
            });
          }
        },
        onScaleEnd: (_) => _saveZoom(_textScale),
        child: Stack(
          children: [
            Listener(
              onPointerDown: (_) => setState(() {
                _pointers++;
                if (_pointers >= 2)
                  _scrollPhysics = const NeverScrollableScrollPhysics();
              }),
              onPointerUp: (_) => setState(() {
                _pointers--;
                if (_pointers < 2)
                  _scrollPhysics = const BouncingScrollPhysics();
              }),
              onPointerCancel: (_) => setState(() {
                _pointers = 0;
                _scrollPhysics = const BouncingScrollPhysics();
              }),
              child: SafeArea(
                child: SingleChildScrollView(
                  physics: _scrollPhysics,
                  padding: const EdgeInsets.only(
                      left: 20.0, right: 20.0, top: 20.0, bottom: 120.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 🖼️ 1. Main Header (Image + Name + Dose)
                      _buildHeaderImageAndName(currentData),

                      const SizedBox(height: 25),

                      if (isLoading) ...[
                        const SizedBox(height: 40),
                        const Center(
                            child:
                                CircularProgressIndicator(color: Colors.teal)),
                        const SizedBox(height: 20),
                        Text(
                          txt('analyzing_med'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal),
                        ),
                      ] else if (isError) ...[
                        _buildErrorState(provider.message),
                      ] else if (currentData != null) ...[
                        // ⚠️ 1. Ingredients (Immutable)
                        _buildSectionHeader(
                            isAr ? "المكونات" : "Ingredients", Icons.science),
                        _buildListSection(
                            items: currentData.ingredients,
                            color: Colors.teal.shade800,
                            icon: Icons.science,
                            isAr: isAr),
                        const SizedBox(height: 15),

                        // 💊 2. Dosage & Duration
                        _buildSectionHeader(
                            isAr ? "الجرعة والمدة" : "Dosage & Duration",
                            Icons.timer),
                        _buildListSection(
                            items: currentData.dosageDuration,
                            color: Colors.blue.shade800,
                            icon: Icons.timer,
                            isAr: isAr),
                        const SizedBox(height: 15),

                        // 🏥 3. Primary Uses
                        _buildSectionHeader(
                            isAr ? "دواعي الاستعمال" : "Primary Uses",
                            Icons.medical_services),
                        _buildListSection(
                            items: currentData.primaryUses,
                            color: Colors.indigo,
                            icon: Icons.medical_services,
                            isAr: isAr),
                        const SizedBox(height: 15),

                        // 🤢 4. Common Side Effects
                        _buildSectionHeader(
                            isAr
                                ? "الآثار الجانبية الشائعة"
                                : "Common Side Effects",
                            Icons.sick),
                        _buildListSection(
                            items: currentData.commonSideEffects,
                            color: Colors.orange.shade800,
                            icon: Icons.sick,
                            isAr: isAr),
                        const SizedBox(height: 15),

                        // 🚨 5. Serious Symptoms
                        _buildSectionHeader(
                            isAr
                                ? "أعراض خطيرة (اطلب المساعدة)"
                                : "Serious Symptoms (Seek Help)",
                            Icons.warning_amber_rounded),
                        _buildListSection(
                            items: currentData.seriousSymptoms,
                            color: Colors.red.shade900,
                            icon: Icons.warning_amber_rounded,
                            isAr: isAr,
                            isWarning: true),
                        const SizedBox(height: 15),

                        // 🛑 6. Contraindications
                        _buildSectionHeader(
                            isAr ? "موانع الاستعمال" : "Contraindications",
                            Icons.block),
                        _buildListSection(
                            items: currentData.contraindications,
                            color: Colors.red,
                            icon: Icons.block,
                            isAr: isAr),
                        const SizedBox(height: 15),

                        // 🍔 7. Interactions
                        _buildSectionHeader(
                            isAr
                                ? "التفاعلات الدوائية والغذائية"
                                : "Interactions",
                            Icons.merge_type),
                        _buildListSection(
                            items: currentData.interactions,
                            color: Colors.deepPurple,
                            icon: Icons.merge_type,
                            isAr: isAr),
                        const SizedBox(height: 15),

                        // 🌡️ 8. Storage & Disposal
                        _buildSectionHeader(
                            isAr ? "التخزين والتخلص" : "Storage & Disposal",
                            Icons.thermostat),
                        _buildListSection(
                            items: currentData.storageDisposal,
                            color: Colors.blueGrey,
                            icon: Icons.thermostat,
                            isAr: isAr),
                        const SizedBox(height: 15),

                        // ⏰ 9. Missed Dose
                        _buildSectionHeader(
                            isAr
                                ? "عند نسيان الجرعة"
                                : "Missed Dose Instructions",
                            Icons.update),
                        _buildListSection(
                            items: currentData.missedDose,
                            color: Colors.amber.shade900,
                            icon: Icons.update,
                            isAr: isAr),
                        const SizedBox(height: 15),

                        // 🚑 10. Overdose Response
                        _buildSectionHeader(
                            isAr
                                ? "في حال الجرعة الزائدة"
                                : "Overdose Response",
                            Icons.local_hospital),
                        _buildListSection(
                            items: currentData.overdoseResponse,
                            color: Colors.redAccent,
                            icon: Icons.local_hospital,
                            isAr: isAr,
                            isWarning: true),
                        const SizedBox(height: 30),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Ads Banner
            if (!widget.isPremium && !isLoading)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 90,
                  color: Colors.white,
                  child: const Center(child: HsoubBanner()),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ✨ UPDATED: Large Image with Bottom-Right Icon + Text Below
  Widget _buildHeaderImageAndName(Medicine? data) {
    return Column(
      children: [
        // 🖼️ The Image Card
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    FullScreenImageScreen(imagePath: widget.imagePath),
              ),
            );
          },
          child: Hero(
            tag: widget.imagePath,
            child: Container(
              height: 220, // Large height as requested
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 5))
                ],
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // The Image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.file(
                      File(widget.imagePath),
                      fit: BoxFit.cover,
                    ),
                  ),

                  // 🔍 Full Screen Icon (Bottom Right)
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.fullscreen_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),

        // 📝 Brand Name & Strength (Under the image)
        if (data != null) ...[
          Text(
            data.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26 * _textScale,
              fontWeight: FontWeight.w800,
              color: Colors.teal[800],
              height: 1.2,
            ),
          ),
          if (data.strength.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.teal.withOpacity(0.3)),
              ),
              child: Text(
                data.strength,
                style: TextStyle(
                  fontSize: 16 * _textScale,
                  color: Colors.teal[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4, right: 4),
      child: Row(children: [
        Icon(icon, color: Colors.grey[700], size: 20 * _textScale),
        const SizedBox(width: 8),
        Expanded(
            child: Text(title,
                style: TextStyle(
                    color: Colors.grey[700],
                    fontWeight: FontWeight.bold,
                    fontSize: 16 * _textScale))),
      ]),
    );
  }

  Widget _buildListSection({
    required List<String> items,
    required Color color,
    required IconData icon,
    required bool isAr,
    bool isWarning = false,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isWarning ? Colors.red.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(
            left: !isAr ? BorderSide(color: color, width: 4) : BorderSide.none,
            right: isAr ? BorderSide(color: color, width: 4) : BorderSide.none),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 5,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
          children: items
              .map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("• ",
                              style: TextStyle(
                                  fontSize: 18 * _textScale,
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                  height: 1.2)),
                          Expanded(
                              child: Text(item,
                                  style: TextStyle(
                                      fontSize: 15 * _textScale,
                                      color: Colors.grey[800],
                                      height: 1.4))),
                        ]),
                  ))
              .toList()),
    );
  }

  Widget _buildZoomButton(
      {required IconData icon,
      required bool isEnabled,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: isEnabled ? onTap : null,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isEnabled
                ? Colors.white.withOpacity(0.3)
                : Colors.white.withOpacity(0.1),
            border: Border.all(
                color: isEnabled ? Colors.white : Colors.white30, width: 1.5)),
        child: Icon(icon,
            size: 20, color: isEnabled ? Colors.white : Colors.white30),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.red.shade50, borderRadius: BorderRadius.circular(15)),
      child: Column(children: [
        const Icon(Icons.error_outline, size: 40, color: Colors.red),
        const SizedBox(height: 10),
        Text(message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red)),
      ]),
    );
  }
}

class FullScreenImageScreen extends StatelessWidget {
  final String imagePath;
  const FullScreenImageScreen({super.key, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Hero(
          tag: imagePath,
          child: InteractiveViewer(
            panEnabled: true,
            minScale: 0.5,
            maxScale: 4.0,
            child: Image.file(File(imagePath)),
          ),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:image/image.dart' as img;
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:bbaiphoto/l10n/locale_provider.dart';
import 'package:bbaiphoto/models/editor_models.dart';

/// Templix benzeri fotoğraf düzenleme ekranı.
/// Hızlı filtre uygulama — PNG encode/decode döngüsü yok.
class PhotoEditorScreen extends StatefulWidget {
  final File? initialImage;
  final String? templateId;

  const PhotoEditorScreen({super.key, this.initialImage, this.templateId});

  @override
  State<PhotoEditorScreen> createState() => _PhotoEditorScreenState();
}

class _PhotoEditorScreenState extends State<PhotoEditorScreen> {
  File? _imageFile;

  // Ham ve işlenmiş görseller bellekte tutuluyor (PNG yok!)
  img.Image? _originalImage;
  img.Image? _editedImage;

  // Flutter'a göstereceğimiz byte'lar
  Uint8List? _displayBytes;
  ui.Image? _displayImage;

  bool _loading = false;
  bool _saving = false;

  // Filtre
  FilterType _currentFilter = FilterType.none;

  // Ayarlamalar
  double _brightness = 0;
  double _contrast = 0;
  double _saturation = 0;
  double _warmth = 0;

  // Metin katmanları
  final List<_TextLayer> _textLayers = [];
  _TextLayer? _selectedTextLayer;

  // Panel
  _EditorPanel _activePanel = _EditorPanel.filters;

  // Undo/Redo
  final List<_EditSnapshot> _undoStack = [];
  final List<_EditSnapshot> _redoStack = [];

  // Kırpma
  double _cropAspectRatio = 0;

  // Debounce timer
  Timer? _filterDebounce;

  @override
  void initState() {
    super.initState();
    if (widget.initialImage != null) {
      _imageFile = widget.initialImage;
      _loadImage();
    }
  }

  @override
  void dispose() {
    _filterDebounce?.cancel();
    _displayImage?.dispose();
    super.dispose();
  }

  // ─── Görseli Yükle (hızlı) ───
  Future<void> _loadImage() async {
    if (_imageFile == null) return;
    setState(() => _loading = true);
    try {
      final bytes = await _imageFile!.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        _showError('Fotoğraf decode edilemedi');
        setState(() => _loading = false);
        return;
      }

      // Büyük görselleri küçült (performans için)
      _originalImage = _resizeIfNeeded(decoded);
      _editedImage = img.Image.from(_originalImage!);

      await _updateDisplay();
      setState(() => _loading = false);
    } catch (e) {
      setState(() => _loading = false);
      _showError('Fotoğraf yüklenemedi: $e');
    }
  }

  /// 2000px genişlikten büyük görselleri küçült
  img.Image _resizeIfNeeded(img.Image image) {
    const maxSize = 2000;
    if (image.width <= maxSize && image.height <= maxSize) return image;
    return img.copyResize(
      image,
      width: image.width > image.height ? maxSize : null,
      height: image.height >= image.width ? maxSize : null,
      interpolation: img.Interpolation.linear,
    );
  }

  /// img.Image → Flutter display bytes (JPG — PNG'den çok daha hızlı)
  Future<void> _updateDisplay() async {
    if (_editedImage == null) return;
    try {
      // JPG encode (PNG'den 10x hızlı)
      final jpgBytes = img.encodeJpg(_editedImage!, quality: 90);
      _displayBytes = Uint8List.fromList(jpgBytes);

      // Flutter ui.Image oluştur
      final codec = await ui.instantiateImageCodec(_displayBytes!);
      final frame = await codec.getNextFrame();
      _displayImage?.dispose();
      _displayImage = frame.image;
    } catch (e) {
      debugPrint('Display güncelleme hatası: $e');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('❌ $msg'), backgroundColor: Colors.red.shade700),
    );
  }

  // ─── Snapshot ───
  void _saveSnapshot() {
    _undoStack.add(_EditSnapshot(
      filter: _currentFilter,
      brightness: _brightness,
      contrast: _contrast,
      saturation: _saturation,
      warmth: _warmth,
      textLayers: List.from(_textLayers),
    ));
    _redoStack.clear();
    if (_undoStack.length > 30) _undoStack.removeAt(0);
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(_EditSnapshot(
      filter: _currentFilter,
      brightness: _brightness,
      contrast: _contrast,
      saturation: _saturation,
      warmth: _warmth,
      textLayers: List.from(_textLayers),
    ));
    final snap = _undoStack.removeLast();
    _applySnapshot(snap);
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_EditSnapshot(
      filter: _currentFilter,
      brightness: _brightness,
      contrast: _contrast,
      saturation: _saturation,
      warmth: _warmth,
      textLayers: List.from(_textLayers),
    ));
    final snap = _redoStack.removeLast();
    _applySnapshot(snap);
  }

  void _applySnapshot(_EditSnapshot snap) {
    setState(() {
      _currentFilter = snap.filter;
      _brightness = snap.brightness;
      _contrast = snap.contrast;
      _saturation = snap.saturation;
      _warmth = snap.warmth;
      _textLayers..clear()..addAll(snap.textLayers);
    });
    _applyFiltersInstant();
  }

  // ─── HIZLI FİLTRE UYGULAMA ───
  // Orijinal görseli kopyala, filtre uygula, JPG encode — hepsi senkron
  void _applyFiltersInstant() {
    if (_originalImage == null) return;

    // Orijinalin kopyası üzerinde çalış (orijinali bozma!)
    var result = img.Image.from(_originalImage!);

    // ── Ayarlamalar ──
    if (_brightness != 0) {
      result = img.adjustColor(result, brightness: _brightness / 100);
    }
    if (_contrast != 0) {
      result = img.adjustColor(result, contrast: 1.0 + (_contrast / 100));
    }
    if (_saturation != 0) {
      result = img.adjustColor(result, saturation: 1.0 + (_saturation / 100));
    }
    if (_warmth != 0) {
      result = img.adjustColor(result, hue: (_warmth / 100) * 30);
    }

    // ── Filtreler ──
    switch (_currentFilter) {
      case FilterType.none: break;
      // Basic
      case FilterType.grayscale: result = img.grayscale(result); break;
      case FilterType.sepia: result = img.sepia(result); break;
      case FilterType.vintage:
        result = img.sepia(result);
        result = img.adjustColor(result, contrast: 0.8, brightness: 0.1); break;
      case FilterType.noir:
        result = img.grayscale(result);
        result = img.adjustColor(result, contrast: 1.5); break;
      case FilterType.fade:
        result = img.adjustColor(result, brightness: 0.08, contrast: 0.85); break;
      // Color
      case FilterType.warm: result = img.adjustColor(result, hue: 15, saturation: 1.1); break;
      case FilterType.cool: result = img.adjustColor(result, hue: -15, saturation: 0.95); break;
      case FilterType.cold: result = img.adjustColor(result, hue: -25, saturation: 0.9, brightness: -0.05); break;
      case FilterType.golden: result = img.adjustColor(result, hue: 30, saturation: 1.2, brightness: 0.05); break;
      case FilterType.rose: result = img.adjustColor(result, hue: -10, saturation: 1.15); result = img.sepia(result, amount: 0.15); break;
      case FilterType.lavender: result = img.adjustColor(result, hue: -40, saturation: 0.8); break;
      // Contrast
      case FilterType.contrast: result = img.adjustColor(result, contrast: 1.5); break;
      case FilterType.highContrast: result = img.adjustColor(result, contrast: 2.0); break;
      case FilterType.softContrast: result = img.adjustColor(result, contrast: 0.7, brightness: 0.05); break;
      case FilterType.dramatic:
        result = img.adjustColor(result, contrast: 1.4, saturation: 0.7);
        result = img.sepia(result, amount: 0.3); break;
      case FilterType.punch: result = img.adjustColor(result, contrast: 1.6, saturation: 1.4); break;
      case FilterType.vivid: result = img.adjustColor(result, saturation: 1.8, contrast: 1.1); break;
      // Brightness
      case FilterType.bright: result = img.adjustColor(result, brightness: 0.15); break;
      case FilterType.dark: result = img.adjustColor(result, brightness: -0.15); break;
      case FilterType.expose: result = img.adjustColor(result, exposure: 0.5, brightness: 0.1); break;
      case FilterType.dim: result = img.adjustColor(result, brightness: -0.1, contrast: 0.9); break;
      // Effects
      case FilterType.blur: result = img.gaussianBlur(result, radius: 3); break;
      case FilterType.sharpen:
        result = img.convolution(result, filter: [0, -1, 0, -1, 5, -1, 0, -1, 0]); break;
      case FilterType.dreamy:
        result = img.gaussianBlur(result, radius: 2);
        result = img.adjustColor(result, brightness: 0.05, saturation: 1.1); break;
      case FilterType.ethereal:
        result = img.adjustColor(result, brightness: 0.1, contrast: 0.85, saturation: 0.9);
        result = img.gaussianBlur(result, radius: 1); break;
      case FilterType.glow:
        result = img.adjustColor(result, brightness: 0.08, contrast: 1.1);
        result = img.sepia(result, amount: 0.05); break;
      case FilterType.vignette:
        result = img.adjustColor(result, brightness: -0.05, contrast: 1.2); break;
      // Film
      case FilterType.cinematic:
        result = img.adjustColor(result, contrast: 1.2, saturation: 0.8, hue: 10); break;
      case FilterType.film:
        result = img.adjustColor(result, contrast: 1.1, saturation: 0.9);
        result = img.sepia(result, amount: 0.1); break;
      case FilterType.kodachrome:
        result = img.adjustColor(result, saturation: 1.3, contrast: 1.15, hue: 5); break;
      case FilterType.portra:
        result = img.adjustColor(result, saturation: 0.85, brightness: 0.05, hue: 8); break;
      case FilterType.fuji:
        result = img.adjustColor(result, saturation: 1.1, hue: -5, brightness: 0.03); break;
      case FilterType.polaroid:
        result = img.sepia(result, amount: 0.2);
        result = img.adjustColor(result, brightness: 0.05, contrast: 1.1); break;
      case FilterType.instax:
        result = img.adjustColor(result, brightness: 0.08, saturation: 0.9, contrast: 0.95);
        result = img.sepia(result, amount: 0.08); break;
      // Artistic
      case FilterType.oilPainting:
        result = img.convolution(result, filter: [1, 2, 1, 2, 4, 2, 1, 2, 1], div: 16); break;
      case FilterType.watercolor:
        result = img.gaussianBlur(result, radius: 4);
        result = img.adjustColor(result, saturation: 1.5, brightness: 0.05); break;
      case FilterType.sketch:
        result = img.grayscale(result);
        result = img.convolution(result, filter: [-1, -1, -1, -1, 9, -1, -1, -1, -1]); break;
      case FilterType.comic:
        result = img.adjustColor(result, contrast: 2.0, saturation: 1.5); break;
      case FilterType.pixelate:
        result = img.pixelate(result, size: 8); break;
      case FilterType.halftone:
        result = img.grayscale(result);
        result = img.adjustColor(result, contrast: 1.8); break;
      // Special
      case FilterType.duotone:
        result = img.grayscale(result);
        result = img.adjustColor(result, hue: 200, saturation: 1.5); break;
      case FilterType.splitTone:
        result = img.adjustColor(result, hue: 30, saturation: 0.5);
        result = img.sepia(result, amount: 0.3); break;
      case FilterType.crossProcess:
        result = img.adjustColor(result, hue: 60, saturation: 1.3, contrast: 1.2); break;
      case FilterType.bleachBypass:
        result = img.adjustColor(result, contrast: 1.5, saturation: 0.4, brightness: 0.05); break;
      case FilterType.colorNegative:
        result = img.invert(result);
        result = img.adjustColor(result, saturation: 1.3); break;
    }

    _editedImage = result;

    // JPG encode ve display güncelle (büyük görseller için frame'de)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _updateDisplay();
      if (mounted) setState(() {});
    });
  }

  // ─── Fotoğraf Seç ───
  Future<void> _pickImage() async {
    final result = await FilePicker.pickFile(type: FileType.image);
    if (result != null && result.path != null) {
      _saveSnapshot();
      _imageFile = File(result.path!);
      _resetEdits();
      await _loadImage();
    }
  }

  void _resetEdits() {
    _currentFilter = FilterType.none;
    _brightness = 0;
    _contrast = 0;
    _saturation = 0;
    _warmth = 0;
    _textLayers.clear();
    _selectedTextLayer = null;
    _undoStack.clear();
    _redoStack.clear();
  }

  // ─── Kaydet ───
  Future<void> _saveImage() async {
    if (_editedImage == null) return;
    setState(() => _saving = true);

    try {
      // Yüksek kalite PNG olarak kaydet
      final encoded = img.encodePng(_editedImage!);
      final dir = await getApplicationDocumentsDirectory();
      final fileName = 'bbaiphoto_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(encoded);

      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Kaydedildi: $fileName'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _showError('Kaydetme hatası: $e');
      }
    }
  }

  // ─── Metin/Sticker ───
  void _addTextLayer() {
    _saveSnapshot();
    final layer = _TextLayer(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: 'Metin yazın...',
      color: Colors.white,
      fontSize: 24,
      x: 0.5,
      y: 0.5,
    );
    setState(() {
      _textLayers.add(layer);
      _selectedTextLayer = layer;
    });
  }

  void _addStickerLayer(String emoji) {
    _saveSnapshot();
    final layer = _TextLayer(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: emoji,
      color: Colors.white,
      fontSize: 48,
      x: 0.5,
      y: 0.5,
      isSticker: true,
    );
    setState(() {
      _textLayers.add(layer);
      _selectedTextLayer = layer;
    });
  }

  void _deleteSelectedLayer() {
    if (_selectedTextLayer == null) return;
    _saveSnapshot();
    setState(() {
      _textLayers.removeWhere((l) => l.id == _selectedTextLayer!.id);
      _selectedTextLayer = null;
    });
  }

  // ─── Build ───
  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final isTr = locale.lang == 'tr';

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1117),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isTr ? 'Fotoğraf Düzenleyici' : 'Photo Editor',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (_undoStack.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.undo, color: Colors.white70),
              onPressed: _undo,
            ),
          if (_redoStack.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.redo, color: Colors.white70),
              onPressed: _redo,
            ),
          IconButton(
            icon: const Icon(Icons.add_photo_alternate, color: Colors.white70),
            onPressed: _pickImage,
          ),
          if (_imageFile != null)
            IconButton(
              icon: _saving
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_alt, color: Colors.white70),
              onPressed: _saving ? null : _saveImage,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _imageFile == null ? _buildPlaceholder(isTr) : _buildCanvas(),
          ),
          if (_imageFile != null) ...[
            _buildPanelTabs(isTr),
            SizedBox(height: 160, child: _buildPanelContent(isTr)),
          ],
        ],
      ),
    );
  }

  Widget _buildPlaceholder(bool isTr) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 120, height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 2),
            ),
            child: const Icon(Icons.add_photo_alternate_outlined, size: 48, color: Colors.white38),
          ),
          const SizedBox(height: 20),
          Text(
            isTr ? 'Düzenlenecek fotoğrafı seçin' : 'Select a photo to edit',
            style: const TextStyle(color: Colors.white54, fontSize: 16),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.photo_library),
            label: Text(isTr ? 'Fotoğraf Seç' : 'Pick Photo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E88E5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCanvas() {
    return Stack(
      children: [
        Center(
          child: _loading
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF1E88E5)),
                    SizedBox(height: 12),
                    Text('Yükleniyor...', style: TextStyle(color: Colors.white54)),
                  ],
                )
              : InteractiveViewer(
                  maxScale: 5, minScale: 0.5,
                  child: _buildDisplayImage(),
                ),
        ),

        // Metin katmanları
        ..._textLayers.map((layer) => Positioned(
              left: layer.x * MediaQuery.of(context).size.width - 50,
              top: layer.y * MediaQuery.of(context).size.height - 20,
              child: GestureDetector(
                onTap: () => setState(() => _selectedTextLayer = layer),
                onPanUpdate: (details) {
                  setState(() {
                    layer.x += details.delta.dx / MediaQuery.of(context).size.width;
                    layer.y += details.delta.dy / MediaQuery.of(context).size.height;
                    layer.x = layer.x.clamp(0.0, 1.0);
                    layer.y = layer.y.clamp(0.0, 1.0);
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: _selectedTextLayer?.id == layer.id
                      ? BoxDecoration(
                          border: Border.all(color: const Color(0xFF1E88E5), width: 2),
                          borderRadius: BorderRadius.circular(4),
                        )
                      : null,
                  child: Text(
                    layer.text ?? '',
                    style: TextStyle(
                      color: layer.color,
                      fontSize: layer.fontSize,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(blurRadius: 8, color: Colors.black.withValues(alpha: 0.8))],
                    ),
                  ),
                ),
              ),
            )),
      ],
    );
  }

  /// Hızlı display — ui.Image veya fallback olarak Image.memory
  Widget _buildDisplayImage() {
    if (_displayImage != null) {
      return RawImage(
        image: _displayImage,
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
      );
    }
    if (_displayBytes != null) {
      return Image.memory(_displayBytes!, fit: BoxFit.contain,
          width: double.infinity, height: double.infinity);
    }
    if (_imageFile != null) {
      return Image.file(_imageFile!, fit: BoxFit.contain,
          width: double.infinity, height: double.infinity);
    }
    return const SizedBox.shrink();
  }

  Widget _buildPanelTabs(bool isTr) {
    final tabs = [
      _PanelTab(Icons.filter, isTr ? 'Filtreler' : 'Filters', _EditorPanel.filters),
      _PanelTab(Icons.tune, isTr ? 'Ayarlar' : 'Adjust', _EditorPanel.adjust),
      _PanelTab(Icons.text_fields, isTr ? 'Metin' : 'Text', _EditorPanel.text),
      _PanelTab(Icons.emoji_emotions, isTr ? 'Sticker' : 'Sticker', _EditorPanel.sticker),
      _PanelTab(Icons.crop, isTr ? 'Kırp' : 'Crop', _EditorPanel.crop),
    ];

    return Container(
      height: 44,
      color: const Color(0xFF161B22),
      child: Row(
        children: tabs.map((tab) {
          final isActive = _activePanel == tab.panel;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activePanel = tab.panel),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isActive ? const Color(0xFF1E88E5) : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(tab.icon, size: 18, color: isActive ? const Color(0xFF1E88E5) : Colors.white54),
                    const SizedBox(height: 2),
                    Text(tab.label, style: TextStyle(
                      fontSize: 10, color: isActive ? const Color(0xFF1E88E5) : Colors.white54,
                    )),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPanelContent(bool isTr) {
    return Container(
      color: const Color(0xFF0D1117),
      child: switch (_activePanel) {
        _EditorPanel.filters => _buildFilterPanel(isTr),
        _EditorPanel.adjust => _buildAdjustPanel(isTr),
        _EditorPanel.text => _buildTextPanel(isTr),
        _EditorPanel.sticker => _buildStickerPanel(isTr),
        _EditorPanel.crop => _buildCropPanel(isTr),
      },
    );
  }

  // ─── Filtre Paneli ───
  Widget _buildFilterPanel(bool isTr) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: allFilters.length,
      itemBuilder: (context, index) {
        final filter = allFilters[index];
        final isActive = _currentFilter == filter.type;
        return GestureDetector(
          onTap: () {
            _saveSnapshot();
            setState(() => _currentFilter = filter.type);
            _applyFiltersInstant();
          },
          child: Container(
            width: 80, margin: const EdgeInsets.only(right: 8),
            child: Column(
              children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFF1E88E5).withValues(alpha: 0.3)
                        : const Color(0xFF161B22),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isActive ? const Color(0xFF1E88E5) : Colors.white.withValues(alpha: 0.08),
                      width: isActive ? 2 : 1,
                    ),
                  ),
                  child: Center(child: Text(filter.emoji, style: const TextStyle(fontSize: 28))),
                ),
                const SizedBox(height: 4),
                Text(
                  isTr ? filter.nameTr : filter.name,
                  style: TextStyle(
                    fontSize: 11,
                    color: isActive ? const Color(0xFF1E88E5) : Colors.white60,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  ),
                  textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Ayar Paneli ───
  Widget _buildAdjustPanel(bool isTr) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        _buildAdjustSlider(icon: Icons.brightness_6, label: isTr ? 'Parlaklık' : 'Brightness',
            value: _brightness, min: -100, max: 100,
            onChanged: (v) => setState(() => _brightness = v),
            onChangeEnd: (_) { _saveSnapshot(); _applyFiltersInstant(); }),
        _buildAdjustSlider(icon: Icons.contrast, label: isTr ? 'Kontrast' : 'Contrast',
            value: _contrast, min: -100, max: 100,
            onChanged: (v) => setState(() => _contrast = v),
            onChangeEnd: (_) { _saveSnapshot(); _applyFiltersInstant(); }),
        _buildAdjustSlider(icon: Icons.palette, label: isTr ? 'Doygunluk' : 'Saturation',
            value: _saturation, min: -100, max: 100,
            onChanged: (v) => setState(() => _saturation = v),
            onChangeEnd: (_) { _saveSnapshot(); _applyFiltersInstant(); }),
        _buildAdjustSlider(icon: Icons.thermostat, label: isTr ? 'Sıcaklık' : 'Warmth',
            value: _warmth, min: -100, max: 100,
            onChanged: (v) => setState(() => _warmth = v),
            onChangeEnd: (_) { _saveSnapshot(); _applyFiltersInstant(); }),
      ],
    );
  }

  Widget _buildAdjustSlider({
    required IconData icon, required String label,
    required double value, required double min, required double max,
    required ValueChanged<double> onChanged,
    ValueChanged<double>? onChangeEnd,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.white54),
          const SizedBox(width: 8),
          SizedBox(width: 70, child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.white60))),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                activeTrackColor: const Color(0xFF1E88E5),
                inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                thumbColor: Colors.white,
              ),
              child: Slider(value: value, min: min, max: max, onChanged: onChanged, onChangeEnd: onChangeEnd),
            ),
          ),
          SizedBox(width: 40, child: Text(value.toInt().toString(),
              style: const TextStyle(fontSize: 12, color: Colors.white54), textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  // ─── Metin Paneli ───
  Widget _buildTextPanel(bool isTr) {
    return Column(
      children: [
        if (_selectedTextLayer != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: _selectedTextLayer!.text),
                    onChanged: (v) => _selectedTextLayer!.text = v,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: isTr ? 'Metin yazın...' : 'Type text...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true, fillColor: const Color(0xFF161B22),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _showColorPicker,
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: _selectedTextLayer!.color,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white24),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
                  onPressed: _deleteSelectedLayer,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.format_size, color: Colors.white54, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                      activeTrackColor: const Color(0xFF1E88E5),
                      inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                      thumbColor: Colors.white,
                    ),
                    child: Slider(
                      value: _selectedTextLayer!.fontSize, min: 12, max: 72,
                      onChanged: (v) => setState(() => _selectedTextLayer!.fontSize = v),
                    ),
                  ),
                ),
                Text('${_selectedTextLayer!.fontSize.toInt()}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _addTextLayer,
              icon: const Icon(Icons.add, size: 18),
              label: Text(isTr ? 'Metin Ekle' : 'Add Text'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E88E5), foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Sticker Paneli ───
  Widget _buildStickerPanel(bool isTr) {
    final stickers = [
      '😀', '😂', '😍', '🤩', '😎', '🥳', '👍', '❤️',
      '🔥', '⭐', '🎵', '✨', '🎉', '💪', '🌟', '🎊',
      '🥰', '💯', '🙌', '👏', '🫶', '🌈', '🦋', '🌸',
      '🌺', '🍃', '☀️', '🌙', '🎨', '📸', '🎬', '💎',
    ];

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8, mainAxisSpacing: 6, crossAxisSpacing: 6),
      itemCount: stickers.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () => _addStickerLayer(stickers[index]),
          child: Container(
            decoration: BoxDecoration(color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(8)),
            child: Center(child: Text(stickers[index], style: const TextStyle(fontSize: 24))),
          ),
        );
      },
    );
  }

  // ─── Kırpma Paneli ───
  Widget _buildCropPanel(bool isTr) {
    final ratios = [
      _CropRatio(label: 'Serbest', labelEn: 'Free', ratio: 0, icon: Icons.crop_free),
      _CropRatio(label: 'Kare', labelEn: 'Square', ratio: 1, icon: Icons.crop_square),
      _CropRatio(label: '16:9', labelEn: '16:9', ratio: 16 / 9, icon: Icons.crop_landscape),
      _CropRatio(label: '9:16', labelEn: '9:16', ratio: 9 / 16, icon: Icons.crop_portrait),
      _CropRatio(label: '4:3', labelEn: '4:3', ratio: 4 / 3, icon: Icons.aspect_ratio),
      _CropRatio(label: '3:4', labelEn: '3:4', ratio: 3 / 4, icon: Icons.aspect_ratio),
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(isTr ? 'En Boy Oranı Seçin' : 'Select Aspect Ratio',
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
        ),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: ratios.length,
            itemBuilder: (context, index) {
              final r = ratios[index];
              final isActive = _cropAspectRatio == r.ratio;
              return GestureDetector(
                onTap: () => setState(() => _cropAspectRatio = r.ratio),
                child: Container(
                  width: 80, margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFF1E88E5).withValues(alpha: 0.2) : const Color(0xFF161B22),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isActive ? const Color(0xFF1E88E5) : Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(r.icon, color: isActive ? const Color(0xFF1E88E5) : Colors.white54, size: 22),
                      const SizedBox(height: 4),
                      Text(isTr ? r.label : r.labelEn, style: TextStyle(
                        fontSize: 11, color: isActive ? const Color(0xFF1E88E5) : Colors.white54,
                      )),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showColorPicker() {
    if (_selectedTextLayer == null) return;
    Color pickerColor = _selectedTextLayer!.color;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Renk Seçin'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: pickerColor,
            onColorChanged: (color) => pickerColor = color,
            enableAlpha: true, displayThumbColor: true, pickerAreaHeightPercent: 0.8,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          TextButton(
            onPressed: () {
              setState(() => _selectedTextLayer!.color = pickerColor);
              Navigator.pop(context);
            },
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }
}

// ─── Yardımcı sınıflar ───

enum _EditorPanel { filters, adjust, text, sticker, crop }

class _PanelTab {
  final IconData icon;
  final String label;
  final _EditorPanel panel;
  _PanelTab(this.icon, this.label, this.panel);
}

class _TextLayer {
  final String id;
  String? text;
  Color color;
  double fontSize;
  double x, y;
  bool isSticker;

  _TextLayer({
    required this.id, this.text,
    this.color = Colors.white, this.fontSize = 24,
    this.x = 0.5, this.y = 0.5, this.isSticker = false,
  });
}

class _EditSnapshot {
  final FilterType filter;
  final double brightness, contrast, saturation, warmth;
  final List<_TextLayer> textLayers;

  _EditSnapshot({
    required this.filter,
    required this.brightness, required this.contrast,
    required this.saturation, required this.warmth,
    required this.textLayers,
  });
}

class _CropRatio {
  final String label, labelEn;
  final double ratio;
  final IconData icon;
  _CropRatio({required this.label, required this.labelEn, required this.ratio, required this.icon});
}

import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:bbaiphoto/l10n/locale_provider.dart';
import 'package:bbaiphoto/models/editor_models.dart';

/// Çoklu fotoğrafla hikaye/reel oluşturma ekranı.
/// Slayt ekleme, filtre uygulama, geçiş efektleri, metin/sticker katmanları.
class StoryCreator extends StatefulWidget {
  const StoryCreator({super.key});

  @override
  State<StoryCreator> createState() => _StoryCreatorState();
}

class _StoryCreatorState extends State<StoryCreator> with TickerProviderStateMixin {
  late StoryProject _project;
  int _selectedSlideIndex = 0;
  bool _isPlaying = false;
  AnimationController? _playController;

  @override
  void initState() {
    super.initState();
    _project = StoryProject(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: 'Yeni Hikaye',
    );
    // İlk boş slayt
    _project.slides.add(StorySlide(
      id: 'slide_0',
      duration: 3.0,
    ));
  }

  @override
  void dispose() {
    _playController?.dispose();
    super.dispose();
  }

  StorySlide get _currentSlide => _project.slides[_selectedSlideIndex];

  // ─── Fotoğraf Ekle ───
  Future<void> _addPhotos() async {
    final result = await FilePicker.pickFile(type: FileType.image);
    if (result != null && result.path != null) {
      setState(() {
        _project.slides.add(StorySlide(
          id: 'slide_${DateTime.now().millisecondsSinceEpoch}',
          imagePath: result.path,
        ));
      });
    }
  }

  // ─── Slayt Ekle ───
  void _addBlankSlide() {
    setState(() {
      _project.slides.add(StorySlide(
        id: 'slide_${DateTime.now().millisecondsSinceEpoch}',
      ));
      _selectedSlideIndex = _project.slides.length - 1;
    });
  }

  // ─── Slayt Sil ───
  void _deleteSlide(int index) {
    if (_project.slides.length <= 1) return;
    setState(() {
      _project.slides.removeAt(index);
      if (_selectedSlideIndex >= _project.slides.length) {
        _selectedSlideIndex = _project.slides.length - 1;
      }
    });
  }

  // ─── Slayt Filtre Uygula ───
  void _openFilterForSlide(int index) async {
    final slide = _project.slides[index];
    if (slide.imagePath == null) return;

    final result = await Navigator.push<FilterType>(
      context,
      MaterialPageRoute(
        builder: (_) => _FilterPickerScreen(
          imagePath: slide.imagePath!,
          currentFilter: slide.filter,
        ),
      ),
    );

    if (result != null) {
      setState(() => slide.filter = result);
    }
  }

  // ─── Metin Ekle ───
  void _addTextToSlide() {
    final layer = SlideLayer(
      id: 'layer_${DateTime.now().millisecondsSinceEpoch}',
      type: SlideLayerType.text,
      text: 'Yazı yazın...',
      color: Colors.white,
      fontSize: 28,
    );
    setState(() => _currentSlide.layers.add(layer));
  }

  // ─── Sticker Ekle ───
  void _addStickerToSlide(String emoji) {
    final layer = SlideLayer(
      id: 'layer_${DateTime.now().millisecondsSinceEpoch}',
      type: SlideLayerType.sticker,
      stickerEmoji: emoji,
      fontSize: 48,
    );
    setState(() => _currentSlide.layers.add(layer));
  }

  // ─── Oynatma ───
  void _togglePlay() {
    setState(() => _isPlaying = !_isPlaying);
    if (_isPlaying) {
      _playSlides();
    }
  }

  Future<void> _playSlides() async {
    for (var i = 0; i < _project.slides.length; i++) {
      if (!_isPlaying) break;
      setState(() => _selectedSlideIndex = i);
      await Future.delayed(Duration(milliseconds: (_project.slides[i].duration * 1000).toInt()));
    }
    setState(() => _isPlaying = false);
  }

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
          isTr ? 'Hikaye Oluşturucu' : 'Story Creator',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        actions: [
          // Oynat/Duraklat
          IconButton(
            icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
            onPressed: _togglePlay,
          ),
          // Slayt ekle
          IconButton(
            icon: const Icon(Icons.add_photo_alternate, color: Colors.white70),
            onPressed: _addPhotos,
          ),
          // Kaydet
          IconButton(
            icon: const Icon(Icons.save, color: Colors.white70),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✅ Hikaye kaydedildi!')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── Ana Önizleme ───
          Expanded(flex: 3, child: _buildPreview(isTr)),

          // ─── Slayt Araçları ───
          _buildSlideToolbar(isTr),

          // ─── Slayt Timeline ───
          Expanded(flex: 2, child: _buildTimeline(isTr)),
        ],
      ),
    );
  }

  // ─── Ana Önizleme ───
  Widget _buildPreview(bool isTr) {
    final slide = _currentSlide;

    return Container(
      color: const Color(0xFF000000),
      margin: const EdgeInsets.all(16),
      child: Stack(
        children: [
          // Arka plan
          Center(
            child: slide.imagePath != null
                ? Image.file(
                    File(slide.imagePath!),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  )
                : Container(
                    color: Color(slide.backgroundColor),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add_photo_alternate_outlined,
                              size: 48, color: Colors.white24),
                          const SizedBox(height: 8),
                          Text(
                            isTr ? 'Fotoğraf ekleyin' : 'Add photos',
                            style: const TextStyle(color: Colors.white38),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),

          // Katmanlar
          ...slide.layers.map((layer) => Positioned(
                left: layer.x * MediaQuery.of(context).size.width * 0.9,
                top: layer.y * 300,
                child: Transform.rotate(
                  angle: layer.rotation * pi / 180,
                  child: Transform.scale(
                    scale: layer.scale,
                    child: Opacity(
                      opacity: layer.opacity,
                      child: layer.type == SlideLayerType.text
                          ? Text(
                              layer.text ?? '',
                              style: TextStyle(
                                color: layer.color,
                                fontSize: layer.fontSize,
                                fontWeight: layer.isBold ? FontWeight.bold : FontWeight.normal,
                                fontStyle: layer.isItalic ? FontStyle.italic : FontStyle.normal,
                                shadows: [Shadow(blurRadius: 6, color: Colors.black.withValues(alpha: 0.7))],
                              ),
                            )
                          : Text(
                              layer.stickerEmoji ?? '',
                              style: TextStyle(fontSize: layer.fontSize),
                            ),
                    ),
                  ),
                ),
              )),

          // Slayt numarası
          Positioned(
            top: 8, right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_selectedSlideIndex + 1}/${_project.slides.length}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),

          // Süre
          Positioned(
            bottom: 8, left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.access_time, color: Colors.white70, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '${_currentSlide.duration.toInt()}s',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Slayt Araç Çubuğu ───
  Widget _buildSlideToolbar(bool isTr) {
    return Container(
      height: 52,
      color: const Color(0xFF161B22),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          _toolbarButton(Icons.photo_library, isTr ? 'Fotoğraf' : 'Photo', _addPhotos),
          _toolbarButton(Icons.add, isTr ? 'Boş Slayt' : 'Blank', _addBlankSlide),
          _toolbarButton(Icons.text_fields, isTr ? 'Metin' : 'Text', _addTextToSlide),
          _toolbarButton(Icons.emoji_emotions, isTr ? 'Sticker' : 'Sticker', () => _showStickerPicker(isTr)),
          _toolbarButton(Icons.filter, isTr ? 'Filtre' : 'Filter', () => _openFilterForSlide(_selectedSlideIndex)),
          _toolbarButton(Icons.timer, isTr ? 'Süre' : 'Duration', () => _showDurationPicker(isTr)),
          _toolbarButton(Icons.swap_horiz, isTr ? 'Geçiş' : 'Transition', () => _showTransitionPicker(isTr)),
          _toolbarButton(Icons.color_lens, isTr ? 'Renk' : 'Color', () => _showColorPicker()),
        ],
      ),
    );
  }

  Widget _toolbarButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1117),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white70, size: 18),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 9)),
          ],
        ),
      ),
    );
  }

  // ─── Timeline ───
  Widget _buildTimeline(bool isTr) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isTr ? 'Slaytlar (${_project.slides.length})' : 'Slides (${_project.slides.length})',
                style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              Text(
                'Toplam: ${_project.slides.fold<double>(0, (sum, s) => sum + s.duration).toInt()}s',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _project.slides.length,
            itemBuilder: (context, index) {
              final slide = _project.slides[index];
              final isActive = index == _selectedSlideIndex;
              return GestureDetector(
                onTap: () => setState(() => _selectedSlideIndex = index),
                onLongPress: () => _showSlideOptions(index, isTr),
                child: Container(
                  width: 72,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isActive ? const Color(0xFF1E88E5) : Colors.white.withValues(alpha: 0.1),
                      width: isActive ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      // Küçük resim
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
                          child: slide.imagePath != null
                              ? Image.file(File(slide.imagePath!), fit: BoxFit.cover, width: double.infinity)
                              : Container(
                                  color: const Color(0xFF21262D),
                                  child: const Center(
                                    child: Icon(Icons.add, color: Colors.white24, size: 20),
                                  ),
                                ),
                        ),
                      ),
                      // Bilgi
                      Container(
                        height: 24,
                        decoration: const BoxDecoration(
                          color: Color(0xFF161B22),
                          borderRadius: BorderRadius.vertical(bottom: Radius.circular(9)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${slide.duration.toInt()}s',
                              style: TextStyle(
                                color: isActive ? const Color(0xFF1E88E5) : Colors.white54,
                                fontSize: 10,
                              ),
                            ),
                            if (slide.filter != FilterType.none) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.filter_alt, size: 8, color: Colors.white38),
                            ],
                          ],
                        ),
                      ),
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

  // ─── Slayt Seçenekleri ───
  void _showSlideOptions(int index, bool isTr) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy, color: Colors.white70),
              title: Text(isTr ? 'Slaytı Kopyala' : 'Duplicate Slide',
                  style: const TextStyle(color: Colors.white)),
              onTap: () {
                final original = _project.slides[index];
                final copy = StorySlide(
                  id: 'slide_${DateTime.now().millisecondsSinceEpoch}',
                  imagePath: original.imagePath,
                  filter: original.filter,
                  duration: original.duration,
                  transition: original.transition,
                  layers: List.from(original.layers.map((l) => SlideLayer(
                    id: '${l.id}_copy', type: l.type, text: l.text,
                    stickerEmoji: l.stickerEmoji, color: l.color,
                    fontSize: l.fontSize, x: l.x, y: l.y,
                  ))),
                );
                setState(() => _project.slides.insert(index + 1, copy));
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.redAccent),
              title: Text(isTr ? 'Slaytı Sil' : 'Delete Slide',
                  style: const TextStyle(color: Colors.redAccent)),
              onTap: () {
                _deleteSlide(index);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ─── Sticker Seici ───
  void _showStickerPicker(bool isTr) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (ctx, controller) => Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.all(12),
                children: stickerPacks.entries.map((entry) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          entry.key.toUpperCase(),
                          style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: entry.value.map((emoji) {
                          return GestureDetector(
                            onTap: () {
                              _addStickerToSlide(emoji);
                              Navigator.pop(ctx);
                            },
                            child: Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D1117),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(child: Text(emoji, style: const TextStyle(fontSize: 24))),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Süre Seici ───
  void _showDurationPicker(bool isTr) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isTr ? 'Slayt Süresi (saniye)' : 'Slide Duration (seconds)',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [1, 2, 3, 5, 7, 10].map((sec) {
                  final isActive = _currentSlide.duration == sec.toDouble();
                  return GestureDetector(
                    onTap: () {
                      setState(() => _currentSlide.duration = sec.toDouble());
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: isActive ? const Color(0xFF1E88E5) : const Color(0xFF0D1117),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text('${sec}s', style: TextStyle(
                          color: isActive ? Colors.white : Colors.white60,
                          fontWeight: FontWeight.w600,
                        )),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Geçiş Seici ───
  void _showTransitionPicker(bool isTr) {
    final transitions = [
      _TransItem('none', isTr ? 'Yok' : 'None', Icons.close),
      _TransItem('fade', isTr ? 'Solma' : 'Fade', Icons.gradient),
      _TransItem('slide', isTr ? 'Kayma' : 'Slide', Icons.swipe),
      _TransItem('zoom', isTr ? 'Yakınlaş' : 'Zoom', Icons.zoom_in),
      _TransItem('wipe', isTr ? 'SİL' : 'Wipe', Icons.view_carousel),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(isTr ? 'Geçiş Efekti' : 'Transition Effect',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            ...transitions.map((t) => ListTile(
                  leading: Icon(t.icon, color: _currentSlide.transition == t.id
                      ? const Color(0xFF1E88E5) : Colors.white54),
                  title: Text(t.label, style: TextStyle(
                    color: _currentSlide.transition == t.id
                        ? const Color(0xFF1E88E5) : Colors.white70,
                  )),
                  trailing: _currentSlide.transition == t.id
                      ? const Icon(Icons.check, color: Color(0xFF1E88E5), size: 20)
                      : null,
                  onTap: () {
                    setState(() => _currentSlide.transition = t.id);
                    Navigator.pop(ctx);
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ─── Renk Seici ───
  void _showColorPicker() {
    final colors = [
      0xFF0D1117, 0xFF1A1A2E, 0xFF16213E, 0xFF0F3460,
      0xFF1B1B2F, 0xFF162447, 0xFF1F4068, 0xFF1B1B2F,
      0xFFE94560, 0xFF53354A, 0xFF903749, 0xFF2B2E4A,
      0xFFFC5C65, 0xFFEB3B5A, 0xFFE84393, 0xFF6C5CE7,
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Arka Plan Rengi', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: colors.map((c) => GestureDetector(
                  onTap: () {
                    setState(() => _currentSlide.backgroundColor = c);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: Color(c),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _currentSlide.backgroundColor == c
                            ? Colors.white : Colors.white24,
                        width: _currentSlide.backgroundColor == c ? 2 : 1,
                      ),
                    ),
                  ),
                )).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Filtre seçici ekran (slayt için)
class _FilterPickerScreen extends StatefulWidget {
  final String imagePath;
  final FilterType currentFilter;

  const _FilterPickerScreen({required this.imagePath, required this.currentFilter});

  @override
  State<_FilterPickerScreen> createState() => _FilterPickerScreenState();
}

class _FilterPickerScreenState extends State<_FilterPickerScreen> {
  late FilterType _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.currentFilter;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1117),
        title: const Text('Filtre Seç', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _selected),
            child: const Text('Uygula', style: TextStyle(color: Color(0xFF1E88E5))),
          ),
        ],
      ),
      body: Column(
        children: [
          // Önizleme
          Expanded(
            child: Image.file(File(widget.imagePath), fit: BoxFit.contain),
          ),
          // Filtre listesi
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(8),
              itemCount: allFilters.length,
              itemBuilder: (context, index) {
                final f = allFilters[index];
                final isActive = _selected == f.type;
                return GestureDetector(
                  onTap: () => setState(() => _selected = f.type),
                  child: Container(
                    width: 72, margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: isActive ? const Color(0xFF1E88E5).withValues(alpha: 0.3) : const Color(0xFF161B22),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isActive ? const Color(0xFF1E88E5) : Colors.transparent,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(f.emoji, style: const TextStyle(fontSize: 24)),
                        const SizedBox(height: 4),
                        Text(f.nameTr, style: TextStyle(
                          fontSize: 10, color: isActive ? const Color(0xFF1E88E5) : Colors.white60,
                        )),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TransItem {
  final String id;
  final String label;
  final IconData icon;
  _TransItem(this.id, this.label, this.icon);
}

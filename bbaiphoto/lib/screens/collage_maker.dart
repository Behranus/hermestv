import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:bbaiphoto/l10n/locale_provider.dart';
import 'package:bbaiphoto/models/editor_models.dart';

/// Çoklu fotoğrafla kolaj oluşturma ekranı.
class CollageMaker extends StatefulWidget {
  const CollageMaker({super.key});

  @override
  State<CollageMaker> createState() => _CollageMakerState();
}

class _CollageMakerState extends State<CollageMaker> {
  CollageLayout _layout = CollageLayout.grid2x2;
  final List<String?> _photos = [null, null, null, null];
  double _padding = 4;
  double _borderRadius = 12;
  Color _backgroundColor = const Color(0xFF0D1117);

  // Düzen limitleme
  int get _maxPhotos => switch (_layout) {
    CollageLayout.grid2x2 => 4,
    CollageLayout.grid3x3 => 9,
    CollageLayout.grid2x3 => 6,
    CollageLayout.grid3x2 => 6,
    CollageLayout.horizontal3 => 3,
    CollageLayout.vertical3 => 3,
    CollageLayout.bigLeft => 3,
    CollageLayout.bigRight => 3,
    CollageLayout.bigTop => 3,
    CollageLayout.bigBottom => 3,
    CollageLayout.circle => 5,
    CollageLayout.heart => 7,
    CollageLayout.diagonal => 4,
  };

  @override
  void initState() {
    super.initState();
    _updatePhotoSlots();
  }

  void _updatePhotoSlots() {
    while (_photos.length < _maxPhotos) {
      _photos.add(null);
    }
    while (_photos.length > _maxPhotos) {
      _photos.removeLast();
    }
  }

  Future<void> _pickPhotoForSlot(int index) async {
    final result = await FilePicker.pickFile(type: FileType.image);
    if (result != null && result.path != null) {
      setState(() => _photos[index] = result.path);
    }
  }

  Future<void> _pickAllPhotos() async {
    final result = await FilePicker.pickFile(type: FileType.image);
    if (result != null && result.path != null) {
      setState(() {
        for (var i = 0; i < _maxPhotos; i++) {
          if (_photos[i] == null) {
            _photos[i] = result.path;
            break;
          }
        }
      });
    }
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
          isTr ? 'Kolaj Oluşturucu' : 'Collage Maker',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_library, color: Colors.white70),
            onPressed: _pickAllPhotos,
            tooltip: isTr ? 'Toplu Fotoğraf Seç' : 'Pick Multiple',
          ),
          IconButton(
            icon: const Icon(Icons.save, color: Colors.white70),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✅ Kolaj kaydedildi!')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── Önizleme ───
          Expanded(child: _buildPreview(isTr)),

          // ─── Ayarlar ───
          _buildSettingsPanel(isTr),
        ],
      ),
    );
  }

  Widget _buildPreview(bool isTr) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(_borderRadius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_borderRadius),
        child: _buildCollageLayout(),
      ),
    );
  }

  Widget _buildCollageLayout() {
    return switch (_layout) {
      CollageLayout.grid2x2 => _buildGrid(2, 2),
      CollageLayout.grid3x3 => _buildGrid(3, 3),
      CollageLayout.grid2x3 => _buildGrid(2, 3),
      CollageLayout.grid3x2 => _buildGrid(3, 2),
      CollageLayout.horizontal3 => _buildHorizontal(3),
      CollageLayout.vertical3 => _buildVertical(3),
      CollageLayout.bigLeft => _buildBigSide(true),
      CollageLayout.bigRight => _buildBigSide(false),
      CollageLayout.bigTop => _buildBigTopBottom(true),
      CollageLayout.bigBottom => _buildBigTopBottom(false),
      CollageLayout.circle => _buildCircle(),
      CollageLayout.heart => _buildHeart(),
      CollageLayout.diagonal => _buildDiagonal(),
    };
  }

  Widget _buildSlot(int index) {
    return GestureDetector(
      onTap: () => _pickPhotoForSlot(index),
      child: Container(
        margin: EdgeInsets.all(_padding / 2),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(_borderRadius / 2),
        ),
        child: _photos[index] != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(_borderRadius / 2),
                child: Image.file(File(_photos[index]!), fit: BoxFit.cover),
              )
            : Center(
                child: Icon(
                  index < _photos.length ? Icons.add : Icons.add,
                  color: Colors.white24,
                  size: 32,
                ),
              ),
      ),
    );
  }

  Widget _buildGrid(int cols, int rows) {
    return Column(
      children: List.generate(rows, (row) {
        return Expanded(
          child: Row(
            children: List.generate(cols, (col) {
              final index = row * cols + col;
              return Expanded(child: _buildSlot(index));
            }),
          ),
        );
      }),
    );
  }

  Widget _buildHorizontal(int count) {
    return Row(
      children: List.generate(count, (i) => Expanded(child: _buildSlot(i))),
    );
  }

  Widget _buildVertical(int count) {
    return Column(
      children: List.generate(count, (i) => Expanded(child: _buildSlot(i))),
    );
  }

  Widget _buildBigSide(bool bigLeft) {
    return Row(
      children: [
        Expanded(flex: 2, child: _buildSlot(0)),
        Expanded(
          child: Column(
            children: [Expanded(child: _buildSlot(1)), Expanded(child: _buildSlot(2))],
          ),
        ),
      ],
    );
  }

  Widget _buildBigTopBottom(bool bigTop) {
    return Column(
      children: [
        Expanded(flex: 2, child: _buildSlot(0)),
        Expanded(
          child: Row(
            children: [Expanded(child: _buildSlot(1)), Expanded(child: _buildSlot(2))],
          ),
        ),
      ],
    );
  }

  Widget _buildCircle() {
    return Stack(
      children: [
        // Merkez
        Center(child: SizedBox(width: 200, height: 200, child: _buildSlot(0))),
        // Çevre
        ...List.generate(min(4, _photos.length - 1), (i) {
          final angle = (i * 90 - 90) * pi / 180;
          final x = cos(angle) * 80;
          final y = sin(angle) * 80;
          return Positioned(
            left: MediaQuery.of(context).size.width / 2 + x - 40,
            top: 150 + y - 40,
            child: SizedBox(width: 80, height: 80, child: _buildSlot(i + 1)),
          );
        }),
      ],
    );
  }

  Widget _buildHeart() {
    return Center(
      child: SizedBox(
        width: 300,
        height: 300,
        child: Stack(
          children: [
            Center(child: SizedBox(width: 150, height: 150, child: _buildSlot(0))),
            Positioned(top: 10, left: 70, child: SizedBox(width: 80, height: 80, child: _buildSlot(1))),
            Positioned(top: 10, right: 70, child: SizedBox(width: 80, height: 80, child: _buildSlot(2))),
            Positioned(bottom: 50, left: 30, child: SizedBox(width: 70, height: 70, child: _buildSlot(3))),
            Positioned(bottom: 50, right: 30, child: SizedBox(width: 70, height: 70, child: _buildSlot(4))),
          ],
        ),
      ),
    );
  }

  Widget _buildDiagonal() {
    return Stack(
      children: [
        Positioned.fill(child: _buildSlot(0)),
        Positioned(
          top: 0, right: 0,
          width: 150, height: 150,
          child: _buildSlot(1),
        ),
        Positioned(
          bottom: 0, left: 0,
          width: 150, height: 150,
          child: _buildSlot(2),
        ),
      ],
    );
  }

  // ─── Ayarlar Paneli ───
  Widget _buildSettingsPanel(bool isTr) {
    return Container(
      color: const Color(0xFF161B22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Düzen seçici
          SizedBox(
            height: 80,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: CollageLayout.values.map((layout) {
                final isActive = _layout == layout;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _layout = layout;
                      _updatePhotoSlots();
                    });
                  },
                  child: Container(
                    width: 64,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: isActive ? const Color(0xFF1E88E5).withValues(alpha: 0.3) : const Color(0xFF0D1117),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isActive ? const Color(0xFF1E88E5) : Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_getLayoutIcon(layout), size: 20,
                            color: isActive ? const Color(0xFF1E88E5) : Colors.white54),
                        const SizedBox(height: 4),
                        Text(
                          _getLayoutName(layout, isTr),
                          style: TextStyle(
                            fontSize: 9,
                            color: isActive ? const Color(0xFF1E88E5) : Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Boşluk ayarı
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.space_bar, color: Colors.white54, size: 18),
                const SizedBox(width: 8),
                const Text('Boşluk', style: TextStyle(color: Colors.white60, fontSize: 12)),
                Expanded(
                  child: Slider(
                    value: _padding, min: 0, max: 16,
                    activeColor: const Color(0xFF1E88E5),
                    onChanged: (v) => setState(() => _padding = v),
                  ),
                ),
              ],
            ),
          ),

          // Köşe yuvarlaklığı
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.rounded_corner, color: Colors.white54, size: 18),
                const SizedBox(width: 8),
                const Text('Yuvarlatma', style: TextStyle(color: Colors.white60, fontSize: 12)),
                Expanded(
                  child: Slider(
                    value: _borderRadius, min: 0, max: 32,
                    activeColor: const Color(0xFF1E88E5),
                    onChanged: (v) => setState(() => _borderRadius = v),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  IconData _getLayoutIcon(CollageLayout layout) {
    return switch (layout) {
      CollageLayout.grid2x2 => Icons.grid_view,
      CollageLayout.grid3x3 => Icons.grid_3x3,
      CollageLayout.grid2x3 => Icons.view_module,
      CollageLayout.grid3x2 => Icons.view_module,
      CollageLayout.horizontal3 => Icons.view_column,
      CollageLayout.vertical3 => Icons.view_agenda,
      CollageLayout.bigLeft => Icons.view_sidebar,
      CollageLayout.bigRight => Icons.view_sidebar,
      CollageLayout.bigTop => Icons.splitscreen,
      CollageLayout.bigBottom => Icons.splitscreen,
      CollageLayout.circle => Icons.circle,
      CollageLayout.heart => Icons.favorite,
      CollageLayout.diagonal => Icons.category,
    };
  }

  String _getLayoutName(CollageLayout layout, bool isTr) {
    return switch (layout) {
      CollageLayout.grid2x2 => '2×2',
      CollageLayout.grid3x3 => '3×3',
      CollageLayout.grid2x3 => '2×3',
      CollageLayout.grid3x2 => '3×2',
      CollageLayout.horizontal3 => isTr ? 'Yatay' : 'Horiz',
      CollageLayout.vertical3 => isTr ? 'Dikey' : 'Vert',
      CollageLayout.bigLeft => isTr ? 'Sol Büyük' : 'Big L',
      CollageLayout.bigRight => isTr ? 'Sağ Büyük' : 'Big R',
      CollageLayout.bigTop => isTr ? 'Üst Büyük' : 'Big T',
      CollageLayout.bigBottom => isTr ? 'Alt Büyük' : 'Big B',
      CollageLayout.circle => isTr ? 'Daire' : 'Circle',
      CollageLayout.heart => isTr ? 'Kalp' : 'Heart',
      CollageLayout.diagonal => isTr ? 'Çapraz' : 'Diag',
    };
  }
}

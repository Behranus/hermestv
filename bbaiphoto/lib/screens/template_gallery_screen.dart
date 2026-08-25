import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bbaiphoto/l10n/locale_provider.dart';
import 'package:bbaiphoto/models/editor_models.dart';
import 'package:bbaiphoto/screens/photo_editor_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

/// Templix benzeri şablon galerisi.
/// Kategorilere göre düzenlenmiş şablonları gösterir.
class TemplateGalleryScreen extends StatefulWidget {
  const TemplateGalleryScreen({super.key});

  @override
  State<TemplateGalleryScreen> createState() => _TemplateGalleryScreenState();
}

class _TemplateGalleryScreenState extends State<TemplateGalleryScreen> {
  TemplateCategory? _selectedCategory;
  String _searchQuery = '';

  List<EditorTemplate> get _filteredTemplates {
    var templates = allTemplates;

    if (_selectedCategory != null) {
      templates =
          templates.where((t) => t.category == _selectedCategory).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      templates = templates
          .where((t) =>
              t.name.toLowerCase().contains(q) ||
              t.nameTr.toLowerCase().contains(q) ||
              t.description.toLowerCase().contains(q))
          .toList();
    }

    return templates;
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
          isTr ? 'Şablon Galerisi' : 'Template Gallery',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          // Arama çubuğu
          _buildSearchBar(isTr),

          // Kategori filtreleri
          _buildCategoryFilters(isTr),

          // Şablon grid
          Expanded(
            child: _filteredTemplates.isEmpty
                ? _buildEmptyState(isTr)
                : _buildTemplateGrid(isTr),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isTr) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: isTr ? 'Şablon ara...' : 'Search templates...',
          hintStyle: const TextStyle(color: Colors.white38),
          prefixIcon:
              const Icon(Icons.search, color: Colors.white38, size: 20),
          filled: true,
          fillColor: const Color(0xFF161B22),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildCategoryFilters(bool isTr) {
    final categories = [
      null, // Tümü
      ...TemplateCategory.values,
    ];

    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isActive = _selectedCategory == cat;
          final label = cat == null
              ? (isTr ? 'Tümü' : 'All')
              : (isTr
                  ? (categoryNamesTr[cat] ?? cat.name)
                  : (categoryNames[cat] ?? cat.name));

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(label),
              selected: isActive,
              onSelected: (_) {
                setState(() => _selectedCategory = cat);
              },
              backgroundColor: const Color(0xFF161B22),
              selectedColor: const Color(0xFF1E88E5),
              labelStyle: TextStyle(
                color: isActive ? Colors.white : Colors.white60,
                fontSize: 13,
              ),
              side: BorderSide.none,
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isTr) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off, size: 48, color: Colors.white24),
          const SizedBox(height: 12),
          Text(
            isTr ? 'Şablon bulunamadı' : 'No templates found',
            style: const TextStyle(color: Colors.white38, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateGrid(bool isTr) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 800
            ? 4
            : constraints.maxWidth > 500
                ? 3
                : 2;

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.65,
          ),
          itemCount: _filteredTemplates.length,
          itemBuilder: (context, index) {
            final template = _filteredTemplates[index];
            return _buildTemplateCard(template, isTr);
          },
        );
      },
    );
  }

  Widget _buildTemplateCard(EditorTemplate template, bool isTr) {
    return GestureDetector(
      onTap: () => _onTemplateTap(template),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thumbnail area
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _getGradientColors(template.category),
                  ),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(14)),
                ),
                child: Center(
                  child: Text(
                    template.emoji,
                    style: const TextStyle(fontSize: 42),
                  ),
                ),
              ),
            ),

            // Info area
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isTr ? template.nameTr : template.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (template.clipCount > 0) ...[
                          Icon(Icons.photo_library,
                              size: 12, color: Colors.white38),
                          const SizedBox(width: 3),
                          Text(
                            '${template.clipCount} ${isTr ? 'klip' : 'clips'}',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                        ],
                        if (template.duration > 0) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.access_time,
                              size: 12, color: Colors.white38),
                          const SizedBox(width: 3),
                          Text(
                            '${template.duration.toInt()}s',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const Spacer(),
                    // Kategori badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isTr
                            ? (categoryNamesTr[template.category] ??
                                template.category.name)
                            : (categoryNames[template.category] ??
                                template.category.name),
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Color> _getGradientColors(TemplateCategory category) {
    return switch (category) {
      TemplateCategory.reel => [
          const Color(0xFF667EEA),
          const Color(0xFF764BA2),
        ],
      TemplateCategory.story => [
          const Color(0xFFF093FB),
          const Color(0xFFF5576C),
        ],
      TemplateCategory.post => [
          const Color(0xFF4FACFE),
          const Color(0xFF00F2FE),
        ],
      TemplateCategory.cover => [
          const Color(0xFF43E97B),
          const Color(0xFF38F9D7),
        ],
      TemplateCategory.thumbnail => [
          const Color(0xFFFF5858),
          const Color(0xFFF09819),
        ],
      TemplateCategory.beforeAfter => [
          const Color(0xFFED4264),
          const Color(0xFFFFEDBC),
        ],
      TemplateCategory.motivation => [
          const Color(0xFF0250C5),
          const Color(0xFFD43F8D),
        ],
      TemplateCategory.summer => [
          const Color(0xFFFFD200),
          const Color(0xFF00B4DB),
        ],
      TemplateCategory.cutout => [
          const Color(0xFF868F96),
          const Color(0xFF596164),
        ],
      TemplateCategory.collage => [
          const Color(0xFF667EEA),
          const Color(0xFF764BA2),
        ],
    };
  }

  Future<void> _onTemplateTap(EditorTemplate template) async {
    // Fotoğraf seç ve şablonla aç
    final result = await FilePicker.pickFile(
      type: FileType.image,
    );

    if (result != null && result.path != null && mounted) {
      final file = File(result.path!);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PhotoEditorScreen(
            initialImage: file,
            templateId: template.id,
          ),
        ),
      );
    }
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bbaiphoto/l10n/locale_provider.dart';
import 'package:bbaiphoto/models/editor_models.dart';
import 'package:bbaiphoto/screens/photo_editor_screen.dart';
import 'package:bbaiphoto/screens/template_gallery_screen.dart';
import 'package:bbaiphoto/screens/story_creator.dart';
import 'package:bbaiphoto/screens/collage_maker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

/// Templix benzeri düzenleme dashboard'u.
/// Tüm araçları ve şablonları bir arada sunar.
class EditorDashboard extends StatefulWidget {
  const EditorDashboard({super.key});

  @override
  State<EditorDashboard> createState() => _EditorDashboardState();
}

class _EditorDashboardState extends State<EditorDashboard> {
  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final isTr = locale.lang == 'tr';

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: CustomScrollView(
        slivers: [
          // ─── Başlık ───
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  // Logo
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isTr ? 'AI Düzenleyici' : 'AI Editor',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        isTr
                            ? 'Fotoğraf ve video düzenleme araçları'
                            : 'Photo & video editing tools',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ─── Hızlı Aksiyonlar ───
          SliverToBoxAdapter(
            child: _buildQuickActions(isTr),
          ),

          // ─── AI Araçları Başlık ───
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Color(0xFF1E88E5), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    isTr ? 'AI Araçları' : 'AI Tools',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ─── AI Araç Grid ───
          SliverToBoxAdapter(
            child: _buildAIToolsGrid(isTr),
          ),

          // ─── Popüler Şablonlar Başlık ───
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department,
                          color: Color(0xFFFF5722), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        isTr ? 'Popüler Şablonlar' : 'Trending Templates',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TemplateGalleryScreen(),
                      ),
                    ),
                    child: Text(
                      isTr ? 'Tümünü Gör' : 'See All',
                      style: const TextStyle(
                        color: Color(0xFF1E88E5),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ─── Şablon Listesi (Yatay) ───
          SliverToBoxAdapter(
            child: _buildTrendingTemplates(isTr),
          ),

          // ─── Kategoriler Başlık ───
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Text(
                isTr ? 'Kategoriler' : 'Categories',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          // ─── Kategori Grid ───
          SliverToBoxAdapter(
            child: _buildCategoriesGrid(isTr),
          ),

          const SliverToBoxAdapter(
            child: SizedBox(height: 80),
          ),
        ],
      ),
    );
  }

  // ─── Hızlı Aksiyonlar ───
  Widget _buildQuickActions(bool isTr) {
    final actions = [
      _QuickAction(
        icon: Icons.photo_library,
        label: isTr ? 'Fotoğraf\nDüzenle' : 'Edit\nPhoto',
        gradient: const [Color(0xFF667EEA), Color(0xFF764BA2)],
        onTap: () => _pickAndEditPhoto(),
      ),
      _QuickAction(
        icon: Icons.videocam,
        label: isTr ? 'Video\nDüzenle' : 'Edit\nVideo',
        gradient: const [Color(0xFFF093FB), Color(0xFFF5576C)],
        onTap: () => _pickAndEditVideo(),
      ),
      _QuickAction(
        icon: Icons.auto_stories,
        label: isTr ? 'Hikaye\nOluştur' : 'Create\nStory',
        gradient: const [Color(0xFFF093FB), Color(0xFFF5576C)],
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const StoryCreator()),
        ),
      ),
      _QuickAction(
        icon: Icons.grid_view,
        label: isTr ? 'Kolaj\nOluştur' : 'Create\nCollage',
        gradient: const [Color(0xFF43E97B), Color(0xFF38F9D7)],
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CollageMaker()),
        ),
      ),
      _QuickAction(
        icon: Icons.collections,
        label: isTr ? 'Şablon\nGalerisi' : 'Template\nGallery',
        gradient: const [Color(0xFF4FACFE), Color(0xFF00F2FE)],
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TemplateGalleryScreen()),
        ),
      ),
      _QuickAction(
        icon: Icons.content_cut,
        label: isTr ? 'Kırp &\nDöndür' : 'Crop &\nRotate',
        gradient: const [Color(0xFF43E97B), Color(0xFF38F9D7)],
        onTap: () => _pickAndCrop(),
      ),
    ];

    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: actions.length,
        itemBuilder: (context, index) {
          final action = actions[index];
          return GestureDetector(
            onTap: action.onTap,
            child: Container(
              width: 100,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: action.gradient,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(action.icon, color: Colors.white, size: 28),
                  const SizedBox(height: 8),
                  Text(
                    action.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── AI Araçları Grid ───
  Widget _buildAIToolsGrid(bool isTr) {
    final tools = [
      _AITool(
        icon: Icons.face,
        emoji: '👤',
        name: isTr ? 'Face Swap' : 'Face Swap',
        desc: isTr ? 'Yüz değiştirme' : 'Swap faces',
        color: const Color(0xFF667EEA),
      ),
      _AITool(
        icon: Icons.content_cut,
        emoji: '✂️',
        name: isTr ? 'Arka Plan Kaldır' : 'Remove BG',
        desc: isTr ? 'Arka plan temizleme' : 'Background removal',
        color: const Color(0xFFF5576C),
      ),
      _AITool(
        icon: Icons.format_paint,
        emoji: '🎨',
        name: isTr ? 'Cartoon' : 'Cartoon',
        desc: isTr ? 'Çizgi film efekti' : 'Cartoon effect',
        color: const Color(0xFF43E97B),
      ),
      _AITool(
        icon: Icons.height,
        emoji: '⬆️',
        name: isTr ? 'Kalite Yükselt' : 'Upscale',
        desc: isTr ? '4K kaliteye yükselt' : 'Upscale to 4K',
        color: const Color(0xFFFF9800),
      ),
      _AITool(
        icon: Icons.brush,
        emoji: '💇',
        name: isTr ? 'Saç Değiştir' : 'Hair Change',
        desc: isTr ? 'Saç rengi/stili' : 'Hair color/style',
        color: const Color(0xFFE91E63),
      ),
      _AITool(
        icon: Icons.light_mode,
        emoji: '💡',
        name: isTr ? 'Işık Düzelt' : 'Fix Lighting',
        desc: isTr ? 'Aydınlatma düzeltme' : 'Lighting fix',
        color: const Color(0xFFFFC107),
      ),
      _AITool(
        icon: Icons.water_drop,
        emoji: '💧',
        name: isTr ? 'Su İşareti Kaldır' : 'Remove Watermark',
        desc: isTr ? 'Filigran temizleme' : 'Remove watermarks',
        color: const Color(0xFF00BCD4),
      ),
      _AITool(
        icon: Icons.restore,
        emoji: '📸',
        name: isTr ? 'Fotoğraf Restorasyon' : 'Photo Restore',
        desc: isTr ? 'Eski fotoğraf düzeltme' : 'Restore old photos',
        color: const Color(0xFF9C27B0),
      ),
    ];

    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: tools.length,
        itemBuilder: (context, index) {
          final tool = tools[index];
          return GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${tool.name} — ${isTr ? 'Yakında!' : 'Coming soon!'}'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Container(
              width: 90,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: tool.color.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: tool.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(tool.emoji, style: const TextStyle(fontSize: 24)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tool.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tool.desc,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 9,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Popüler Şablonlar (Yatay) ───
  Widget _buildTrendingTemplates(bool isTr) {
    final trending = allTemplates.take(6).toList();

    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: trending.length,
        itemBuilder: (context, index) {
          final template = trending[index];
          return GestureDetector(
            onTap: () async {
              final result = await FilePicker.pickFile(
                type: FileType.image,
              );
              if (!mounted) return;
              if (result != null && result.path != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PhotoEditorScreen(
                      initialImage: File(result.path!),
                      templateId: template.id,
                    ),
                  ),
                );
              }
            },
            child: Container(
              width: 150,
              margin: const EdgeInsets.symmetric(horizontal: 4),
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
                  // Gradient thumb
                  Expanded(
                    flex: 3,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: _getGradientColors(template.category),
                        ),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(14),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          template.emoji,
                          style: const TextStyle(fontSize: 36),
                        ),
                      ),
                    ),
                  ),
                  // Info
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isTr ? template.nameTr : template.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              if (template.duration > 0) ...[
                                const Icon(Icons.access_time,
                                    size: 10, color: Colors.white38),
                                const SizedBox(width: 2),
                                Text(
                                  '${template.duration.toInt()}s',
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E88E5)
                                      .withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isTr
                                      ? (categoryNamesTr[
                                              template.category] ??
                                          '')
                                      : (categoryNames[
                                              template.category] ??
                                          ''),
                                  style: const TextStyle(
                                    color: Color(0xFF1E88E5),
                                    fontSize: 9,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
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

  // ─── Kategoriler Grid ───
  Widget _buildCategoriesGrid(bool isTr) {
    final categories = [
      _CategoryItem(
        name: isTr ? 'Reels' : 'Reels',
        emoji: '📱',
        count: allTemplates.where((t) => t.category == TemplateCategory.reel).length,
        gradient: [const Color(0xFF667EEA), const Color(0xFF764BA2)],
        category: TemplateCategory.reel,
      ),
      _CategoryItem(
        name: isTr ? 'Hikayeler' : 'Stories',
        emoji: '📖',
        count: allTemplates.where((t) => t.category == TemplateCategory.story).length,
        gradient: [const Color(0xFFF093FB), const Color(0xFFF5576C)],
        category: TemplateCategory.story,
      ),
      _CategoryItem(
        name: isTr ? 'Gönderiler' : 'Posts',
        emoji: '📸',
        count: allTemplates.where((t) => t.category == TemplateCategory.post).length,
        gradient: [const Color(0xFF4FACFE), const Color(0xFF00F2FE)],
        category: TemplateCategory.post,
      ),
      _CategoryItem(
        name: isTr ? 'Önce/Sonra' : 'Before & After',
        emoji: '🔄',
        count: allTemplates.where((t) => t.category == TemplateCategory.beforeAfter).length,
        gradient: [const Color(0xFFED4264), const Color(0xFFFFEDBC)],
        category: TemplateCategory.beforeAfter,
      ),
      _CategoryItem(
        name: isTr ? 'Motivasyon' : 'Motivation',
        emoji: '🌟',
        count: allTemplates.where((t) => t.category == TemplateCategory.motivation).length,
        gradient: [const Color(0xFF0250C5), const Color(0xFFD43F8D)],
        category: TemplateCategory.motivation,
      ),
      _CategoryItem(
        name: isTr ? 'Küçük Resim' : 'Thumbnails',
        emoji: '🎬',
        count: allTemplates.where((t) => t.category == TemplateCategory.thumbnail).length,
        gradient: [const Color(0xFFFF5858), const Color(0xFFF09819)],
        category: TemplateCategory.thumbnail,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.6,
        ),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TemplateGalleryScreen()),
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: cat.gradient.map((c) => c.withValues(alpha: 0.3)).toList(),
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Text(cat.emoji, style: const TextStyle(fontSize: 24)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          cat.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${cat.count} ${isTr ? 'şablon' : 'templates'}',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Aksiyonlar ───
  Future<void> _pickAndEditPhoto() async {
    final result = await FilePicker.pickFile(
      type: FileType.image,
    );
    if (result != null && result.path != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PhotoEditorScreen(
            initialImage: File(result.path!),
          ),
        ),
      );
    }
  }

  Future<void> _pickAndEditVideo() async {
    final result = await FilePicker.pickFile(
      type: FileType.video,
    );
    if (result != null && result.path != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎬 Video düzenleme — Yakında!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _pickAndCrop() async {
    final result = await FilePicker.pickFile(
      type: FileType.image,
    );
    if (result != null && result.path != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PhotoEditorScreen(
            initialImage: File(result.path!),
          ),
        ),
      );
    }
  }
}

// ─── Yardımcı sınıflar ───

class _QuickAction {
  final IconData icon;
  final String label;
  final List<Color> gradient;
  final VoidCallback onTap;

  _QuickAction({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.onTap,
  });
}

class _AITool {
  final IconData icon;
  final String emoji;
  final String name;
  final String desc;
  final Color color;

  _AITool({
    required this.icon,
    required this.emoji,
    required this.name,
    required this.desc,
    required this.color,
  });
}

class _CategoryItem {
  final String name;
  final String emoji;
  final int count;
  final List<Color> gradient;
  final TemplateCategory category;

  _CategoryItem({
    required this.name,
    required this.emoji,
    required this.count,
    required this.gradient,
    required this.category,
  });
}

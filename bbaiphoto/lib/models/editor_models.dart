import 'dart:ui';
import 'package:flutter/material.dart';

/// ─── FİLTRE TÜRLERİ (40+) ───
enum FilterType {
  none,
  // Temel
  grayscale, sepia, vintage, noir, fade,
  // Renk
  warm, cool, cold, golden, rose, lavender,
  // Kontrast/Yoğunluk
  contrast, highContrast, softContrast, dramatic, punch, vivid,
  // Parlaklık
  bright, dark, expose, dim,
  //Efektler
  blur, sharpen, dreamy, ethereal, glow, vignette,
  // Film
  cinematic, film, kodachrome, portra, fuji, polaroid, instax,
  // Sanatsal
  oilPainting, watercolor, sketch, comic, pixelate, halftone,
  // Özel
  duotone, splitTone, crossProcess, bleachBypass, colorNegative,
}

/// Filtre bilgisi
class PhotoFilter {
  final FilterType type;
  final String name;
  final String nameTr;
  final String emoji;
  final FilterCategory category;

  const PhotoFilter({
    required this.type,
    required this.name,
    required this.nameTr,
    required this.emoji,
    required this.category,
  });
}

enum FilterCategory {
  all, basic, color, contrast, brightness, effect, film, artistic, special
}

/// ─── ŞABLONLAR ───
enum TemplateCategory {
  reel, story, post, cover, thumbnail,
  beforeAfter, motivation, summer, cutout, collage
}

class EditorTemplate {
  final String id;
  final String name;
  final String nameTr;
  final TemplateCategory category;
  final String description;
  final String emoji;
  final int clipCount;
  final double duration;

  const EditorTemplate({
    required this.id, required this.name, required this.nameTr,
    required this.category, required this.description,
    required this.emoji, this.clipCount = 1, this.duration = 0,
  });
}

/// ─── HİKAYE MODU ───
class StoryProject {
  final String id;
  String name;
  final List<StorySlide> slides;
  final DateTime createdAt;

  StoryProject({
    required this.id,
    this.name = 'Yeni Hikaye',
    List<StorySlide>? slides,
    DateTime? createdAt,
  }) : slides = slides ?? [],
       createdAt = createdAt ?? DateTime.now();
}

class StorySlide {
  final String id;
  String? imagePath;
  FilterType filter;
  List<SlideLayer> layers;
  double duration; // saniye
  String transition; // none, fade, slide, zoom
  int backgroundColor;

  StorySlide({
    required this.id,
    this.imagePath,
    this.filter = FilterType.none,
    List<SlideLayer>? layers,
    this.duration = 3.0,
    this.transition = 'fade',
    this.backgroundColor = 0xFF0D1117,
  }) : layers = layers ?? [];
}

/// ─── KATMAN SİSTEMİ ───
enum SlideLayerType { text, sticker, image, drawing, shape }

class SlideLayer {
  final String id;
  final SlideLayerType type;
  String? text;
  String? stickerEmoji;
  String? imagePath;
  Color color;
  double fontSize;
  double x, y;
  double rotation;
  double scale;
  double opacity;
  String? fontFamily;
  bool isBold;
  bool isItalic;

  SlideLayer({
    required this.id,
    required this.type,
    this.text,
    this.stickerEmoji,
    this.imagePath,
    this.color = Colors.white,
    this.fontSize = 24,
    this.x = 0.5, this.y = 0.5,
    this.rotation = 0,
    this.scale = 1,
    this.opacity = 1.0,
    this.fontFamily,
    this.isBold = false,
    this.isItalic = false,
  });
}

/// ─── ÇİZİM NOKTASI ───
class DrawPoint {
  final Offset point;
  final Color color;
  final double strokeWidth;

  const DrawPoint({
    required this.point,
    this.color = Colors.white,
    this.strokeWidth = 3,
  });
}

/// ─── KOLAJ DÜZENİ ───
enum CollageLayout {
  grid2x2, grid3x3, grid2x3, grid3x2,
  horizontal3, vertical3,
  bigLeft, bigRight, bigTop, bigBottom,
  circle, heart, diagonal,
}

class CollageItem {
  final String id;
  String? imagePath;
  FilterType filter;

  CollageItem({
    required this.id,
    this.imagePath,
    this.filter = FilterType.none,
  });
}

/// ─── TÜM FİLTRELER (40+) ───
const List<PhotoFilter> allFilters = [
  // All
  PhotoFilter(type: FilterType.none, name: 'Original', nameTr: 'Orijinal', emoji: '✨', category: FilterCategory.all),

  // Basic
  PhotoFilter(type: FilterType.grayscale, name: 'Grayscale', nameTr: 'Siyah Beyaz', emoji: '🖤', category: FilterCategory.basic),
  PhotoFilter(type: FilterType.sepia, name: 'Sepia', nameTr: 'Sepya', emoji: '📜', category: FilterCategory.basic),
  PhotoFilter(type: FilterType.vintage, name: 'Vintage', nameTr: 'Vintage', emoji: '📷', category: FilterCategory.basic),
  PhotoFilter(type: FilterType.noir, name: 'Noir', nameTr: 'Noir', emoji: '🕵️', category: FilterCategory.basic),
  PhotoFilter(type: FilterType.fade, name: 'Fade', nameTr: 'Soluk', emoji: '🌸', category: FilterCategory.basic),

  // Color
  PhotoFilter(type: FilterType.warm, name: 'Warm', nameTr: 'Sıcak', emoji: '🔥', category: FilterCategory.color),
  PhotoFilter(type: FilterType.cool, name: 'Cool', nameTr: 'Soğuk', emoji: '❄️', category: FilterCategory.color),
  PhotoFilter(type: FilterType.cold, name: 'Cold', nameTr: 'Buz', emoji: '🧊', category: FilterCategory.color),
  PhotoFilter(type: FilterType.golden, name: 'Golden', nameTr: 'Altın', emoji: '🥇', category: FilterCategory.color),
  PhotoFilter(type: FilterType.rose, name: 'Rose', nameTr: 'Gül', emoji: '🌹', category: FilterCategory.color),
  PhotoFilter(type: FilterType.lavender, name: 'Lavender', nameTr: 'Lavanta', emoji: '💜', category: FilterCategory.color),

  // Contrast
  PhotoFilter(type: FilterType.contrast, name: 'Contrast', nameTr: 'Kontrast', emoji: '🌓', category: FilterCategory.contrast),
  PhotoFilter(type: FilterType.highContrast, name: 'High Contrast', nameTr: 'Yüksek Kontrast', emoji: '⬛', category: FilterCategory.contrast),
  PhotoFilter(type: FilterType.softContrast, name: 'Soft Contrast', nameTr: 'Yumuşak Kontrast', emoji: '🫧', category: FilterCategory.contrast),
  PhotoFilter(type: FilterType.dramatic, name: 'Dramatic', nameTr: 'Dramatik', emoji: '🎭', category: FilterCategory.contrast),
  PhotoFilter(type: FilterType.punch, name: 'Punch', nameTr: 'Canlı Kontrast', emoji: '💥', category: FilterCategory.contrast),
  PhotoFilter(type: FilterType.vivid, name: 'Vivid', nameTr: 'Canlı', emoji: '🌈', category: FilterCategory.contrast),

  // Brightness
  PhotoFilter(type: FilterType.bright, name: 'Bright', nameTr: 'Parlak', emoji: '☀️', category: FilterCategory.brightness),
  PhotoFilter(type: FilterType.dark, name: 'Dark', nameTr: 'Karanlık', emoji: '🌑', category: FilterCategory.brightness),
  PhotoFilter(type: FilterType.expose, name: 'Expose', nameTr: 'Pozlama', emoji: '📸', category: FilterCategory.brightness),
  PhotoFilter(type: FilterType.dim, name: 'Dim', nameTr: 'Loş', emoji: '🔅', category: FilterCategory.brightness),

  // Effects
  PhotoFilter(type: FilterType.blur, name: 'Blur', nameTr: 'Bulanık', emoji: '🌫️', category: FilterCategory.effect),
  PhotoFilter(type: FilterType.sharpen, name: 'Sharpen', nameTr: 'Keskinleştir', emoji: '🔪', category: FilterCategory.effect),
  PhotoFilter(type: FilterType.dreamy, name: 'Dreamy', nameTr: 'Rüya', emoji: '💭', category: FilterCategory.effect),
  PhotoFilter(type: FilterType.ethereal, name: 'Ethereal', nameTr: 'Hafif', emoji: '👼', category: FilterCategory.effect),
  PhotoFilter(type: FilterType.glow, name: 'Glow', nameTr: 'Parıltı', emoji: '💫', category: FilterCategory.effect),
  PhotoFilter(type: FilterType.vignette, name: 'Vignette', nameTr: 'Vignette', emoji: '🔲', category: FilterCategory.effect),

  // Film
  PhotoFilter(type: FilterType.cinematic, name: 'Cinematic', nameTr: 'Sinematik', emoji: '🎬', category: FilterCategory.film),
  PhotoFilter(type: FilterType.film, name: 'Film', nameTr: 'Film', emoji: '🎞️', category: FilterCategory.film),
  PhotoFilter(type: FilterType.kodachrome, name: 'Kodachrome', nameTr: 'Kodachrome', emoji: '🎠', category: FilterCategory.film),
  PhotoFilter(type: FilterType.portra, name: 'Portra', nameTr: 'Portra', emoji: '🧑', category: FilterCategory.film),
  PhotoFilter(type: FilterType.fuji, name: 'Fuji', nameTr: 'Fuji', emoji: '🗻', category: FilterCategory.film),
  PhotoFilter(type: FilterType.polaroid, name: 'Polaroid', nameTr: 'Polaroid', emoji: '🖨️', category: FilterCategory.film),
  PhotoFilter(type: FilterType.instax, name: 'Instax', nameTr: 'Instax', emoji: '📐', category: FilterCategory.film),

  // Artistic
  PhotoFilter(type: FilterType.oilPainting, name: 'Oil Painting', nameTr: 'Yağlı Boya', emoji: '🎨', category: FilterCategory.artistic),
  PhotoFilter(type: FilterType.watercolor, name: 'Watercolor', nameTr: 'Sulu Boya', emoji: '🖌️', category: FilterCategory.artistic),
  PhotoFilter(type: FilterType.sketch, name: 'Sketch', nameTr: 'Çizim', emoji: '✏️', category: FilterCategory.artistic),
  PhotoFilter(type: FilterType.comic, name: 'Comic', nameTr: 'Çizgi Roman', emoji: '💥', category: FilterCategory.artistic),
  PhotoFilter(type: FilterType.pixelate, name: 'Pixelate', nameTr: 'Piksel', emoji: '🎮', category: FilterCategory.artistic),
  PhotoFilter(type: FilterType.halftone, name: 'Halftone', nameTr: 'Halftone', emoji: '🔵', category: FilterCategory.artistic),

  // Special
  PhotoFilter(type: FilterType.duotone, name: 'Duotone', nameTr: 'Çift Ton', emoji: '🟡', category: FilterCategory.special),
  PhotoFilter(type: FilterType.splitTone, name: 'Split Tone', nameTr: 'Bölünmüş Ton', emoji: '🔘', category: FilterCategory.special),
  PhotoFilter(type: FilterType.crossProcess, name: 'Cross Process', nameTr: 'Çapraz İşlem', emoji: '🔀', category: FilterCategory.special),
  PhotoFilter(type: FilterType.bleachBypass, name: 'Bleach Bypass', nameTr: 'Bleach Bypass', emoji: '🧪', category: FilterCategory.special),
  PhotoFilter(type: FilterType.colorNegative, name: 'Color Negative', nameTr: 'Negatif', emoji: '🔄', category: FilterCategory.special),
];

/// ─── TÜM ŞABLONLAR ───
const List<EditorTemplate> allTemplates = [
  EditorTemplate(id: 'reel_summer', name: 'Summer Vibes', nameTr: 'Yaz Rüzgarı', category: TemplateCategory.summer, description: 'Trendy summer reels', emoji: '☀️', clipCount: 12, duration: 15),
  EditorTemplate(id: 'reel_travel', name: 'Travel Diary', nameTr: 'Seyahat Günlüğü', category: TemplateCategory.reel, description: 'Beautiful travel moments', emoji: '✈️', clipCount: 20, duration: 30),
  EditorTemplate(id: 'reel_food', name: 'Food Showcase', nameTr: 'Yemek Sunumu', category: TemplateCategory.reel, description: 'Delicious food', emoji: '🍕', clipCount: 8, duration: 12),
  EditorTemplate(id: 'reel_fitness', name: 'Fitness Goals', nameTr: 'Spor Hedefleri', category: TemplateCategory.reel, description: 'Workout motivation', emoji: '💪', clipCount: 15, duration: 20),
  EditorTemplate(id: 'story_poll', name: 'Interactive Poll', nameTr: 'Anket Hikayesi', category: TemplateCategory.story, description: 'Engaging story', emoji: '📊', clipCount: 1, duration: 15),
  EditorTemplate(id: 'story_qna', name: 'Q&A Template', nameTr: 'Soru-Cevap', category: TemplateCategory.story, description: 'Q&A story', emoji: '❓', clipCount: 1, duration: 15),
  EditorTemplate(id: 'post_carousel', name: 'Carousel Post', nameTr: 'Karusel Gönderi', category: TemplateCategory.post, description: 'Multi-image carousel', emoji: '🎠', clipCount: 10),
  EditorTemplate(id: 'post_quote', name: 'Quote Post', nameTr: 'Alıntı Gönderisi', category: TemplateCategory.post, description: 'Beautiful quote', emoji: '💬', clipCount: 1),
  EditorTemplate(id: 'ba_transformation', name: 'Transformation', nameTr: 'Dönüşüm', category: TemplateCategory.beforeAfter, description: 'Before/after reveal', emoji: '🔄', clipCount: 2, duration: 8),
  EditorTemplate(id: 'mot_daily', name: 'Daily Motivation', nameTr: 'Günlük Motivasyon', category: TemplateCategory.motivation, description: 'Inspirational quote', emoji: '🌟', clipCount: 3, duration: 15),
  EditorTemplate(id: 'thumb_youtube', name: 'YouTube Thumbnail', nameTr: 'YouTube Küçük Resim', category: TemplateCategory.thumbnail, description: 'Eye-catching thumbnail', emoji: '🎬', clipCount: 1),
  EditorTemplate(id: 'collage_memory', name: 'Memory Collage', nameTr: 'Anı Kolajı', category: TemplateCategory.collage, description: 'Photo collage', emoji: '🖼️', clipCount: 9),
  EditorTemplate(id: 'collage_travel', name: 'Travel Collage', nameTr: 'Seyahat Kolajı', category: TemplateCategory.collage, description: 'Travel photo grid', emoji: '🗺️', clipCount: 6),
];

/// ─── STICKER PAKETLERİ ───
const Map<String, List<String>> stickerPacks = {
  'ifadeler': ['😀','😂','😍','🤩','😎','🥳','😭','🥺','🤯','💀','👻','🤖','👽','😈','🤡'],
  'kalpler': ['❤️','🧡','💛','💚','💙','💜','🖤','🤍','💔','💕','💞','💓','💗','💖','💘'],
  'el': ['👍','👎','👏','🙌','🤝','✌️','🤞','🫶','👋','✋','🖐️','💪','🦾','👆','👇'],
  'yildiz': ['⭐','🌟','💫','✨','🔥','💥','⚡','🌈','☀️','🌙','❄️','💧','🌊','🍕','🎵'],
  'emoji': ['🎉','🎊','🏆','🥇','🎯','💎','👑','🎪','🎨','📸','🎬','🎭','🎶','🎸','🎺'],
  'yazi': ['💯','🆕','⚠️','❌','✅','⭕','❓','❗','💬','👁️‍🗨️','🗨️','🗯️','🔱','⚜️','♻️'],
  'sekiller': ['🔴','🟠','🟡','🟢','🔵','🟣','⚫','⚪','🟤','🔶','🔷','🔸','🔹','⬜','⬛'],
  'doga': ['🌸','🌺','🌻','🌹','🌷','🌱','🍀','🍃','🦋','🐝','🌈','☀️','🌙','⭐','🌊'],
};

/// Kategori isimleri
const Map<TemplateCategory, String> categoryNames = {
  TemplateCategory.reel: 'Reels', TemplateCategory.story: 'Stories',
  TemplateCategory.post: 'Posts', TemplateCategory.cover: 'Kapak',
  TemplateCategory.thumbnail: 'Küçük Resim', TemplateCategory.beforeAfter: 'Önce/Sonra',
  TemplateCategory.motivation: 'Motivasyon', TemplateCategory.summer: 'Yaz',
  TemplateCategory.cutout: 'Kesim', TemplateCategory.collage: 'Kolaj',
};

const Map<TemplateCategory, String> categoryNamesTr = {
  TemplateCategory.reel: 'Reels', TemplateCategory.story: 'Hikayeler',
  TemplateCategory.post: 'Gönderiler', TemplateCategory.cover: 'Kapak Fotoğrafı',
  TemplateCategory.thumbnail: 'Küçük Resim', TemplateCategory.beforeAfter: 'Önce/Sonra',
  TemplateCategory.motivation: 'Motivasyon', TemplateCategory.summer: 'Yaz',
  TemplateCategory.cutout: 'Kesim/Çıkarma', TemplateCategory.collage: 'Kolaj',
};

const Map<FilterCategory, String> filterCategoryNames = {
  FilterCategory.all: 'Tümü',
  FilterCategory.basic: 'Temel',
  FilterCategory.color: 'Renk',
  FilterCategory.contrast: 'Kontrast',
  FilterCategory.brightness: 'Parlaklık',
  FilterCategory.effect: 'Efekt',
  FilterCategory.film: 'Film',
  FilterCategory.artistic: 'Sanatsal',
  FilterCategory.special: 'Özel',
};

const Map<FilterCategory, String> filterCategoryNamesEn = {
  FilterCategory.all: 'All',
  FilterCategory.basic: 'Basic',
  FilterCategory.color: 'Color',
  FilterCategory.contrast: 'Contrast',
  FilterCategory.brightness: 'Brightness',
  FilterCategory.effect: 'Effect',
  FilterCategory.film: 'Film',
  FilterCategory.artistic: 'Artistic',
  FilterCategory.special: 'Special',
};

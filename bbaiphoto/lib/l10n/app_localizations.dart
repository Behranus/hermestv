/// BBAIPhoto lokalizasyon sistemi — Türkçe, İngilizce.
class AppLocalizations {
  final String lang;
  const AppLocalizations(this.lang);

  static const _s = <String, Map<String, String>>{
    'tr': {
      // ── Navigation ──
      'home': 'Ana Sayfa',
      'editor': 'Düzenleyici',
      'templates': 'Şablonlar',
      'settings': 'Ayarlar',
      // ── Editor ──
      'photo_editor': 'Fotoğraf Düzenleyici',
      'video_editor': 'Video Düzenleyici',
      'edit_photo': 'Fotoğraf\nDüzenle',
      'edit_video': 'Video\nDüzenle',
      'template_gallery': 'Şablon Galerisi',
      'template_gallery_label': 'Şablon\nGalerisi',
      'crop_rotate': 'Kırp &\nDöndür',
      'ai_tools': 'AI Araçları',
      'trending_templates': 'Popüler Şablonlar',
      'see_all': 'Tümünü Gör',
      'categories': 'Kategoriler',
      // ── AI Tools ──
      'face_swap': 'Face Swap',
      'face_swap_desc': 'Yüz değiştirme',
      'remove_bg': 'Arka Plan Kaldır',
      'remove_bg_desc': 'Arka plan temizleme',
      'cartoon': 'Cartoon',
      'cartoon_desc': 'Çizgi film efekti',
      'upscale': 'Kalite Yükselt',
      'upscale_desc': '4K kaliteye yükselt',
      'hair_change': 'Saç Değiştir',
      'hair_change_desc': 'Saç rengi/stili',
      'fix_lighting': 'Işık Düzelt',
      'fix_lighting_desc': 'Aydınlatma düzeltme',
      'remove_watermark': 'Su İşareti Kaldır',
      'remove_watermark_desc': 'Filigran temizleme',
      'photo_restore': 'Fotoğraf Restorasyon',
      'photo_restore_desc': 'Eski fotoğraf düzeltme',
      'coming_soon': 'Yakında!',
      // ── Photo Editor ──
      'filters': 'Filtreler',
      'adjust': 'Ayarlar',
      'text': 'Metin',
      'sticker': 'Sticker',
      'crop': 'Kırp',
      'brightness': 'Parlaklık',
      'contrast': 'Kontrast',
      'saturation': 'Doygunluk',
      'warmth': 'Sıcaklık',
      'sharpness': 'Keskinlik',
      'add_text': 'Metin Ekle',
      'type_text': 'Metin yazın...',
      'select_photo': 'Düzenlenecek fotoğrafı seçin',
      'pick_photo': 'Fotoğraf Seç',
      'saved': 'Kaydedildi',
      'save_error': 'Kaydetme hatası',
      'undo': 'Geri Al',
      'redo': 'İleri Al',
      'select_aspect': 'En Boy Oranı Seçin',
      'free': 'Serbest',
      'square': 'Kare',
      'original': 'Orijinal',
      'grayscale': 'Siyah Beyaz',
      'sepia': 'Sepya',
      'vintage': 'Vintage',
      'warm': 'Sıcak',
      'cool': 'Soğuk',
      'high_contrast': 'Yüksek Kontrast',
      'bright': 'Parlak',
      'vivid': 'Canlı',
      'blur': 'Bulanık',
      'sharpen': 'Keskinleştir',
      'dramatic': 'Dramatik',
      'cinematic': 'Sinematik',
      'fade': 'Soluk',
      'noir': 'Noir',
      // ── Templates ──
      'search_templates': 'Şablon ara...',
      'no_templates': 'Şablon bulunamadı',
      'all': 'Tümü',
      'reels': 'Reels',
      'stories': 'Hikayeler',
      'posts': 'Gönderiler',
      'before_after': 'Önce/Sonra',
      'motivation': 'Motivasyon',
      'thumbnails': 'Küçük Resim',
      'covers': 'Kapak',
      'cutout': 'Kesim/Çıkarma',
      'summer': 'Yaz',
      'clips': 'klip',
      'templates_count': 'şablon',
      // ── General ──
      'loading': 'Yükleniyor…',
      'error': 'Hata',
      'cancel': 'İptal',
      'ok': 'Tamam',
      'save': 'Kaydet',
      'delete': 'Sil',
      'close': 'Kapat',
      'language': 'Dil',
      'turkish': 'Türkçe',
      'english': 'İngilizce',
      // ── About ──
      'app_name': 'BBAI Photo',
      'app_desc': 'Fotoğraf ve video düzenleme araçları',
      'version': 'Sürüm 1.0.0',
    },
    'en': {
      'home': 'Home',
      'editor': 'Editor',
      'templates': 'Templates',
      'settings': 'Settings',
      'photo_editor': 'Photo Editor',
      'video_editor': 'Video Editor',
      'edit_photo': 'Edit\nPhoto',
      'edit_video': 'Edit\nVideo',
      'template_gallery': 'Template Gallery',
      'template_gallery_label': 'Template\nGallery',
      'crop_rotate': 'Crop &\nRotate',
      'ai_tools': 'AI Tools',
      'trending_templates': 'Trending Templates',
      'see_all': 'See All',
      'categories': 'Categories',
      'face_swap': 'Face Swap',
      'face_swap_desc': 'Swap faces',
      'remove_bg': 'Remove BG',
      'remove_bg_desc': 'Background removal',
      'cartoon': 'Cartoon',
      'cartoon_desc': 'Cartoon effect',
      'upscale': 'Upscale',
      'upscale_desc': 'Upscale to 4K',
      'hair_change': 'Hair Change',
      'hair_change_desc': 'Hair color/style',
      'fix_lighting': 'Fix Lighting',
      'fix_lighting_desc': 'Lighting fix',
      'remove_watermark': 'Remove Watermark',
      'remove_watermark_desc': 'Remove watermarks',
      'photo_restore': 'Photo Restore',
      'photo_restore_desc': 'Restore old photos',
      'coming_soon': 'Coming soon!',
      'filters': 'Filters',
      'adjust': 'Adjust',
      'text': 'Text',
      'sticker': 'Sticker',
      'crop': 'Crop',
      'brightness': 'Brightness',
      'contrast': 'Contrast',
      'saturation': 'Saturation',
      'warmth': 'Warmth',
      'sharpness': 'Sharpness',
      'add_text': 'Add Text',
      'type_text': 'Type text...',
      'select_photo': 'Select a photo to edit',
      'pick_photo': 'Pick Photo',
      'saved': 'Saved',
      'save_error': 'Save error',
      'undo': 'Undo',
      'redo': 'Redo',
      'select_aspect': 'Select Aspect Ratio',
      'free': 'Free',
      'square': 'Square',
      'original': 'Original',
      'grayscale': 'Grayscale',
      'sepia': 'Sepia',
      'vintage': 'Vintage',
      'warm': 'Warm',
      'cool': 'Cool',
      'high_contrast': 'High Contrast',
      'bright': 'Bright',
      'vivid': 'Vivid',
      'blur': 'Blur',
      'sharpen': 'Sharpen',
      'dramatic': 'Dramatic',
      'cinematic': 'Cinematic',
      'fade': 'Fade',
      'noir': 'Noir',
      'search_templates': 'Search templates...',
      'no_templates': 'No templates found',
      'all': 'All',
      'reels': 'Reels',
      'stories': 'Stories',
      'posts': 'Posts',
      'before_after': 'Before & After',
      'motivation': 'Motivation',
      'thumbnails': 'Thumbnails',
      'covers': 'Covers',
      'cutout': 'Cutout',
      'summer': 'Summer',
      'clips': 'clips',
      'templates_count': 'templates',
      'loading': 'Loading…',
      'error': 'Error',
      'cancel': 'Cancel',
      'ok': 'OK',
      'save': 'Save',
      'delete': 'Delete',
      'close': 'Close',
      'language': 'Language',
      'turkish': 'Turkish',
      'english': 'English',
      'app_name': 'BBAI Photo',
      'app_desc': 'Photo & video editing tools',
      'version': 'Version 1.0.0',
    },
  };

  String _t(String key) => _s[lang]?[key] ?? _s['en']?[key] ?? key;

  String get home => _t('home');
  String get editor => _t('editor');
  String get templates => _t('templates');
  String get settings => _t('settings');
  String get photoEditor => _t('photo_editor');
  String get videoEditor => _t('video_editor');
  String get editPhoto => _t('edit_photo');
  String get editVideo => _t('edit_video');
  String get templateGallery => _t('template_gallery');
  String get templateGalleryLabel => _t('template_gallery_label');
  String get cropRotate => _t('crop_rotate');
  String get aiTools => _t('ai_tools');
  String get trendingTemplates => _t('trending_templates');
  String get seeAll => _t('see_all');
  String get categories => _t('categories');
  String get faceSwap => _t('face_swap');
  String get faceSwapDesc => _t('face_swap_desc');
  String get removeBg => _t('remove_bg');
  String get removeBgDesc => _t('remove_bg_desc');
  String get cartoonTool => _t('cartoon');
  String get cartoonDesc => _t('cartoon_desc');
  String get upscaleTool => _t('upscale');
  String get upscaleDesc => _t('upscale_desc');
  String get hairChange => _t('hair_change');
  String get hairChangeDesc => _t('hair_change_desc');
  String get fixLighting => _t('fix_lighting');
  String get fixLightingDesc => _t('fix_lighting_desc');
  String get removeWatermark => _t('remove_watermark');
  String get removeWatermarkDesc => _t('remove_watermark_desc');
  String get photoRestore => _t('photo_restore');
  String get photoRestoreDesc => _t('photo_restore_desc');
  String get comingSoon => _t('coming_soon');
  String get filters => _t('filters');
  String get adjust => _t('adjust');
  String get textTool => _t('text');
  String get stickerTool => _t('sticker');
  String get cropTool => _t('crop');
  String get brightnessLabel => _t('brightness');
  String get contrastLabel => _t('contrast');
  String get saturationLabel => _t('saturation');
  String get warmthLabel => _t('warmth');
  String get sharpnessLabel => _t('sharpness');
  String get addText => _t('add_text');
  String get typeText => _t('type_text');
  String get selectPhoto => _t('select_photo');
  String get pickPhoto => _t('pick_photo');
  String get saved => _t('saved');
  String get saveError => _t('save_error');
  String get undo => _t('undo');
  String get redo => _t('redo');
  String get selectAspect => _t('select_aspect');
  String get freeLabel => _t('free');
  String get squareLabel => _t('square');
  String get originalFilter => _t('original');
  String get grayscaleFilter => _t('grayscale');
  String get sepiaFilter => _t('sepia');
  String get vintageFilter => _t('vintage');
  String get warmFilter => _t('warm');
  String get coolFilter => _t('cool');
  String get highContrastFilter => _t('high_contrast');
  String get brightFilter => _t('bright');
  String get vividFilter => _t('vivid');
  String get blurFilter => _t('blur');
  String get sharpenFilter => _t('sharpen');
  String get dramaticFilter => _t('dramatic');
  String get cinematicFilter => _t('cinematic');
  String get fadeFilter => _t('fade');
  String get noirFilter => _t('noir');
  String get searchTemplates => _t('search_templates');
  String get noTemplates => _t('no_templates');
  String get allLabel => _t('all');
  String get reelsLabel => _t('reels');
  String get storiesLabel => _t('stories');
  String get postsLabel => _t('posts');
  String get beforeAfterLabel => _t('before_after');
  String get motivationLabel => _t('motivation');
  String get thumbnailsLabel => _t('thumbnails');
  String get coversLabel => _t('covers');
  String get cutoutLabel => _t('cutout');
  String get summerLabel => _t('summer');
  String get clipsLabel => _t('clips');
  String get templatesCountLabel => _t('templates_count');
  String get loading => _t('loading');
  String get errorLabel => _t('error');
  String get cancel => _t('cancel');
  String get ok => _t('ok');
  String get saveLabel => _t('save');
  String get deleteLabel => _t('delete');
  String get close => _t('close');
  String get language => _t('language');
  String get turkish => _t('turkish');
  String get english => _t('english');
  String get appName => _t('app_name');
  String get appDesc => _t('app_desc');
  String get version => _t('version');
}

AppLocalizations loc(String lang) => AppLocalizations(lang);
const supportedLocales = ['tr', 'en'];

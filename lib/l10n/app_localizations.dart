/// HermesTV lokalizasyon sistemi — Türkçe, İngilizce, Kürtçe.
class AppLocalizations {
  final String lang;
  const AppLocalizations(this.lang);

  static const _strings = <String, Map<String, String>>{
    'tr': {
      'channels': 'Kanallar',
      'vod': 'VOD',
      'favorites': 'Favoriler',
      'donate': 'Destek',
      'setup': 'Kurulum',
      'search': 'Ara',
      'live': 'CANLI',
      'movies': 'Filmler',
      'series': 'Diziler',
      'settings': 'Ayarlar',
      'subtitle': 'Altyazı',
      'audio': 'Ses',
      'quality': 'Görüntü Kalitesi',
      'menu': 'Menü',
      'back': 'Geri',
      'play': 'Oynat',
      'pause': 'Durdur',
      'stop': 'Durdur',
      'next': 'Sonraki',
      'previous': 'Önceki',
      'forward': 'İleri Sar',
      'rewind': 'Geri Sar',
      'now_playing': 'Şu An Oynuyor',
      'coming_up': 'Sıradaki',
      'channel_list': 'Kanal Listesi',
      'free_tv': 'Ücretsiz TV',
      'add_source': 'Kaynak Ekle',
      'url_playlist': 'Playlist URL\'si',
      'xtream_codes': 'Xtream Codes',
      'file_m3u': 'Dosya ile M3U Yükle',
      'epg': 'Program Rehberi',
      'connection_speed': 'Bağlantı Hızı',
      'loading': 'Yükleniyor...',
      'error': 'Hata',
      'no_channels': 'Kanal bulunamadı',
      'language': 'Dil',
      'turkish': 'Türkçe',
      'english': 'İngilizce',
      'kurdish': 'Kürtçe',
    },
    'en': {
      'channels': 'Channels',
      'vod': 'VOD',
      'favorites': 'Favorites',
      'donate': 'Support',
      'setup': 'Setup',
      'search': 'Search',
      'live': 'LIVE',
      'movies': 'Movies',
      'series': 'Series',
      'settings': 'Settings',
      'subtitle': 'Subtitle',
      'audio': 'Audio',
      'quality': 'Video Quality',
      'menu': 'Menu',
      'back': 'Back',
      'play': 'Play',
      'pause': 'Pause',
      'stop': 'Stop',
      'next': 'Next',
      'previous': 'Previous',
      'forward': 'Forward',
      'rewind': 'Rewind',
      'now_playing': 'Now Playing',
      'coming_up': 'Coming Up',
      'channel_list': 'Channel List',
      'free_tv': 'Free TV',
      'add_source': 'Add Source',
      'url_playlist': 'Playlist URL',
      'xtream_codes': 'Xtream Codes',
      'file_m3u': 'Load M3U File',
      'epg': 'Program Guide',
      'connection_speed': 'Connection Speed',
      'loading': 'Loading...',
      'error': 'Error',
      'no_channels': 'No channels found',
      'language': 'Language',
      'turkish': 'Turkish',
      'english': 'English',
      'kurdish': 'Kurdish',
    },
    'ku': {
      'channels': 'Kanal',
      'vod': 'VOD',
      'favorites': 'Bijarte',
      'donate': 'Destek',
      'setup': 'Sazkirin',
      'search': 'Lêgerîn',
      'live': 'ZINDÎ',
      'movies': 'Film',
      'series': 'Dîzî',
      'settings': 'Eyar',
      'subtitle': 'Altyazı',
      'audio': 'Deng',
      'quality': 'Kalite',
      'menu': 'Menu',
      'back': 'Paşve',
      'play': 'Litirîne',
      'pause': 'Bisekinîne',
      'stop': 'Rawestê',
      'next': 'Paşde',
      'previous': 'Pêşve',
      'forward': 'Pêşve fire',
      'rewind': 'Paşve fire',
      'now_playing': 'Niha tê lêdan',
      'coming_up': 'Paşde tê',
      'channel_list': 'Lîsteya Kanal',
      'free_tv': 'TV Bê fecere',
      'add_source': 'Çavkani zêde bike',
      'url_playlist': 'URL Playlist',
      'xtream_codes': 'Xtream Codes',
      'file_m3u': 'Pel M3U barkirîne',
      'epg': 'Rêberê bermânê',
      'connection_speed': 'Lezê tenduristiyê',
      'loading': 'Tê barkirin...',
      'error': 'Çewtî',
      'no_channels': 'Kanal nehat dîtin',
      'language': 'Ziman',
      'turkish': 'Tirkî',
      'english': 'Îngilîzî',
      'kurdish': 'Kurdî',
    },
  };

  String _t(String key) => _strings[lang]?[key] ?? _strings['en']?[key] ?? key;

  // Navigation
  String get channels => _t('channels');
  String get vod => _t('vod');
  String get favorites => _t('favorites');
  String get donate => _t('donate');
  String get setup => _t('setup');

  // Player
  String get search => _t('search');
  String get live => _t('live');
  String get movies => _t('movies');
  String get series => _t('series');
  String get subtitle => _t('subtitle');
  String get audio => _t('audio');
  String get quality => _t('quality');
  String get menu => _t('menu');
  String get back => _t('back');
  String get play => _t('play');
  String get pause => _t('pause');
  String get stop => _t('stop');
  String get next => _t('next');
  String get previous => _t('previous');
  String get forward => _t('forward');
  String get rewind => _t('rewind');
  String get nowPlaying => _t('now_playing');
  String get comingUp => _t('coming_up');
  String get channelList => _t('channel_list');

  // Setup
  String get freeTv => _t('free_tv');
  String get addSource => _t('add_source');
  String get urlPlaylist => _t('url_playlist');
  String get xtreamCodes => _t('xtream_codes');
  String get fileM3u => _t('file_m3u');
  String get epg => _t('epg');
  String get connectionSpeed => _t('connection_speed');

  // General
  String get loading => _t('loading');
  String get error => _t('error');
  String get noChannels => _t('no_channels');
  String get language => _t('language');
  String get turkish => _t('turkish');
  String get english => _t('english');
  String get kurdish => _t('kurdish');
}

/// Dil koduna göre AppLocalizations döndürür.
AppLocalizations loc(String lang) => AppLocalizations(lang);

/// Desteklenen diller.
const supportedLocales = ['tr', 'en', 'ku'];
const localeLabels = {
  'tr': '🇹🇷 Türkçe',
  'en': '🇬🇧 English',
  'ku': '🏴 Kürtçe',
};

/// HermesTV lokalizasyon sistemi — Türkçe, İngilizce, Kürtçe.
class AppLocalizations {
  final String lang;
  const AppLocalizations(this.lang);

  static const _s = <String, Map<String, String>>{
    'tr': {
      // ── Navigation ──
      'channels': 'Kanallar',
      'vod': 'VOD',
      'favorites': 'Favoriler',
      'donate': 'Destek',
      'setup': 'Kurulum',
      // ── Player ──
      'search': 'Ara',
      'live': 'CANLI',
      'movies': 'Filmler',
      'series': 'Diziler',
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
      'retry': 'Tekrar Dene',
      'now_playing': 'Şu An Oynuyor',
      'coming_up': 'Sıradaki',
      'channel_list': 'Kanal Listesi',
      'sleep_timer': 'Uyku Zamanlayıcı',
      'aspect_ratio': 'Ekran Oranı',
      'hours': 'saat',
      'minutes': 'dakika',
      'minutes_later_stop': 'dakika sonra duracak',
      'part': 'parça',
      'stream_subtitles': 'Akış Altyazıları',
      'no_audio_tracks': 'Bu yayında birden fazla ses parçası bulunamadı',
      'no_upcoming': 'Bu kanal için yaklaşan program yok.',
      'channel_of': 'kanal',
      'track_of': 'parça',
      // ── Setup ──
      'free_tv': 'Ücretsiz TV',
      'add_source': 'Kaynak Ekle',
      'url_playlist': 'Playlist URL\'si',
      'xtream_codes': 'Xtream Codes',
      'file_m3u': 'Dosya ile M3U Yükle',
      'epg': 'Program Rehberi',
      'connection_speed': 'Bağlantı Hızı',
      'source_added': 'kanal yüklendi.',
      'load_error': 'Yükleme hatası',
      'login_error': 'Giriş hatası',
      'connection_error': 'Bağlantı hatası',
      'saved_source': 'Kayıtlı kaynak',
      'remove': 'Kaldır',
      'load_url': 'URL\'den Yükle',
      'load_epg': 'EPG Yükle',
      'epg_url': 'EPG URL\'si',
      'pick_file': 'Dosya ile M3U Yükle',
      'pick_file_sub': 'Cihazdan M3U dosyası seç',
      'free_legal': 'Ücretsiz ve Yasal Kanallar',
      'free_legal_sub': 'iptv-org kataloğundan ülke → kategori seç',
      'free_hd': 'HD/4K ücretsiz yayınlar',
      'loading_label': 'yükleniyor…',
      'loaded_label': 'yüklendi',
      'retry_button': 'Tekrar dene',
      'server': 'Sunucu adresi',
      'username': 'Kullanıcı adı',
      'password': 'Şifre',
      'login': 'Giriş Yap',
      'connecting': 'Bağlanılıyor…',
      'player': 'Oynatıcı',
      'speed_desc': 'Kanal geçiş hızı ve tampon süresi.',
      'epg_desc': 'Sağlayıcının verdiği XMLTV adresini gir.',
      'epg_loaded': 'kanal için program yüklendi.',
      'status': 'Durum',
      'verified': 'Kanallar doğrulanıyor…',
      // ── VOD ──
      'vod_needs_xtream': 'VOD için Xtream bağlantısı gerekir',
      'vod_xtream_hint': 'Kurulum sekmesinden Xtream Codes girişi yap',
      // ── Donate ──
      'support': 'Destek',
      'support_title': 'HermesTV\'yi Destekleyin',
      'support_desc': 'HermesTV tamamen ücretsiz ve reklamsızdır.\nGeliştirmeye devam etmemiz için destekleriniz çok değerli.',
      'github_sponsors': 'GitHub Sponsors',
      'github_sub': 'Açık kaynak geliştirmeyi destekle',
      'support_on_github': 'GitHub Sponsors\'ta Destekle',
      'copy_link': 'Linki Kopyala',
      'copied': 'Link kopyalandı',
      'star_text': 'Bu uygulamayı beğendiyseniz, bir yıldız vermeyi unutmayın!\nTüm destekleriniz gelecek sürümler için motivasyon kaynağı.',
      // ── Subtitle Search ──
      'sub_download_error': 'Altyazı indirilemedi',
      'sub_search_open': 'OpenSubtitles\'da ara',
      'sub_search_desc': 'İnternette altyazı bul ve yükle',
      'audio_tracks': 'Ses Parçaları',
      'audio_tracks_avail': 'Mevcut',
      'audio_tracks_dil': 'dil',
      'sub_from_file': 'Dosyadan altyazı yükle',
      'sub_from_file_formats': 'SRT, VTT, ASS, SSA, SUB',
      'off': 'Kapalı',
      'season': 'Sezon',
      'no_episodes': 'Bu dizi için bölüm bulunamadı.',
      // ── Editor ──
      'editor': 'Düzenleyici',
      // ── General ──
      'loading': 'Yükleniyor…',
      'error': 'Hata',
      'no_channels': 'Kanal bulunamadı',
      'language': 'Dil',
      'turkish': 'Türkçe',
      'english': 'İngilizce',
      'kurdish': 'Kürtçe',
      'cancel': 'İptal',
      'ok': 'Tamam',
      'save': 'Kaydet',
      'delete': 'Sil',
      'close': 'Kapat',
      'confirm': 'Onayla',
      'copied_to_clipboard': 'Panoya kopyalandı',
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
      'retry': 'Retry',
      'now_playing': 'Now Playing',
      'coming_up': 'Coming Up',
      'channel_list': 'Channel List',
      'sleep_timer': 'Sleep Timer',
      'aspect_ratio': 'Aspect Ratio',
      'hours': 'hours',
      'minutes': 'minutes',
      'minutes_later_stop': 'minutes to stop',
      'part': 'track',
      'stream_subtitles': 'Stream Subtitles',
      'no_audio_tracks': 'No multiple audio tracks found in this stream',
      'no_upcoming': 'No upcoming programs for this channel.',
      'channel_of': 'channel',
      'track_of': 'track',
      'free_tv': 'Free TV',
      'add_source': 'Add Source',
      'url_playlist': 'Playlist URL',
      'xtream_codes': 'Xtream Codes',
      'file_m3u': 'Load M3U File',
      'epg': 'Program Guide',
      'connection_speed': 'Connection Speed',
      'source_added': 'channels loaded.',
      'load_error': 'Load error',
      'login_error': 'Login error',
      'connection_error': 'Connection error',
      'saved_source': 'Saved source',
      'remove': 'Remove',
      'load_url': 'Load from URL',
      'load_epg': 'Load EPG',
      'epg_url': 'EPG URL',
      'pick_file': 'Load M3U File',
      'pick_file_sub': 'Select M3U file from device',
      'free_legal': 'Free & Legal Channels',
      'free_legal_sub': 'Browse by country → category from iptv-org catalog',
      'free_hd': 'Free HD/4K streams',
      'loading_label': 'loading…',
      'loaded_label': 'loaded',
      'retry_button': 'Try again',
      'server': 'Server address',
      'username': 'Username',
      'password': 'Password',
      'login': 'Login',
      'connecting': 'Connecting…',
      'player': 'Player',
      'speed_desc': 'Channel switch speed and buffer time.',
      'epg_desc': 'Enter the XMLTV address from your provider.',
      'epg_loaded': 'programs loaded for channels.',
      'status': 'Status',
      'verified': 'Verifying channels…',
      'vod_needs_xtream': 'VOD requires an Xtream connection',
      'vod_xtream_hint': 'Add Xtream Codes login in Setup tab',
      'support': 'Support',
      'support_title': 'Support HermesTV',
      'support_desc': 'HermesTV is completely free and ad-free.\nYour support means a lot for continued development.',
      'github_sponsors': 'GitHub Sponsors',
      'github_sub': 'Support open source development',
      'support_on_github': 'Support on GitHub Sponsors',
      'copy_link': 'Copy Link',
      'copied': 'Link copied',
      'star_text': 'If you like this app, don\'t forget to give it a star!\nAll support motivates future development.',
      'sub_download_error': 'Could not download subtitle',
      'sub_search_open': 'Search on OpenSubtitles',
      'sub_search_desc': 'Find and load subtitles from the internet',
      'audio_tracks': 'Audio Tracks',
      'audio_tracks_avail': 'Available',
      'audio_tracks_dil': 'languages',
      'sub_from_file': 'Load subtitle from file',
      'sub_from_file_formats': 'SRT, VTT, ASS, SSA, SUB',
      'off': 'Off',
      'season': 'Season',
      'no_episodes': 'No episodes found for this series.',
      'editor': 'Editor',
      'loading': 'Loading…',
      'error': 'Error',
      'no_channels': 'No channels found',
      'language': 'Language',
      'turkish': 'Turkish',
      'english': 'English',
      'kurdish': 'Kurdish',
      'cancel': 'Cancel',
      'ok': 'OK',
      'save': 'Save',
      'delete': 'Delete',
      'close': 'Close',
      'confirm': 'Confirm',
      'copied_to_clipboard': 'Copied to clipboard',
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
      'retry': 'Dîsa ceribîne',
      'now_playing': 'Niha tê lêdan',
      'coming_up': 'Paşde tê',
      'channel_list': 'Lîsteya Kanal',
      'sleep_timer': 'Demjimara Rawestînê',
      'aspect_ratio': 'Qeta Ekranê',
      'hours': 'saet',
      'minutes': 'deqîqê',
      'minutes_later_stop': 'deqîqê paşde dibe',
      'part': 'xwarê',
      'stream_subtitles': 'Altyaziyên Avêtinê',
      'no_audio_tracks': 'Di vê avêtinê de gelek xwarên deng nehatin dîtin',
      'no_upcoming': 'Ji bo vê kanalê program nehatiye dîtin.',
      'channel_of': 'kanal',
      'track_of': 'xwarê',
      'free_tv': 'TV Bê Fecere',
      'add_source': 'Çavkani zêde bike',
      'url_playlist': 'URL Playlist',
      'xtream_codes': 'Xtream Codes',
      'file_m3u': 'Pel M3U barkirîne',
      'epg': 'Rêberê Bermânê',
      'connection_speed': 'Lezê Tenduristiyê',
      'source_added': 'kanal hat bardan.',
      'load_error': 'Çewtiya barkirinê',
      'login_error': 'Çewtiya têketinê',
      'connection_error': 'Çewtiya tenduristiya',
      'saved_source': 'Çavkani tomarkirî',
      'remove': 'Rakirîne',
      'load_url': 'Ji URL-ê barke',
      'load_epg': 'EPG barke',
      'epg_url': 'URL EPG',
      'pick_file': 'Pel M3U barkirîne',
      'pick_file_sub': 'Ji amûrê pel M3U hilbijêre',
      'free_legal': 'Kanal Bê Fecere û Yê Qanûnî',
      'free_legal_sub': 'Ji kataloqa iptv-org peyvên welat → kategori bijêre',
      'free_hd': 'Avêtinên HD/4K bê fecere',
      'loading_label': 'tê barkirin…',
      'loaded_label': 'hat bardan',
      'retry_button': 'Dîsa ceribîne',
      'server': 'Navnîşana serverê',
      'username': 'Navê Bikarhêner',
      'password': 'Nasnav',
      'login': 'Têkeve',
      'connecting': 'Tê tenduristîn…',
      'player': 'Lêdar',
      'speed_desc': 'Lezê guherîna kanal û demê tamponê.',
      'epg_desc': 'Navnîşana XMLTV jiProviderê binivîse.',
      'epg_loaded': 'program ji bo kanal hat bardan.',
      'status': 'Dûrîn',
      'verified': 'Kanal tê ceribandin…',
      'vod_needs_xtream': 'VOD pêwîstî tenduristiya Xtream e',
      'vod_xtream_hint': 'Di Sazkirin de têketinê Xtream Codes tebike',
      'support': 'Destek',
      'support_title': 'HermesTV-pê destek bike',
      'support_desc': 'HermesTV bi temamî bê fecere ye.\nDesteka we ji bo developmentê gelek生ser e.',
      'github_sponsors': 'GitHub Sponsors',
      'github_sub': 'Çandekîserî destek bike',
      'support_on_github': 'Di GitHub Sponsors de destek bike',
      'copy_link': 'Linki kopî bike',
      'copied': 'Link hat kopîkirin',
      'star_text': 'Heke vê sepan hûn vêkir, fêrka hûn fêmabike!\nHemû destek ji bo pêşveçûnê veguherîne.',
      'sub_download_error': 'Nikarî altyaziyê daxist',
      'sub_search_open': 'Di OpenSubtitles de bigere',
      'sub_search_desc': 'Di înternetê de altyazî bigere û barkirîne',
      'audio_tracks': 'Xwarên Deng',
      'audio_tracks_avail': 'Hene',
      'audio_tracks_dil': 'ziman',
      'sub_from_file': 'Altyazî ji pelê barke',
      'sub_from_file_formats': 'SRT, VTT, ASS, SSA, SUB',
      'off': 'Girtî',
      'season': 'Dîrok',
      'no_episodes': 'Ji bo vê dîzîyê bêhn nehatin dîtin.',
      'editor': 'Serasterek',
      'loading': 'Tê barkirin…',
      'error': 'Çewtî',
      'no_channels': 'Kanal nehat dîtin',
      'language': 'Ziman',
      'turkish': 'Tirkî',
      'english': 'Îngilîzî',
      'kurdish': 'Kurdî',
      'cancel': 'Betal bike',
      'ok': 'Temam',
      'save': 'Toabar bike',
      'delete': 'Jê bibe',
      'close': 'Bigre',
      'confirm': 'Pêşiroj bike',
      'copied_to_clipboard': 'Hat kopîkirin',
    },
  };

  String _t(String key) => _s[lang]?[key] ?? _s['en']?[key] ?? key;

  String get channels => _t('channels');
  String get vod => _t('vod');
  String get favorites => _t('favorites');
  String get donate => _t('donate');
  String get support => _t('donate');
  String get setup => _t('setup');
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
  String get retry => _t('retry');
  String get nowPlaying => _t('now_playing');
  String get comingUp => _t('coming_up');
  String get channelList => _t('channel_list');
  String get sleepTimer => _t('sleep_timer');
  String get aspectRatio => _t('aspect_ratio');
  String get hours => _t('hours');
  String get minutes => _t('minutes');
  String get minutesLaterStop => _t('minutes_later_stop');
  String get part => _t('part');
  String get streamSubtitles => _t('stream_subtitles');
  String get noAudioTracks => _t('no_audio_tracks');
  String get noUpcoming => _t('no_upcoming');
  String get channelOf => _t('channel_of');
  String get trackOf => _t('track_of');
  String get freeTv => _t('free_tv');
  String get addSource => _t('add_source');
  String get urlPlaylist => _t('url_playlist');
  String get xtreamCodes => _t('xtream_codes');
  String get fileM3u => _t('file_m3u');
  String get epg => _t('epg');
  String get connectionSpeed => _t('connection_speed');
  String sourceAdded(String n) => '$n ${_t('source_added')}';
  String get loadError => _t('load_error');
  String get loginError => _t('login_error');
  String get connectionError => _t('connection_error');
  String get savedSource => _t('saved_source');
  String get remove => _t('remove');
  String get loadUrl => _t('load_url');
  String get loadEpg => _t('load_epg');
  String get epgUrl => _t('epg_url');
  String get pickFile => _t('pick_file');
  String get pickFileSub => _t('pick_file_sub');
  String get freeLegal => _t('free_legal');
  String get freeLegalSub => _t('free_legal_sub');
  String get freeHd => _t('free_hd');
  String loadingLabel(String l) => '$l ${_t('loading_label')}';
  String loadedLabel(String l, String n) => '$l ${_t('loaded_label')}: $n ${_t('channel_of')}';
  String get retryButton => _t('retry_button');
  String get server => _t('server');
  String get username => _t('username');
  String get password => _t('password');
  String get login => _t('login');
  String get connecting => _t('connecting');
  String get player => _t('player');
  String get speedDesc => _t('speed_desc');
  String get epgDesc => _t('epg_desc');
  String epgLoaded(int n) => '$n ${_t('epg_loaded')}';
  String get status => _t('status');
  String get verified => _t('verified');
  String get vodNeedsXtream => _t('vod_needs_xtream');
  String get vodXtreamHint => _t('vod_xtream_hint');
  String get supportTitle => _t('support_title');
  String get supportDesc => _t('support_desc');
  String get githubSponsors => _t('github_sponsors');
  String get githubSub => _t('github_sub');
  String get supportOnGithub => _t('support_on_github');
  String get copyLink => _t('copy_link');
  String get copied => _t('copied');
  String get starText => _t('star_text');
  String get subDownloadError => _t('sub_download_error');
  String get subSearchOpen => _t('sub_search_open');
  String get subSearchDesc => _t('sub_search_desc');
  String get audioTracks => _t('audio_tracks');
  String get audioTracksAvail => _t('audio_tracks_avail');
  String get audioTracksDil => _t('audio_tracks_dil');
  String get subFromFile => _t('sub_from_file');
  String get subFromFileFormats => _t('sub_from_file_formats');
  String get off => _t('off');
  String seasonN(int n) => '${_t('season')} $n';
  String get noEpisodes => _t('no_episodes');
  String get loading => _t('loading');
  String get error => _t('error');
  String get noChannels => _t('no_channels');
  String get language => _t('language');
  String get turkish => _t('turkish');
  String get english => _t('english');
  String get kurdish => _t('kurdish');
  String get cancel => _t('cancel');
  String get ok => _t('ok');
  String get save => _t('save');
  String get delete => _t('delete');
  String get close => _t('close');
  String get confirm => _t('confirm');
  String get copiedToClipboard => _t('copied_to_clipboard');
  String get editor => _t('editor');
}

AppLocalizations loc(String lang) => AppLocalizations(lang);
const supportedLocales = ['tr', 'en', 'ku'];
/// Kürdistan Bölgesel Yönetimi bayrağı — Unicode tag sequence (IR-16).
const kuFlag = '🏴󠁩󠁲󠀱󠀶󠁿';

const localeLabels = {
  'tr': '🇹🇷 Türkçe',
  'en': '🇬🇧 English',
  'ku': '$kuFlag Kurdî',
};

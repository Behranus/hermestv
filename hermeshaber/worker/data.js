// HermesHaber — kaynak, bölge, kategori ve radyo kataloğu.
// Kaynakların tamamı doğrulanmış RSS/Atom adresleri; her biri güvenilir
// ana akım kuruluşlardan seçildi (haber ajansları, kamu yayıncıları, büyük gazeteler).

// category: 'world' (gündem akışı) ya da konu akışı:
// politics | business | tech | sport | culture | science | health | climate
export const SOURCES = [
  // ---------------- Avrupa ----------------
  { id: 'bbc-world', name: 'BBC News', country: 'Birleşik Krallık', flag: '🇬🇧', region: 'europe', lang: 'en', category: 'world', url: 'https://feeds.bbci.co.uk/news/world/rss.xml' },
  { id: 'guardian-world', name: 'The Guardian', country: 'Birleşik Krallık', flag: '🇬🇧', region: 'europe', lang: 'en', category: 'world', url: 'https://www.theguardian.com/world/rss' },
  { id: 'lemonde', name: 'Le Monde', country: 'Fransa', flag: '🇫🇷', region: 'europe', lang: 'fr', category: 'world', url: 'https://www.lemonde.fr/rss/une.xml' },
  { id: 'lemonde-intl', name: 'Le Monde International', country: 'Fransa', flag: '🇫🇷', region: 'europe', lang: 'fr', category: 'world', url: 'https://www.lemonde.fr/international/rss_full.xml' },
  { id: 'spiegel', name: 'Der Spiegel', country: 'Almanya', flag: '🇩🇪', region: 'europe', lang: 'en', category: 'world', url: 'https://www.spiegel.de/international/index.rss' },
  { id: 'spiegel-politik', name: 'Spiegel Politik', country: 'Almanya', flag: '🇩🇪', region: 'europe', lang: 'de', category: 'world', url: 'https://www.spiegel.de/politik/index.rss' },
  { id: 'elpais', name: 'El País', country: 'İspanya', flag: '🇪🇸', region: 'europe', lang: 'es', category: 'world', url: 'https://feeds.elpais.com/mrss-s/pages/ep/site/elpais.com/portada' },
  { id: 'ansa', name: 'ANSA', country: 'İtalya', flag: '🇮🇹', region: 'europe', lang: 'it', category: 'world', url: 'https://www.ansa.it/sito/notizie/topnews/topnews_rss.xml' },
  { id: 'dw-world', name: 'DW', country: 'Almanya', flag: '🇩🇪', region: 'europe', lang: 'en', category: 'world', url: 'https://rss.dw.com/rdf/rss-en-world' },
  { id: 'euronews', name: 'Euronews', country: 'Avrupa', flag: '🇪🇺', region: 'europe', lang: 'en', category: 'world', url: 'https://www.euronews.com/rss?level=theme&name=news' },
  { id: 'france24-en', name: 'France 24', country: 'Fransa', flag: '🇫🇷', region: 'europe', lang: 'en', category: 'world', url: 'https://www.france24.com/en/rss' },
  { id: 'skynews', name: 'Sky News', country: 'Birleşik Krallık', flag: '🇬🇧', region: 'europe', lang: 'en', category: 'world', url: 'https://feeds.skynews.com/feeds/rss/world.xml' },
  { id: 'nos-nl', name: 'NOS', country: 'Hollanda', flag: '🇳🇱', region: 'europe', lang: 'nl', category: 'world', url: 'https://feeds.nos.nl/nosnieuwsalgemeen' },
  { id: 'svt-se', name: 'SVT Nyheter', country: 'İsveç', flag: '🇸🇪', region: 'europe', lang: 'sv', category: 'world', url: 'https://www.svt.se/nyheter/rss.xml' },
  { id: 'notesfrompoland', name: 'Notes from Poland', country: 'Polonya', flag: '🇵🇱', region: 'europe', lang: 'en', category: 'world', url: 'https://notesfrompoland.com/feed/' },
  { id: 'irishtimes', name: 'The Irish Times', country: 'İrlanda', flag: '🇮🇪', region: 'europe', lang: 'en', category: 'world', url: 'https://www.irishtimes.com/arc/outboundfeeds/rss/?outputType=xml' },
  { id: 'politico-eu', name: 'Politico Europe', country: 'Avrupa', flag: '🇪🇺', region: 'europe', lang: 'en', category: 'world', url: 'https://www.politico.eu/feed/' },

  // ---------------- ABD ----------------
  { id: 'nytimes-world', name: 'The New York Times', country: 'ABD', flag: '🇺🇸', region: 'usa', lang: 'en', category: 'world', url: 'https://rss.nytimes.com/services/xml/rss/nyt/World.xml' },
  { id: 'cnn-world', name: 'CNN', country: 'ABD', flag: '🇺🇸', region: 'usa', lang: 'en', category: 'world', url: 'http://rss.cnn.com/rss/cnn_world.rss' },
  { id: 'npr-world', name: 'NPR', country: 'ABD', flag: '🇺🇸', region: 'usa', lang: 'en', category: 'world', url: 'https://feeds.npr.org/1004/rss.xml' },
  { id: 'wapo-world', name: 'The Washington Post', country: 'ABD', flag: '🇺🇸', region: 'usa', lang: 'en', category: 'world', url: 'https://feeds.washingtonpost.com/rss/world' },
  { id: 'fox-world', name: 'Fox News', country: 'ABD', flag: '🇺🇸', region: 'usa', lang: 'en', category: 'world', url: 'https://moxie.foxnews.com/google-publisher/world.xml' },
  { id: 'abcnews', name: 'ABC News', country: 'ABD', flag: '🇺🇸', region: 'usa', lang: 'en', category: 'world', url: 'https://abcnews.go.com/abcnews/topstories' },
  { id: 'latimes', name: 'Los Angeles Times', country: 'ABD', flag: '🇺🇸', region: 'usa', lang: 'en', category: 'world', url: 'https://www.latimes.com/world-nation/rss2.0.xml' },
  { id: 'politico-us', name: 'Politico', country: 'ABD', flag: '🇺🇸', region: 'usa', lang: 'en', category: 'world', url: 'https://rss.politico.com/politics-news.xml' },
  { id: 'thehill', name: 'The Hill', country: 'ABD', flag: '🇺🇸', region: 'usa', lang: 'en', category: 'world', url: 'https://thehill.com/feed/' },

  // ---------------- Kanada ----------------
  { id: 'cbc-world', name: 'CBC News', country: 'Kanada', flag: '🇨🇦', region: 'canada', lang: 'en', category: 'world', url: 'https://www.cbc.ca/webfeed/rss/rss-world' },
  { id: 'globe-mail', name: 'The Globe and Mail', country: 'Kanada', flag: '🇨🇦', region: 'canada', lang: 'en', category: 'world', url: 'https://www.theglobeandmail.com/arc/outboundfeeds/rss/category/world/?outputType=xml' },
  { id: 'radiocanada', name: 'Radio-Canada', country: 'Kanada', flag: '🇨🇦', region: 'canada', lang: 'fr', category: 'world', url: 'https://ici.radio-canada.ca/rss/4159' },

  // ---------------- Latin Amerika ----------------
  { id: 'folha-mundo', name: 'Folha de S.Paulo', country: 'Brezilya', flag: '🇧🇷', region: 'latam', lang: 'pt', category: 'world', url: 'https://feeds.folha.uol.com.br/mundo/rss091.xml' },
  { id: 'oglobo-mundo', name: 'O Globo', country: 'Brezilya', flag: '🇧🇷', region: 'latam', lang: 'pt', category: 'world', url: 'https://oglobo.globo.com/rss/oglobo/mundo/' },
  { id: 'lanacion-ar', name: 'La Nación', country: 'Arjantin', flag: '🇦🇷', region: 'latam', lang: 'es', category: 'world', url: 'https://www.lanacion.com.ar/arc/outboundfeeds/rss/?outputType=xml' },
  { id: 'eltiempo-co', name: 'El Tiempo', country: 'Kolombiya', flag: '🇨🇴', region: 'latam', lang: 'es', category: 'world', url: 'https://www.eltiempo.com/rss/mundo.xml' },
  { id: 'elcomercio-pe', name: 'El Comercio', country: 'Peru', flag: '🇵🇪', region: 'latam', lang: 'es', category: 'world', url: 'https://elcomercio.pe/arc/outboundfeeds/rss/?outputType=xml' },
  { id: 'latercera-cl', name: 'La Tercera', country: 'Şili', flag: '🇨🇱', region: 'latam', lang: 'es', category: 'world', url: 'https://www.latercera.com/arc/outboundfeeds/rss/?outputType=xml' },
  { id: 'elnacional-ve', name: 'El Nacional', country: 'Venezuela', flag: '🇻🇪', region: 'latam', lang: 'es', category: 'world', url: 'https://www.elnacional.com/feed/' },
  { id: 'bbcmundo', name: 'BBC Mundo', country: 'Birleşik Krallık', flag: '🇬🇧', region: 'latam', lang: 'es', category: 'world', url: 'https://feeds.bbci.co.uk/mundo/rss.xml' },
  { id: 'france24-es', name: 'France 24 Español', country: 'Fransa', flag: '🇫🇷', region: 'latam', lang: 'es', category: 'world', url: 'https://www.france24.com/es/rss' },

  // ---------------- Afrika ----------------
  { id: 'allafrica', name: 'AllAfrica', country: 'Afrika', flag: '🌍', region: 'africa', lang: 'en', category: 'world', url: 'https://allafrica.com/tools/headlines/rdf/latest/headlines.rdf' },
  { id: 'premiumtimes', name: 'Premium Times', country: 'Nijerya', flag: '🇳🇬', region: 'africa', lang: 'en', category: 'world', url: 'https://www.premiumtimesng.com/feed' },
  { id: 'punch-ng', name: 'The Punch', country: 'Nijerya', flag: '🇳🇬', region: 'africa', lang: 'en', category: 'world', url: 'https://punchng.com/feed/' },
  { id: 'myjoyonline', name: 'MyJoyOnline', country: 'Gana', flag: '🇬🇭', region: 'africa', lang: 'en', category: 'world', url: 'https://www.myjoyonline.com/feed/' },
  { id: 'standardmedia-ke', name: 'The Standard', country: 'Kenya', flag: '🇰🇪', region: 'africa', lang: 'en', category: 'world', url: 'https://www.standardmedia.co.ke/rss/headlines.php' },
  { id: 'africareport', name: 'The Africa Report', country: 'Afrika', flag: '🌍', region: 'africa', lang: 'en', category: 'world', url: 'https://www.theafricareport.com/feed/' },
  { id: 'jeuneafrique', name: 'Jeune Afrique', country: 'Fransa', flag: '🇫🇷', region: 'africa', lang: 'fr', category: 'world', url: 'https://www.jeuneafrique.com/feed/' },
  { id: 'rfi-afrique', name: 'RFI Afrique', country: 'Fransa', flag: '🇫🇷', region: 'africa', lang: 'fr', category: 'world', url: 'https://www.rfi.fr/fr/afrique/rss' },
  { id: 'egyptindependent', name: 'Egypt Independent', country: 'Mısır', flag: '🇪🇬', region: 'africa', lang: 'en', category: 'world', url: 'https://egyptindependent.com/feed/' },
  { id: 'bbc-africa', name: 'BBC Africa', country: 'Birleşik Krallık', flag: '🇬🇧', region: 'africa', lang: 'en', category: 'world', url: 'https://feeds.bbci.co.uk/news/world/africa/rss.xml' },

  // ---------------- Orta Doğu ----------------
  { id: 'aljazeera-ar', name: 'Al Jazeera', country: 'Katar', flag: '🇶🇦', region: 'middleeast', lang: 'ar', category: 'world', url: 'https://www.aljazeera.net/aljazeerarss/a7c186be-1baa-4bd4-9d80-a84db769f779/73d0e1b4-532f-45ef-b135-bfdff8b8cab9' },
  { id: 'bbc-arabic', name: 'BBC Arabic', country: 'Birleşik Krallık', flag: '🇬🇧', region: 'middleeast', lang: 'ar', category: 'world', url: 'https://feeds.bbci.co.uk/arabic/rss.xml' },
  { id: 'dw-arabic', name: 'DW Arapça', country: 'Almanya', flag: '🇩🇪', region: 'middleeast', lang: 'ar', category: 'world', url: 'https://rss.dw.com/rdf/rss-ar-all' },
  { id: 'france24-arabic', name: 'France 24 Arapça', country: 'Fransa', flag: '🇫🇷', region: 'middleeast', lang: 'ar', category: 'world', url: 'https://www.france24.com/ar/rss' },
  { id: 'cnn-arabic', name: 'CNN Arabic', country: 'BAE', flag: '🇦🇪', region: 'middleeast', lang: 'ar', category: 'world', url: 'https://arabic.cnn.com/api/v1/rss/rss.xml' },
  { id: 'rt-arabic', name: 'RT Arabic', country: 'Rusya', flag: '🇷🇺', region: 'middleeast', lang: 'ar', category: 'world', url: 'https://rtarabic.com/rss/' },
  { id: 'aljazeera-en', name: 'Al Jazeera English', country: 'Katar', flag: '🇶🇦', region: 'middleeast', lang: 'en', category: 'world', url: 'https://www.aljazeera.com/xml/rss/all.xml' },
  { id: 'aawsat', name: 'Asharq Al-Awsat', country: 'Suudi Arabistan', flag: '🇸🇦', region: 'middleeast', lang: 'ar', category: 'world', url: 'https://aawsat.com/feed' },
  { id: 'middleeasteye', name: 'Middle East Eye', country: 'Birleşik Krallık', flag: '🇬🇧', region: 'middleeast', lang: 'en', category: 'world', url: 'https://www.middleeasteye.net/rss' },
  { id: 'thenational-ae', name: 'The National', country: 'BAE', flag: '🇦🇪', region: 'middleeast', lang: 'en', category: 'world', url: 'https://www.thenationalnews.com/arc/outboundfeeds/rss/?outputType=xml' },
  { id: 'iranintl', name: 'Iran International', country: 'İran', flag: '🇮🇷', region: 'middleeast', lang: 'en', category: 'world', url: 'https://www.iranintl.com/feed' },
  { id: 'al-monitor', name: 'Al-Monitor', country: 'ABD', flag: '🇺🇸', region: 'middleeast', lang: 'en', category: 'world', url: 'https://www.al-monitor.com/rss' },

  // ---------------- Türkiye ----------------
  { id: 'bbcturkce', name: 'BBC Türkçe', country: 'Türkiye', flag: '🇹🇷', region: 'turkey', lang: 'tr', category: 'world', url: 'https://feeds.bbci.co.uk/turkce/rss.xml' },
  { id: 'euronews-tr', name: 'Euronews Türkçe', country: 'Türkiye', flag: '🇹🇷', region: 'turkey', lang: 'tr', category: 'world', url: 'https://tr.euronews.com/rss' },
  { id: 'sozcu', name: 'Sözcü', country: 'Türkiye', flag: '🇹🇷', region: 'turkey', lang: 'tr', category: 'world', url: 'https://www.sozcu.com.tr/feeds-rss-category-gundem' },
  { id: 'hurriyet', name: 'Hürriyet', country: 'Türkiye', flag: '🇹🇷', region: 'turkey', lang: 'tr', category: 'world', url: 'https://www.hurriyet.com.tr/rss/anasayfa' },
  { id: 'milliyet', name: 'Milliyet', country: 'Türkiye', flag: '🇹🇷', region: 'turkey', lang: 'tr', category: 'world', url: 'https://www.milliyet.com.tr/rss/rssNew/gundemRss.xml' },
  { id: 'gazeteduvar', name: 'Gazete Duvar', country: 'Türkiye', flag: '🇹🇷', region: 'turkey', lang: 'tr', category: 'world', url: 'https://gazeteduvar.com.tr/rss' },

  // ---------------- Çin ----------------
  { id: 'globaltimes', name: 'Global Times', country: 'Çin', flag: '🇨🇳', region: 'china', lang: 'en', category: 'world', url: 'https://www.globaltimes.cn/rss/outbrain.xml' },
  { id: 'cgtn', name: 'CGTN', country: 'Çin', flag: '🇨🇳', region: 'china', lang: 'en', category: 'world', url: 'https://www.cgtn.com/subscribe/rss/section/world.xml' },
  { id: 'cgtn-china', name: 'CGTN Çin', country: 'Çin', flag: '🇨🇳', region: 'china', lang: 'en', category: 'world', url: 'https://www.cgtn.com/subscribe/rss/section/china.xml' },
  { id: 'scmp', name: 'South China Morning Post', country: 'Hong Kong', flag: '🇭🇰', region: 'china', lang: 'en', category: 'world', url: 'https://www.scmp.com/rss/91/feed' },
  { id: 'sixthtone', name: 'Sixth Tone', country: 'Çin', flag: '🇨🇳', region: 'china', lang: 'en', category: 'world', url: 'https://www.sixthtone.com/rss' },

  // ---------------- Rusya ----------------
  { id: 'tass', name: 'TASS', country: 'Rusya', flag: '🇷🇺', region: 'russia', lang: 'en', category: 'world', url: 'https://tass.com/rss/v2.xml' },
  { id: 'moscowtimes', name: 'The Moscow Times', country: 'Rusya', flag: '🇷🇺', region: 'russia', lang: 'en', category: 'world', url: 'https://www.themoscowtimes.com/rss/news' },
  { id: 'meduza', name: 'Meduza', country: 'Rusya', flag: '🇷🇺', region: 'russia', lang: 'en', category: 'world', url: 'https://meduza.io/rss/en/all' },
  { id: 'kommersant', name: 'Kommersant', country: 'Rusya', flag: '🇷🇺', region: 'russia', lang: 'ru', category: 'world', url: 'https://www.kommersant.ru/RSS/news.xml' },
  { id: 'ria', name: 'RIA Novosti', country: 'Rusya', flag: '🇷🇺', region: 'russia', lang: 'ru', category: 'world', url: 'https://ria.ru/export/rss2/archive/index.xml' },
  { id: 'rt-english', name: 'RT', country: 'Rusya', flag: '🇷🇺', region: 'russia', lang: 'en', category: 'world', url: 'https://rt-english.com/rss/news/' },

  // ---------------- Güney Asya ----------------
  { id: 'thehindu', name: 'The Hindu', country: 'Hindistan', flag: '🇮🇳', region: 'southasia', lang: 'en', category: 'world', url: 'https://www.thehindu.com/news/international/feeder/default.rss' },
  { id: 'indianexpress', name: 'The Indian Express', country: 'Hindistan', flag: '🇮🇳', region: 'southasia', lang: 'en', category: 'world', url: 'https://indianexpress.com/section/world/feed/' },
  { id: 'timesofindia', name: 'The Times of India', country: 'Hindistan', flag: '🇮🇳', region: 'southasia', lang: 'en', category: 'world', url: 'https://timesofindia.indiatimes.com/rssfeeds/296589292.cms' },
  { id: 'hindustantimes', name: 'Hindustan Times', country: 'Hindistan', flag: '🇮🇳', region: 'southasia', lang: 'en', category: 'world', url: 'https://www.hindustantimes.com/feeds/rss/world-news/rssfeed.xml' },
  { id: 'dawn', name: 'Dawn', country: 'Pakistan', flag: '🇵🇰', region: 'southasia', lang: 'en', category: 'world', url: 'https://www.dawn.com/feeds/home' },
  { id: 'tribune-pk', name: 'The Express Tribune', country: 'Pakistan', flag: '🇵🇰', region: 'southasia', lang: 'en', category: 'world', url: 'https://tribune.com.pk/feed/world' },
  { id: 'dailystar-bd', name: 'The Daily Star', country: 'Bangladeş', flag: '🇧🇩', region: 'southasia', lang: 'en', category: 'world', url: 'https://www.thedailystar.net/frontpage/rss.xml' },
  { id: 'kathmandupost', name: 'The Kathmandu Post', country: 'Nepal', flag: '🇳🇵', region: 'southasia', lang: 'en', category: 'world', url: 'https://kathmandupost.com/rss' },
  { id: 'theisland-lk', name: 'The Island', country: 'Sri Lanka', flag: '🇱🇰', region: 'southasia', lang: 'en', category: 'world', url: 'https://island.lk/feed/' },

  // ---------------- Doğu Asya ----------------
  { id: 'japantimes', name: 'The Japan Times', country: 'Japonya', flag: '🇯🇵', region: 'eastasia', lang: 'en', category: 'world', url: 'https://www.japantimes.co.jp/feed/' },
  { id: 'koreaherald', name: 'The Korea Herald', country: 'Güney Kore', flag: '🇰🇷', region: 'eastasia', lang: 'en', category: 'world', url: 'https://www.koreaherald.com/rss/newsAll' },
  { id: 'yonhap', name: 'Yonhap', country: 'Güney Kore', flag: '🇰🇷', region: 'eastasia', lang: 'en', category: 'world', url: 'https://en.yna.co.kr/RSS/news.xml' },
  { id: 'taipeitimes', name: 'Taipei Times', country: 'Tayvan', flag: '🇹🇼', region: 'eastasia', lang: 'en', category: 'world', url: 'https://www.taipeitimes.com/xml/index.rss' },
  { id: 'nikkei', name: 'Nikkei Asia', country: 'Japonya', flag: '🇯🇵', region: 'eastasia', lang: 'en', category: 'world', url: 'https://asia.nikkei.com/rss/feed/nar' },

  // ---------------- Güneydoğu Asya ----------------
  { id: 'straitstimes', name: 'The Straits Times', country: 'Singapur', flag: '🇸🇬', region: 'seasia', lang: 'en', category: 'world', url: 'https://www.straitstimes.com/news/world/rss.xml' },
  { id: 'cna', name: 'CNA', country: 'Singapur', flag: '🇸🇬', region: 'seasia', lang: 'en', category: 'world', url: 'https://www.channelnewsasia.com/api/v1/rss-outbound-feed?_format=xml' },
  { id: 'bangkokpost', name: 'Bangkok Post', country: 'Tayland', flag: '🇹🇭', region: 'seasia', lang: 'en', category: 'world', url: 'https://www.bangkokpost.com/rss/data/topstories.xml' },
  { id: 'vnexpress', name: 'VnExpress', country: 'Vietnam', flag: '🇻🇳', region: 'seasia', lang: 'en', category: 'world', url: 'https://e.vnexpress.net/rss/news.rss' },
  { id: 'rappler', name: 'Rappler', country: 'Filipinler', flag: '🇵🇭', region: 'seasia', lang: 'en', category: 'world', url: 'https://www.rappler.com/feed/' },
  { id: 'malaysiakini', name: 'Malaysiakini', country: 'Malezya', flag: '🇲🇾', region: 'seasia', lang: 'en', category: 'world', url: 'https://www.malaysiakini.com/rss/en/news.rss' },

  // ---------------- Okyanusya ----------------
  { id: 'abc-au', name: 'ABC News', country: 'Avustralya', flag: '🇦🇺', region: 'oceania', lang: 'en', category: 'world', url: 'https://www.abc.net.au/news/feed/51120/rss.xml' },
  { id: 'smh', name: 'The Sydney Morning Herald', country: 'Avustralya', flag: '🇦🇺', region: 'oceania', lang: 'en', category: 'world', url: 'https://www.smh.com.au/rss/world.xml' },
  { id: 'theage', name: 'The Age', country: 'Avustralya', flag: '🇦🇺', region: 'oceania', lang: 'en', category: 'world', url: 'https://www.theage.com.au/rss/world.xml' },
  { id: 'guardian-au', name: 'The Guardian Australia', country: 'Avustralya', flag: '🇦🇺', region: 'oceania', lang: 'en', category: 'world', url: 'https://www.theguardian.com/au/rss' },
  { id: 'sbs-au', name: 'SBS News', country: 'Avustralya', flag: '🇦🇺', region: 'oceania', lang: 'en', category: 'world', url: 'https://www.sbs.com.au/news/feed' },
  { id: 'rnz', name: 'RNZ', country: 'Yeni Zelanda', flag: '🇳🇿', region: 'oceania', lang: 'en', category: 'world', url: 'https://www.rnz.co.nz/rss/world.xml' },

  // ---------------- Siyaset ----------------
  { id: 'bbc-politics', name: 'BBC Siyaset', country: 'Birleşik Krallık', flag: '🇬🇧', region: 'europe', lang: 'en', category: 'politics', url: 'https://feeds.bbci.co.uk/news/politics/rss.xml' },
  { id: 'nyt-politics', name: 'NYT Politics', country: 'ABD', flag: '🇺🇸', region: 'usa', lang: 'en', category: 'politics', url: 'https://rss.nytimes.com/services/xml/rss/nyt/Politics.xml' },
  { id: 'lemonde-politique', name: 'Le Monde Politique', country: 'Fransa', flag: '🇫🇷', region: 'europe', lang: 'fr', category: 'politics', url: 'https://www.lemonde.fr/politique/rss_full.xml' },
  { id: 'spiegel-ausland', name: 'Spiegel Ausland', country: 'Almanya', flag: '🇩🇪', region: 'europe', lang: 'de', category: 'politics', url: 'https://www.spiegel.de/ausland/index.rss' },
  { id: 'ansa-politica', name: 'ANSA Politica', country: 'İtalya', flag: '🇮🇹', region: 'europe', lang: 'it', category: 'politics', url: 'https://www.ansa.it/sito/notizie/politica/politica_rss.xml' },
  { id: 'elpais-intl', name: 'El País Internacional', country: 'İspanya', flag: '🇪🇸', region: 'europe', lang: 'es', category: 'politics', url: 'https://feeds.elpais.com/mrss-s/pages/ep/site/elpais.com/section/internacional/portada' },

  // ---------------- Ekonomi ----------------
  { id: 'bbc-business', name: 'BBC Business', country: 'Birleşik Krallık', flag: '🇬🇧', region: 'europe', lang: 'en', category: 'business', url: 'https://feeds.bbci.co.uk/news/business/rss.xml' },
  { id: 'guardian-business', name: 'The Guardian Business', country: 'Birleşik Krallık', flag: '🇬🇧', region: 'europe', lang: 'en', category: 'business', url: 'https://www.theguardian.com/uk/business/rss' },
  { id: 'nyt-business', name: 'NYT Business', country: 'ABD', flag: '🇺🇸', region: 'usa', lang: 'en', category: 'business', url: 'https://rss.nytimes.com/services/xml/rss/nyt/Business.xml' },
  { id: 'spiegel-wirtschaft', name: 'Spiegel Wirtschaft', country: 'Almanya', flag: '🇩🇪', region: 'europe', lang: 'de', category: 'business', url: 'https://www.spiegel.de/wirtschaft/index.rss' },
  { id: 'lemonde-eco', name: 'Le Monde Économie', country: 'Fransa', flag: '🇫🇷', region: 'europe', lang: 'fr', category: 'business', url: 'https://www.lemonde.fr/economie/rss_full.xml' },

  // ---------------- Teknoloji ----------------
  { id: 'bbc-tech', name: 'BBC Technology', country: 'Birleşik Krallık', flag: '🇬🇧', region: 'europe', lang: 'en', category: 'tech', url: 'https://feeds.bbci.co.uk/news/technology/rss.xml' },
  { id: 'guardian-tech', name: 'The Guardian Tech', country: 'Birleşik Krallık', flag: '🇬🇧', region: 'europe', lang: 'en', category: 'tech', url: 'https://www.theguardian.com/uk/technology/rss' },
  { id: 'nyt-tech', name: 'NYT Technology', country: 'ABD', flag: '🇺🇸', region: 'usa', lang: 'en', category: 'tech', url: 'https://rss.nytimes.com/services/xml/rss/nyt/Technology.xml' },
  { id: 'lemonde-pixels', name: 'Le Monde Pixels', country: 'Fransa', flag: '🇫🇷', region: 'europe', lang: 'fr', category: 'tech', url: 'https://www.lemonde.fr/pixels/rss_full.xml' },
  { id: 'spiegel-netzwelt', name: 'Spiegel Netzwelt', country: 'Almanya', flag: '🇩🇪', region: 'europe', lang: 'de', category: 'tech', url: 'https://www.spiegel.de/netzwelt/index.rss' },
  { id: 'hindustantimes-tech', name: 'HT Tech', country: 'Hindistan', flag: '🇮🇳', region: 'southasia', lang: 'en', category: 'tech', url: 'https://www.hindustantimes.com/feeds/rss/technology/rssfeed.xml' },

  // ---------------- Spor ----------------
  { id: 'bbc-sport', name: 'BBC Sport', country: 'Birleşik Krallık', flag: '🇬🇧', region: 'europe', lang: 'en', category: 'sport', url: 'https://feeds.bbci.co.uk/sport/rss.xml' },
  { id: 'guardian-sport', name: 'The Guardian Sport', country: 'Birleşik Krallık', flag: '🇬🇧', region: 'europe', lang: 'en', category: 'sport', url: 'https://www.theguardian.com/uk/sport/rss' },
  { id: 'lemonde-sport', name: 'Le Monde Sport', country: 'Fransa', flag: '🇫🇷', region: 'europe', lang: 'fr', category: 'sport', url: 'https://www.lemonde.fr/sport/rss_full.xml' },
  { id: 'ansa-sport', name: 'ANSA Sport', country: 'İtalya', flag: '🇮🇹', region: 'europe', lang: 'it', category: 'sport', url: 'https://www.ansa.it/sito/notizie/sport/sport_rss.xml' },

  // ---------------- Kültür ----------------
  { id: 'bbc-culture', name: 'BBC Kültür', country: 'Birleşik Krallık', flag: '🇬🇧', region: 'europe', lang: 'en', category: 'culture', url: 'https://feeds.bbci.co.uk/news/entertainment_and_arts/rss.xml' },
  { id: 'guardian-culture', name: 'The Guardian Kültür', country: 'Birleşik Krallık', flag: '🇬🇧', region: 'europe', lang: 'en', category: 'culture', url: 'https://www.theguardian.com/uk/culture/rss' },
  { id: 'nyt-arts', name: 'NYT Arts', country: 'ABD', flag: '🇺🇸', region: 'usa', lang: 'en', category: 'culture', url: 'https://rss.nytimes.com/services/xml/rss/nyt/Arts.xml' },
  { id: 'lemonde-culture', name: 'Le Monde Culture', country: 'Fransa', flag: '🇫🇷', region: 'europe', lang: 'fr', category: 'culture', url: 'https://www.lemonde.fr/culture/rss_full.xml' },

  // ---------------- Bilim ----------------
  { id: 'bbc-science', name: 'BBC Bilim', country: 'Birleşik Krallık', flag: '🇬🇧', region: 'europe', lang: 'en', category: 'science', url: 'https://feeds.bbci.co.uk/news/science_and_environment/rss.xml' },
  { id: 'nyt-science', name: 'NYT Science', country: 'ABD', flag: '🇺🇸', region: 'usa', lang: 'en', category: 'science', url: 'https://rss.nytimes.com/services/xml/rss/nyt/Science.xml' },
  { id: 'spiegel-wissenschaft', name: 'Spiegel Wissenschaft', country: 'Almanya', flag: '🇩🇪', region: 'europe', lang: 'de', category: 'science', url: 'https://www.spiegel.de/wissenschaft/index.rss' },
  { id: 'sciencedaily', name: 'ScienceDaily', country: 'ABD', flag: '🇺🇸', region: 'usa', lang: 'en', category: 'science', url: 'https://www.sciencedaily.com/rss/top/science.xml' },

  // ---------------- Sağlık ----------------
  { id: 'bbc-health', name: 'BBC Sağlık', country: 'Birleşik Krallık', flag: '🇬🇧', region: 'europe', lang: 'en', category: 'health', url: 'https://feeds.bbci.co.uk/news/health/rss.xml' },
  { id: 'nyt-health', name: 'NYT Health', country: 'ABD', flag: '🇺🇸', region: 'usa', lang: 'en', category: 'health', url: 'https://rss.nytimes.com/services/xml/rss/nyt/Health.xml' },

  // ---------------- İklim ----------------
  { id: 'guardian-climate', name: 'Guardian İklim', country: 'Birleşik Krallık', flag: '🇬🇧', region: 'europe', lang: 'en', category: 'climate', url: 'https://www.theguardian.com/environment/climate-crisis/rss' },
  { id: 'nyt-climate', name: 'NYT Climate', country: 'ABD', flag: '🇺🇸', region: 'usa', lang: 'en', category: 'climate', url: 'https://rss.nytimes.com/services/xml/rss/nyt/Climate.xml' },
];

export const REGIONS = [
  { id: 'all', label: 'Tümü', icon: '🌐' },
  { id: 'europe', label: 'Avrupa', icon: '🇪🇺' },
  { id: 'usa', label: 'ABD', icon: '🇺🇸' },
  { id: 'canada', label: 'Kanada', icon: '🇨🇦' },
  { id: 'latam', label: 'Latin Amerika', icon: '🌎' },
  { id: 'africa', label: 'Afrika', icon: '🌍' },
  { id: 'middleeast', label: 'Orta Doğu', icon: '🕌' },
  { id: 'turkey', label: 'Türkiye', icon: '🇹🇷' },
  { id: 'china', label: 'Çin', icon: '🇨🇳' },
  { id: 'russia', label: 'Rusya', icon: '🇷🇺' },
  { id: 'southasia', label: 'Güney Asya', icon: '🇮🇳' },
  { id: 'eastasia', label: 'Doğu Asya', icon: '🇯🇵' },
  { id: 'seasia', label: 'Güneydoğu Asya', icon: '🇸🇬' },
  { id: 'oceania', label: 'Okyanusya', icon: '🇦🇺' },
];

export const CATEGORIES = [
  { id: 'all', label: 'Gündem', icon: '📰' },
  { id: 'politics', label: 'Siyaset', icon: '🏛️' },
  { id: 'business', label: 'Ekonomi', icon: '📈' },
  { id: 'tech', label: 'Teknoloji', icon: '💻' },
  { id: 'science', label: 'Bilim', icon: '🔬' },
  { id: 'health', label: 'Sağlık', icon: '🩺' },
  { id: 'climate', label: 'İklim', icon: '🌱' },
  { id: 'sport', label: 'Spor', icon: '⚽' },
  { id: 'culture', label: 'Kültür', icon: '🎭' },
];

// ---------------- radyo ----------------
// Öne çıkan kamu yayıncıları (hepsi HTTPS, doğrudan MP3/AAC akışı).
export const RADIO_FEATURED = [
  { id: 'bbc-ws', name: 'BBC World Service', country: 'Birleşik Krallık', flag: '🇬🇧', genre: 'Haber', url: 'https://stream.live.vc.bbcmedia.co.uk/bbc_world_service', site: 'https://www.bbc.co.uk/worldserviceradio' },
  { id: 'npr', name: 'NPR News', country: 'ABD', flag: '🇺🇸', genre: 'Haber', url: 'https://npr-ice.streamguys1.com/live.mp3', site: 'https://www.npr.org' },
  { id: 'wnyc', name: 'WNYC', country: 'ABD', flag: '🇺🇸', genre: 'Haber & Kültür', url: 'https://fm939.wnyc.org/wnycfm', site: 'https://www.wnyc.org' },
  { id: 'wbez', name: 'WBEZ Chicago', country: 'ABD', flag: '🇺🇸', genre: 'Haber', url: 'https://wbez.streamguys1.com/wbez128.mp3', site: 'https://www.wbez.org' },
  { id: 'kexp', name: 'KEXP', country: 'ABD', flag: '🇺🇸', genre: 'Alternatif', url: 'https://kexp.streamguys1.com/kexp160.aac', site: 'https://www.kexp.org' },
  { id: 'somafm-groove', name: 'SomaFM Groove Salad', country: 'ABD', flag: '🇺🇸', genre: 'Chill', url: 'https://ice1.somafm.com/groovesalad-128-mp3', site: 'https://somafm.com' },
  { id: 'franceinter', name: 'France Inter', country: 'Fransa', flag: '🇫🇷', genre: 'Haber', url: 'https://icecast.radiofrance.fr/franceinter-midfi.mp3', site: 'https://www.radiofrance.fr/franceinter' },
  { id: 'franceinfo', name: 'France Info', country: 'Fransa', flag: '🇫🇷', genre: 'Haber', url: 'https://icecast.radiofrance.fr/franceinfo-midfi.mp3', site: 'https://www.radiofrance.fr/franceinfo' },
  { id: 'fip', name: 'FIP', country: 'Fransa', flag: '🇫🇷', genre: 'Müzik', url: 'https://icecast.radiofrance.fr/fip-midfi.mp3', site: 'https://www.radiofrance.fr/fip' },
  { id: 'francemusique', name: 'France Musique', country: 'Fransa', flag: '🇫🇷', genre: 'Klasik', url: 'https://icecast.radiofrance.fr/francemusique-midfi.mp3', site: 'https://www.radiofrance.fr/francemusique' },
  { id: 'mouv', name: "Mouv'", country: 'Fransa', flag: '🇫🇷', genre: 'Rap & Hip-hop', url: 'https://icecast.radiofrance.fr/mouv-midfi.mp3', site: 'https://www.radiofrance.fr/mouv' },
  { id: 'rfi-monde', name: 'RFI Monde', country: 'Fransa', flag: '🇫🇷', genre: 'Dünya', url: 'https://rfimonde64k.ice.infomaniak.ch/rfimonde-64.mp3', site: 'https://www.rfi.fr' },
  { id: 'dlf', name: 'Deutschlandfunk', country: 'Almanya', flag: '🇩🇪', genre: 'Haber', url: 'https://st01.sslstream.dlf.de/dlf/01/128/mp3/stream.mp3', site: 'https://www.deutschlandfunk.de' },
  { id: 'swr3', name: 'SWR3', country: 'Almanya', flag: '🇩🇪', genre: 'Pop', url: 'https://liveradio.swr.de/sw282p3/swr3/play.mp3', site: 'https://www.swr3.de' },
  { id: 'npo-radio1', name: 'NPO Radio 1', country: 'Hollanda', flag: '🇳🇱', genre: 'Haber', url: 'https://icecast.omroep.nl/radio1-bb-mp3', site: 'https://www.nporadio1.nl' },
  { id: 'vrt-radio1', name: 'VRT Radio 1', country: 'Belçika', flag: '🇧🇪', genre: 'Haber', url: 'https://icecast.vrtcdn.be/radio1-mid.mp3', site: 'https://www.vrt.be/radio1' },
  { id: 'stubru', name: 'Studio Brussel', country: 'Belçika', flag: '🇧🇪', genre: 'Alternatif', url: 'https://icecast.vrtcdn.be/stubru-mid.mp3', site: 'https://www.vrt.be/stubru' },
  { id: 'srf3', name: 'SRF 3', country: 'İsviçre', flag: '🇨🇭', genre: 'Pop', url: 'https://stream.srg-ssr.ch/m/drs3/mp3_128', site: 'https://www.srf.ch/radio-srf-3' },
  { id: 'rsj', name: 'Radio Swiss Jazz', country: 'İsviçre', flag: '🇨🇭', genre: 'Caz', url: 'https://stream.srg-ssr.ch/m/rsj/mp3_128', site: 'https://www.radioswissjazz.ch' },
  { id: 'oe1', name: 'Ö1', country: 'Avusturya', flag: '🇦🇹', genre: 'Kültür', url: 'https://orf-live.ors-shoutcast.at/oe1-q2a', site: 'https://oe1.orf.at' },
  { id: 'dr-p1', name: 'DR P1', country: 'Danimarka', flag: '🇩🇰', genre: 'Haber', url: 'https://live-icy.dr.dk/A/A03H.mp3', site: 'https://www.dr.dk/lyd/p1' },
  { id: 'dr-p5', name: 'DR P5', country: 'Danimarka', flag: '🇩🇰', genre: 'Kültür', url: 'https://live-icy.dr.dk/A/A05H.mp3', site: 'https://www.dr.dk/lyd/p5' },
  { id: 'sr-p1', name: 'Sveriges Radio P1', country: 'İsveç', flag: '🇸🇪', genre: 'Haber', url: 'https://sverigesradio.se/topsy/direkt/132-hi-mp3', site: 'https://sverigesradio.se/p1' },
  { id: 'sr-p2', name: 'Sveriges Radio P2', country: 'İsveç', flag: '🇸🇪', genre: 'Klasik', url: 'https://sverigesradio.se/topsy/direkt/164-hi-mp3', site: 'https://sverigesradio.se/p2' },
  { id: 'cro-radiozurnal', name: 'ČRo Radiožurnál', country: 'Çekya', flag: '🇨🇿', genre: 'Haber', url: 'https://rozhlas.stream/radiozurnal_mp3_128.mp3', site: 'https://radiozurnal.rozhlas.cz' },
  { id: 'rai3', name: 'RAI Radio 3', country: 'İtalya', flag: '🇮🇹', genre: 'Kültür', url: 'https://icestreaming.rai.it/3.mp3', site: 'https://www.raiplaysound.it/radio3' },
  { id: 'antena1', name: 'RTP Antena 1', country: 'Portekiz', flag: '🇵🇹', genre: 'Haber', url: 'https://radiocast.rtp.pt/antena180a.mp3', site: 'https://www.rtp.pt/play' },
  { id: 'cadenaser', name: 'Cadena SER', country: 'İspanya', flag: '🇪🇸', genre: 'Haber', url: 'https://25603.live.streamtheworld.com/CADENASERAAC.aac', site: 'https://cadenaser.com' },
  { id: 'caracol', name: 'Caracol Radio', country: 'Kolombiya', flag: '🇨🇴', genre: 'Haber', url: 'https://playerservices.streamtheworld.com/api/livestream-redirect/CARACOL_RADIOAAC.aac', site: 'https://caracol.com.co' },
  { id: 'trt-radyo1', name: 'TRT Radyo 1', country: 'Türkiye', flag: '🇹🇷', genre: 'Haber', url: 'https://radio-trtradyo1.live.trt.com.tr/master.m3u8', site: 'https://www.trtdinle.com', hls: true },
];

// Ülke ülke radyo: radyo dizini radio-browser.info üzerinden canlı çekilir,
// burada yalnızca öne çıkan ülke listesi ve Türkçe adları tutulur.
export const RADIO_COUNTRIES = [
  { code: 'TR', name: 'Türkiye', flag: '🇹🇷' },
  { code: 'DE', name: 'Almanya', flag: '🇩🇪' },
  { code: 'FR', name: 'Fransa', flag: '🇫🇷' },
  { code: 'GB', name: 'Birleşik Krallık', flag: '🇬🇧' },
  { code: 'US', name: 'ABD', flag: '🇺🇸' },
  { code: 'CA', name: 'Kanada', flag: '🇨🇦' },
  { code: 'MX', name: 'Meksika', flag: '🇲🇽' },
  { code: 'BR', name: 'Brezilya', flag: '🇧🇷' },
  { code: 'AR', name: 'Arjantin', flag: '🇦🇷' },
  { code: 'CO', name: 'Kolombiya', flag: '🇨🇴' },
  { code: 'CL', name: 'Şili', flag: '🇨🇱' },
  { code: 'PE', name: 'Peru', flag: '🇵🇪' },
  { code: 'VE', name: 'Venezuela', flag: '🇻🇪' },
  { code: 'UY', name: 'Uruguay', flag: '🇺🇾' },
  { code: 'ES', name: 'İspanya', flag: '🇪🇸' },
  { code: 'IT', name: 'İtalya', flag: '🇮🇹' },
  { code: 'PT', name: 'Portekiz', flag: '🇵🇹' },
  { code: 'NL', name: 'Hollanda', flag: '🇳🇱' },
  { code: 'BE', name: 'Belçika', flag: '🇧🇪' },
  { code: 'CH', name: 'İsviçre', flag: '🇨🇭' },
  { code: 'AT', name: 'Avusturya', flag: '🇦🇹' },
  { code: 'SE', name: 'İsveç', flag: '🇸🇪' },
  { code: 'NO', name: 'Norveç', flag: '🇳🇴' },
  { code: 'DK', name: 'Danimarka', flag: '🇩🇰' },
  { code: 'FI', name: 'Finlandiya', flag: '🇫🇮' },
  { code: 'PL', name: 'Polonya', flag: '🇵🇱' },
  { code: 'CZ', name: 'Çekya', flag: '🇨🇿' },
  { code: 'GR', name: 'Yunanistan', flag: '🇬🇷' },
  { code: 'RU', name: 'Rusya', flag: '🇷🇺' },
  { code: 'UA', name: 'Ukrayna', flag: '🇺🇦' },
  { code: 'IE', name: 'İrlanda', flag: '🇮🇪' },
  { code: 'IS', name: 'İzlanda', flag: '🇮🇸' },
  { code: 'EG', name: 'Mısır', flag: '🇪🇬' },
  { code: 'MA', name: 'Fas', flag: '🇲🇦' },
  { code: 'DZ', name: 'Cezayir', flag: '🇩🇿' },
  { code: 'TN', name: 'Tunus', flag: '🇹🇳' },
  { code: 'NG', name: 'Nijerya', flag: '🇳🇬' },
  { code: 'GH', name: 'Gana', flag: '🇬🇭' },
  { code: 'KE', name: 'Kenya', flag: '🇰🇪' },
  { code: 'TZ', name: 'Tanzanya', flag: '🇹🇿' },
  { code: 'ET', name: 'Etiyopya', flag: '🇪🇹' },
  { code: 'ZA', name: 'Güney Afrika', flag: '🇿🇦' },
  { code: 'SN', name: 'Senegal', flag: '🇸🇳' },
  { code: 'SA', name: 'Suudi Arabistan', flag: '🇸🇦' },
  { code: 'AE', name: 'BAE', flag: '🇦🇪' },
  { code: 'QA', name: 'Katar', flag: '🇶🇦' },
  { code: 'JO', name: 'Ürdün', flag: '🇯🇴' },
  { code: 'LB', name: 'Lübnan', flag: '🇱🇧' },
  { code: 'IQ', name: 'Irak', flag: '🇮🇶' },
  { code: 'IR', name: 'İran', flag: '🇮🇷' },
  { code: 'IL', name: 'İsrail', flag: '🇮🇱' },
  { code: 'IN', name: 'Hindistan', flag: '🇮🇳' },
  { code: 'PK', name: 'Pakistan', flag: '🇵🇰' },
  { code: 'BD', name: 'Bangladeş', flag: '🇧🇩' },
  { code: 'LK', name: 'Sri Lanka', flag: '🇱🇰' },
  { code: 'NP', name: 'Nepal', flag: '🇳🇵' },
  { code: 'CN', name: 'Çin', flag: '🇨🇳' },
  { code: 'JP', name: 'Japonya', flag: '🇯🇵' },
  { code: 'KR', name: 'Güney Kore', flag: '🇰🇷' },
  { code: 'TW', name: 'Tayvan', flag: '🇹🇼' },
  { code: 'HK', name: 'Hong Kong', flag: '🇭🇰' },
  { code: 'SG', name: 'Singapur', flag: '🇸🇬' },
  { code: 'MY', name: 'Malezya', flag: '🇲🇾' },
  { code: 'ID', name: 'Endonezya', flag: '🇮🇩' },
  { code: 'PH', name: 'Filipinler', flag: '🇵🇭' },
  { code: 'TH', name: 'Tayland', flag: '🇹🇭' },
  { code: 'VN', name: 'Vietnam', flag: '🇻🇳' },
  { code: 'AU', name: 'Avustralya', flag: '🇦🇺' },
  { code: 'NZ', name: 'Yeni Zelanda', flag: '🇳🇿' },
];

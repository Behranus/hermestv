/// Bir IPTV kanalını temsil eden model.
class Channel {
  const Channel({
    required this.name,
    required this.url,
    this.group,
    this.logo,
    this.tvgId,
    this.tvgName,
    this.subtitleUrl,
  });

  final String name;
  final String url;

  /// M3U'daki `group-title` alanı.
  final String? group;
  final String? logo;
  final String? tvgId;
  final String? tvgName;

  /// M3U'daki `#EXTVLCOPT:sub-file=` alanından gelen harici altyazı adresi.
  final String? subtitleUrl;

  /// Grubu boş/eksik olan kanallar için görünen grup adı.
  String get displayGroup => (group == null || group!.trim().isEmpty) ? 'Diğer' : group!.trim();

  Channel copyWith({String? name, String? url}) => Channel(
        name: name ?? this.name,
        url: url ?? this.url,
        group: group,
        logo: logo,
        tvgId: tvgId,
        tvgName: tvgName,
        subtitleUrl: subtitleUrl,
      );

  @override
  bool operator ==(Object other) => other is Channel && other.url == url;

  @override
  int get hashCode => url.hashCode;
}

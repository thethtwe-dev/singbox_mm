/// RuleSet type enum.
enum RuleSetType { remote, local }

/// RuleSet format enum.
enum RuleSetFormat { binary, source }

/// SingboxRuleSet model for modern routing rules (v1.8+).
class SingboxRuleSet {
  const SingboxRuleSet({
    required this.tag,
    required this.type,
    required this.format,
    this.url,
    this.path,
    this.downloadDetour,
    this.updateInterval,
  }) : assert(tag != ''),
       assert(type != RuleSetType.remote || url != null),
       assert(type != RuleSetType.local || path != null);

  /// Unique tag for this rule-set.
  final String tag;

  /// Whether this is a remote URL or a local file.
  final RuleSetType type;

  /// Format of the rule-set (binary or source).
  final RuleSetFormat format;

  /// URL for remote rule-sets.
  final String? url;

  /// Path for local rule-sets.
  final String? path;

  /// Optional outbound tag used to download this rule-set.
  final String? downloadDetour;

  /// Optional update interval for remote rule-sets.
  final Duration? updateInterval;

  /// Converts this model to sing-box JSON format.
  Map<String, Object?> toMap() {
    final Map<String, Object?> map = <String, Object?>{
      'tag': tag,
      'type': type.name,
      'format': format.name,
    };

    if (type == RuleSetType.remote) {
      map['url'] = url;
      if (downloadDetour != null && downloadDetour!.isNotEmpty) {
        map['download_detour'] = downloadDetour;
      }
      if (updateInterval != null) {
        map['update_interval'] = _formatDuration(updateInterval!);
      }
    } else {
      map['path'] = path;
    }

    return map;
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) return '${duration.inDays}d';
    if (duration.inHours > 0) return '${duration.inHours}h';
    if (duration.inMinutes > 0) return '${duration.inMinutes}m';
    return '${duration.inSeconds}s';
  }

  /// Creates an instance from a dynamic map.
  factory SingboxRuleSet.fromMap(Map<String, Object?> map) {
    return SingboxRuleSet(
      tag: map['tag'] as String,
      type: RuleSetType.values.byName(map['type'] as String),
      format: RuleSetFormat.values.byName(map['format'] as String),
      url: map['url'] as String?,
      path: map['path'] as String?,
      downloadDetour: map['download_detour'] as String?,
      updateInterval: map['update_interval'] != null
          ? _parseDuration(map['update_interval'] as String)
          : null,
    );
  }

  static Duration _parseDuration(String raw) {
    final int value = int.parse(raw.substring(0, raw.length - 1));
    final String unit = raw.substring(raw.length - 1).toLowerCase();
    switch (unit) {
      case 'd': return Duration(days: value);
      case 'h': return Duration(hours: value);
      case 'm': return Duration(minutes: value);
      case 's': return Duration(seconds: value);
      default: return Duration(minutes: value);
    }
  }
}

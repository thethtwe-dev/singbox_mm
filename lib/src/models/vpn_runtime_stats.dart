class VpnRuntimeStats {
  const VpnRuntimeStats({
    int? totalUploaded,
    int? totalDownloaded,
    int? uploadSpeed,
    int? downloadSpeed,
    @Deprecated('Use totalUploaded instead.') int? uplinkBytes,
    @Deprecated('Use totalDownloaded instead.') int? downlinkBytes,
    @Deprecated('Use uploadSpeed instead.') int? uplinkSpeed,
    @Deprecated('Use downloadSpeed instead.') int? downlinkSpeed,
    required this.activeConnections,
    required this.updatedAt,
    this.connectedAt,
  }) : totalUploaded = totalUploaded ?? uplinkBytes ?? 0,
       totalDownloaded = totalDownloaded ?? downlinkBytes ?? 0,
       uploadSpeed = uploadSpeed ?? uplinkSpeed ?? 0,
       downloadSpeed = downloadSpeed ?? downlinkSpeed ?? 0;

  final int totalUploaded;
  final int totalDownloaded;
  final int uploadSpeed;
  final int downloadSpeed;
  final int activeConnections;
  final DateTime updatedAt;
  final DateTime? connectedAt;

  @Deprecated('Use totalUploaded instead.')
  int get uplinkBytes => totalUploaded;

  @Deprecated('Use totalDownloaded instead.')
  int get downlinkBytes => totalDownloaded;

  int get totalBytes => totalUploaded + totalDownloaded;

  Duration? get connectionDuration {
    final DateTime? startedAt = connectedAt;
    if (startedAt == null) {
      return null;
    }
    final Duration delta = updatedAt.toUtc().difference(startedAt.toUtc());
    if (delta.isNegative) {
      return Duration.zero;
    }
    return delta;
  }

  @Deprecated('Use formattedTotalUploaded instead.')
  String get formattedUplink => formattedTotalUploaded;

  @Deprecated('Use formattedTotalDownloaded instead.')
  String get formattedDownlink => formattedTotalDownloaded;

  @Deprecated('Use formattedTotalUploaded + formattedTotalDownloaded instead.')
  String get formattedTotal => formatBytes(totalBytes);

  String get formattedTotalUploaded => formatBytes(totalUploaded);

  String get formattedTotalDownloaded => formatBytes(totalDownloaded);

  String get formattedUploadSpeed => '${formatBytes(uploadSpeed)}/s';

  String get formattedDownloadSpeed => '${formatBytes(downloadSpeed)}/s';

  String get formattedDuration {
    final Duration? duration = connectionDuration;
    if (duration == null) {
      return '--:--:--';
    }
    return formatDuration(duration);
  }

  factory VpnRuntimeStats.empty() {
    return VpnRuntimeStats(
      totalUploaded: 0,
      totalDownloaded: 0,
      uploadSpeed: 0,
      downloadSpeed: 0,
      activeConnections: 0,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  factory VpnRuntimeStats.fromMap(Map<Object?, Object?> raw) {
    final bool hasTotalUploaded = raw.containsKey('totalUploaded');
    final bool hasTotalDownloaded = raw.containsKey('totalDownloaded');
    final int uploadSpeed = _readInt(raw['uploadSpeed']);
    final int downloadSpeed = _readInt(raw['downloadSpeed']);
    return VpnRuntimeStats(
      totalUploaded: hasTotalUploaded
          ? _readInt(raw['totalUploaded'])
          : _readInt(raw['uplinkBytes']),
      totalDownloaded: hasTotalDownloaded
          ? _readInt(raw['totalDownloaded'])
          : _readInt(raw['downlinkBytes']),
      uploadSpeed: uploadSpeed,
      downloadSpeed: downloadSpeed,
      activeConnections: _readInt(raw['activeConnections']),
      updatedAt: _readDateTime(raw['updatedAt']) ?? DateTime.now().toUtc(),
      connectedAt: _readDateTime(raw['connectedAt']),
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'totalUploaded': totalUploaded,
      'totalDownloaded': totalDownloaded,
      'uploadSpeed': uploadSpeed,
      'downloadSpeed': downloadSpeed,
      'uplinkBytes': totalUploaded,
      'downlinkBytes': totalDownloaded,
      'activeConnections': activeConnections,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'connectedAt': connectedAt?.millisecondsSinceEpoch,
    };
  }

  static String formatBytes(int bytes, {int fractionDigits = 2}) {
    final List<String> units = <String>['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
    double value = bytes < 0 ? 0 : bytes.toDouble();
    int unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }

    if (unitIndex == 0) {
      return '${value.toInt()} ${units[unitIndex]}';
    }
    return '${value.toStringAsFixed(fractionDigits)} ${units[unitIndex]}';
  }

  static String formatDuration(Duration duration) {
    final int totalSeconds = duration.inSeconds < 0 ? 0 : duration.inSeconds;
    final int days = totalSeconds ~/ 86400;
    final int hours = (totalSeconds % 86400) ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    final int seconds = totalSeconds % 60;
    final String hhmmss =
        '${_twoDigits(hours)}:${_twoDigits(minutes)}:${_twoDigits(seconds)}';
    if (days > 0) {
      return '${days}d $hhmmss';
    }
    return hhmmss;
  }

  static int _readInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is double) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  static DateTime? _readDateTime(Object? value) {
    final int milliseconds = _readInt(value);
    if (milliseconds <= 0) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
  }

  static String _twoDigits(int value) {
    if (value >= 10) {
      return '$value';
    }
    return '0$value';
  }
}

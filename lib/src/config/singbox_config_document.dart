import 'dart:convert';

import '../models/singbox_endpoint_summary.dart';

class SingboxConfigDocument {
  SingboxConfigDocument._(this._root);

  factory SingboxConfigDocument.fromJson(String configJson) {
    final dynamic decoded = jsonDecode(configJson);
    if (decoded is! Map<Object?, Object?>) {
      throw const FormatException('Sing-box config must be a JSON object.');
    }
    return SingboxConfigDocument._(_normalizeRoot(decoded));
  }

  factory SingboxConfigDocument.fromMap(Map<String, Object?> config) {
    return SingboxConfigDocument._(_deepCopyMap(config));
  }

  final Map<String, Object?> _root;

  Map<String, Object?> toMap() => _deepCopyMap(_root);

  String toJson({bool pretty = false}) {
    final Map<String, Object?> map = toMap();
    if (pretty) {
      return const JsonEncoder.withIndent('  ').convert(map);
    }
    return jsonEncode(map);
  }

  List<SingboxEndpointSummary> endpointSummaries() {
    final List<SingboxEndpointSummary> output = <SingboxEndpointSummary>[];
    final List<Object?> outbounds = _outbounds();

    for (int index = 0; index < outbounds.length; index++) {
      final Object? item = outbounds[index];
      if (item is! Map<Object?, Object?>) {
        continue;
      }
      final Map<String, Object?> outbound = _normalizeMap(item);
      final String type = _readString(outbound['type']) ?? '';
      final String? tag = _readString(outbound['tag']);
      final String? remark =
          _readString(outbound['remark']) ??
          _readString(outbound['name']) ??
          _readString(outbound['ps']) ??
          tag;
      final String? server =
          _readString(outbound['server']) ?? _readString(outbound['address']);
      final int? serverPort = _readInt(outbound['server_port']);
      final String? transportType = _readTransportType(outbound['transport']);
      final bool tlsEnabled = _readTlsEnabled(outbound['tls']);

      output.add(
        SingboxEndpointSummary(
          outboundIndex: index,
          type: type,
          tag: tag,
          remark: remark,
          server: server,
          serverPort: serverPort,
          transportType: transportType,
          tlsEnabled: tlsEnabled,
          rawOutbound: _deepCopyMap(outbound),
        ),
      );
    }
    return output;
  }

  void updateEndpoint({
    required int outboundIndex,
    String? server,
    int? serverPort,
    String? remark,
    String? tag,
    Map<String, Object?>? advancedPatch,
  }) {
    final List<Object?> outbounds = _outbounds();
    if (outboundIndex < 0 || outboundIndex >= outbounds.length) {
      throw RangeError.index(outboundIndex, outbounds, 'outboundIndex');
    }

    final Object? outbound = outbounds[outboundIndex];
    if (outbound is! Map<Object?, Object?>) {
      throw FormatException('Outbound[$outboundIndex] is not an object.');
    }

    final Map<String, Object?> target = _normalizeMap(outbound);
    bool explicitTagUpdated = false;
    if (server != null && server.isNotEmpty) {
      target['server'] = server;
    }
    if (serverPort != null && serverPort > 0) {
      target['server_port'] = serverPort;
    }
    if (tag != null && tag.isNotEmpty) {
      target['tag'] = tag;
      explicitTagUpdated = true;
    }
    if (remark != null && remark.isNotEmpty) {
      target['remark'] = remark;
      target['name'] = remark;
      if (!explicitTagUpdated) {
        target['tag'] = remark;
      }
    }

    if (advancedPatch != null && advancedPatch.isNotEmpty) {
      _deepMergeInto(target, advancedPatch);
    }

    outbounds[outboundIndex] = target;
    _root['outbounds'] = outbounds;
  }

  void setLogLevel(String level) {
    if (level.isEmpty) {
      return;
    }
    final Map<String, Object?> log = _normalizeMap(_root['log']);
    log['level'] = level;
    _root['log'] = log;
  }

  void applyAdvancedOverride(Map<String, Object?> override) {
    if (override.isEmpty) {
      return;
    }
    _deepMergeInto(_root, override);
  }

  List<Object?> _outbounds() {
    final Object? value = _root['outbounds'];
    if (value is List<Object?>) {
      return List<Object?>.from(value);
    }
    return <Object?>[];
  }

  static Map<String, Object?> _normalizeRoot(Map<Object?, Object?> raw) {
    final Map<String, Object?> output = <String, Object?>{};
    raw.forEach((Object? key, Object? value) {
      if (key == null) {
        return;
      }
      output[key.toString()] = _deepCopyValue(value);
    });
    return output;
  }

  static Map<String, Object?> _normalizeMap(Object? raw) {
    if (raw is Map<String, Object?>) {
      return raw;
    }
    if (raw is Map<Object?, Object?>) {
      return _normalizeRoot(raw);
    }
    return <String, Object?>{};
  }

  static Map<String, Object?> _deepCopyMap(Map<String, Object?> input) {
    final Map<String, Object?> output = <String, Object?>{};
    input.forEach((String key, Object? value) {
      output[key] = _deepCopyValue(value);
    });
    return output;
  }

  static Object? _deepCopyValue(Object? value) {
    if (value is Map<String, Object?>) {
      return _deepCopyMap(value);
    }
    if (value is Map<Object?, Object?>) {
      return _normalizeRoot(value);
    }
    if (value is List<Object?>) {
      return value
          .map<Object?>((Object? item) => _deepCopyValue(item))
          .toList();
    }
    if (value is List<dynamic>) {
      return value
          .map<Object?>((dynamic item) => _deepCopyValue(item))
          .toList();
    }
    return value;
  }

  static void _deepMergeInto(
    Map<String, Object?> target,
    Map<String, Object?> incoming,
  ) {
    incoming.forEach((String key, Object? value) {
      final Object? current = target[key];
      if (current is Map<Object?, Object?> &&
          (value is Map<Object?, Object?> || value is Map<String, Object?>)) {
        final Map<String, Object?> currentMap = _normalizeMap(current);
        final Map<String, Object?> incomingMap = _normalizeMap(value);
        _deepMergeInto(currentMap, incomingMap);
        target[key] = currentMap;
        return;
      }
      if (current is Map<String, Object?> &&
          (value is Map<Object?, Object?> || value is Map<String, Object?>)) {
        final Map<String, Object?> incomingMap = _normalizeMap(value);
        _deepMergeInto(current, incomingMap);
        target[key] = current;
        return;
      }
      target[key] = _deepCopyValue(value);
    });
  }

  static String? _readString(Object? value) {
    if (value == null) {
      return null;
    }
    final String text = value.toString();
    return text.isEmpty ? null : text;
  }

  static int? _readInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is double) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  static String? _readTransportType(Object? transport) {
    if (transport is Map<Object?, Object?>) {
      final Object? type = transport['type'];
      return _readString(type);
    }
    if (transport is Map<String, Object?>) {
      return _readString(transport['type']);
    }
    return null;
  }

  static bool _readTlsEnabled(Object? tls) {
    if (tls is Map<Object?, Object?>) {
      final Object? enabled = tls['enabled'];
      return enabled == true || enabled == 1 || enabled == 'true';
    }
    if (tls is Map<String, Object?>) {
      final Object? enabled = tls['enabled'];
      return enabled == true || enabled == 1 || enabled == 'true';
    }
    return false;
  }
}

import 'vpn_connection_state.dart';

class VpnConnectionSnapshot {
  const VpnConnectionSnapshot({
    required this.state,
    required this.timestamp,
    this.lastError,
    this.detailCode,
    this.detailMessage,
    this.networkValidated,
    this.hasInternetCapability,
    this.privateDnsActive,
    this.privateDnsServerName,
    this.activeInterface,
    this.underlyingTransports = const <String>[],
  });

  final VpnConnectionState state;
  final DateTime timestamp;
  final String? lastError;
  final String? detailCode;
  final String? detailMessage;
  final bool? networkValidated;
  final bool? hasInternetCapability;
  final bool? privateDnsActive;
  final String? privateDnsServerName;
  final String? activeInterface;
  final List<String> underlyingTransports;

  bool get isConnected => state == VpnConnectionState.connected;
  bool get hasValidationIssue => isConnected && networkValidated == false;

  factory VpnConnectionSnapshot.fromMap(Map<Object?, Object?> raw) {
    return VpnConnectionSnapshot(
      state: vpnConnectionStateFromWire(raw['state']),
      timestamp: _readDateTime(raw['timestamp']) ?? DateTime.now().toUtc(),
      lastError: _readNullableString(raw['lastError']),
      detailCode: _readNullableString(raw['detailCode']),
      detailMessage: _readNullableString(raw['detailMessage']),
      networkValidated: _readNullableBool(raw['networkValidated']),
      hasInternetCapability: _readNullableBool(raw['hasInternetCapability']),
      privateDnsActive: _readNullableBool(raw['privateDnsActive']),
      privateDnsServerName: _readNullableString(raw['privateDnsServerName']),
      activeInterface: _readNullableString(raw['activeInterface']),
      underlyingTransports: _readStringList(raw['underlyingTransports']),
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'state': state.wireValue,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'lastError': lastError,
      'detailCode': detailCode,
      'detailMessage': detailMessage,
      'networkValidated': networkValidated,
      'hasInternetCapability': hasInternetCapability,
      'privateDnsActive': privateDnsActive,
      'privateDnsServerName': privateDnsServerName,
      'activeInterface': activeInterface,
      'underlyingTransports': underlyingTransports,
    };
  }

  static bool? _readNullableBool(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      if (value == 'true') {
        return true;
      }
      if (value == 'false') {
        return false;
      }
    }
    return null;
  }

  static String? _readNullableString(Object? value) {
    if (value is String && value.isNotEmpty) {
      return value;
    }
    return null;
  }

  static DateTime? _readDateTime(Object? value) {
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
    }
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true);
    }
    if (value is String) {
      final int? parsed = int.tryParse(value);
      if (parsed != null) {
        return DateTime.fromMillisecondsSinceEpoch(parsed, isUtc: true);
      }
    }
    return null;
  }

  static List<String> _readStringList(Object? value) {
    if (value is! List) {
      return const <String>[];
    }
    return value
        .whereType<String>()
        .where((String item) => item.isNotEmpty)
        .toList();
  }
}

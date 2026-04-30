import 'vpn_profile.dart';

/// Transports that the current libbox.so build supports natively.
/// `xhttp` (Xray splithttp) is intentionally absent — sing-box does not
/// expose it as a standalone outbound type; xhttp links are normalized to
/// sing-box `http` transport by [VpnConfigParser] and [SingboxConfigBuilder].
const List<VpnTransport> _kSupportedTransports = <VpnTransport>[
  VpnTransport.tcp,
  VpnTransport.ws,
  VpnTransport.grpc,
  VpnTransport.http,
  VpnTransport.httpUpgrade,
  // Note: quic transport exists in sing-box but requires specific build flags.
  // Omit unless confirmed present in the shipped libbox.so.
];

class VpnCoreCapabilities {
  const VpnCoreCapabilities({
    required this.rawVersion,
    required this.displayVersion,
    this.semverMajor,
    this.semverMinor,
    this.semverPatch,
    required this.supportedProtocols,
    List<VpnTransport>? supportedTransports,
  }) : supportedTransports = supportedTransports ?? _kSupportedTransports;

  final String? rawVersion;
  final String displayVersion;
  final int? semverMajor;
  final int? semverMinor;
  final int? semverPatch;
  final List<VpnProtocol> supportedProtocols;

  /// Transports natively supported by the current sing-box core build.
  /// Use [supportsTransport] to check a single transport.
  final List<VpnTransport> supportedTransports;

  bool get hasParsedSemver =>
      semverMajor != null && semverMinor != null && semverPatch != null;

  bool supportsProtocol(VpnProtocol protocol) {
    return supportedProtocols.contains(protocol);
  }

  /// Returns `true` if the sing-box core natively supports [transport].
  ///
  /// Note: `VpnTransport.xhttp` does not exist in this enum because it is
  /// normalized to [VpnTransport.http] transparently by the parser and
  /// config builder. A link with `type=xhttp` will use `http` at runtime.
  bool supportsTransport(VpnTransport transport) {
    return supportedTransports.contains(transport);
  }

  List<VpnProtocol> get unsupportedProtocols {
    return VpnProtocol.values
        .where((VpnProtocol protocol) => !supportsProtocol(protocol))
        .toList(growable: false);
  }

  /// Transports from [VpnTransport.values] NOT natively supported by this build.
  List<VpnTransport> get unsupportedTransports {
    return VpnTransport.values
        .where((VpnTransport t) => !supportsTransport(t))
        .toList(growable: false);
  }

  /// Returns `true` if every transport in [transports] is supported.
  bool supportsAllTransports(Iterable<VpnTransport> transports) {
    return transports.every(supportsTransport);
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'rawVersion': rawVersion,
      'displayVersion': displayVersion,
      'semverMajor': semverMajor,
      'semverMinor': semverMinor,
      'semverPatch': semverPatch,
      'hasParsedSemver': hasParsedSemver,
      'supportedProtocols': supportedProtocols
          .map((VpnProtocol protocol) => protocol.wireValue)
          .toList(growable: false),
      'unsupportedProtocols': unsupportedProtocols
          .map((VpnProtocol protocol) => protocol.wireValue)
          .toList(growable: false),
      'supportedTransports': supportedTransports
          .map((VpnTransport t) => t.wireValue)
          .toList(growable: false),
      'unsupportedTransports': unsupportedTransports
          .map((VpnTransport t) => t.wireValue)
          .toList(growable: false),
    };
  }
}

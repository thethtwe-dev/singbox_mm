import 'vpn_profile.dart';

class VpnCoreCapabilities {
  const VpnCoreCapabilities({
    required this.rawVersion,
    required this.displayVersion,
    this.semverMajor,
    this.semverMinor,
    this.semverPatch,
    required this.supportedProtocols,
  });

  final String? rawVersion;
  final String displayVersion;
  final int? semverMajor;
  final int? semverMinor;
  final int? semverPatch;
  final List<VpnProtocol> supportedProtocols;

  bool get hasParsedSemver =>
      semverMajor != null && semverMinor != null && semverPatch != null;

  bool supportsProtocol(VpnProtocol protocol) {
    return supportedProtocols.contains(protocol);
  }

  List<VpnProtocol> get unsupportedProtocols {
    return VpnProtocol.values
        .where((VpnProtocol protocol) => !supportsProtocol(protocol))
        .toList(growable: false);
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
    };
  }
}

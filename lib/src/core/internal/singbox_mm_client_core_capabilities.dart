part of '../singbox_mm_client.dart';

class _CoreSemver {
  const _CoreSemver(this.major, this.minor, this.patch);

  final int major;
  final int minor;
  final int patch;

  int compareTo(_CoreSemver other) {
    if (major != other.major) {
      return major.compareTo(other.major);
    }
    if (minor != other.minor) {
      return minor.compareTo(other.minor);
    }
    return patch.compareTo(other.patch);
  }
}

class _CoreCapabilityMatrix {
  const _CoreCapabilityMatrix({required this.rawVersion, required this.semver});

  final String? rawVersion;
  final _CoreSemver? semver;

  String get displayVersion {
    final String? value = rawVersion?.trim();
    if (value == null || value.isEmpty) {
      return 'unknown';
    }
    return value;
  }

  bool supportsProtocol(VpnProtocol protocol) {
    switch (protocol) {
      case VpnProtocol.wireguard:
        return _supportsWireGuardOutbound();
      case VpnProtocol.vless:
      case VpnProtocol.vmess:
      case VpnProtocol.trojan:
      case VpnProtocol.shadowsocks:
      case VpnProtocol.hysteria2:
      case VpnProtocol.tuic:
      case VpnProtocol.ssh:
        return true;
    }
  }

  bool _supportsWireGuardOutbound() {
    final _CoreSemver? parsed = semver;
    if (parsed == null) {
      // Unknown version: keep permissive behavior.
      return true;
    }
    return parsed.compareTo(const _CoreSemver(1, 13, 0)) < 0;
  }

  static _CoreCapabilityMatrix fromVersion(String? rawVersion) {
    return _CoreCapabilityMatrix(
      rawVersion: rawVersion,
      semver: _tryParseCoreSemver(rawVersion),
    );
  }

  VpnCoreCapabilities toPublicModel() {
    return VpnCoreCapabilities(
      rawVersion: rawVersion,
      displayVersion: displayVersion,
      semverMajor: semver?.major,
      semverMinor: semver?.minor,
      semverPatch: semver?.patch,
      supportedProtocols: VpnProtocol.values
          .where((VpnProtocol protocol) => supportsProtocol(protocol))
          .toList(growable: false),
    );
  }
}

Future<_CoreCapabilityMatrix> _resolveCoreCapabilitiesInternal(
  SignboxVpn client, {
  bool refresh = false,
}) async {
  if (!refresh && client._coreCapabilities != null) {
    return client._coreCapabilities!;
  }

  final String? rawVersion = await _guardCoreVersionReadInternal(client);
  final _CoreCapabilityMatrix resolved = _CoreCapabilityMatrix.fromVersion(
    rawVersion,
  );
  client._coreCapabilities = resolved;
  return resolved;
}

Future<String?> _guardCoreVersionReadInternal(SignboxVpn client) async {
  try {
    return await client._guard(() => client._platform.getSingboxVersion());
  } on SignboxVpnException {
    return null;
  }
}

Future<VpnCoreCapabilities> _getCoreCapabilitiesInternal(
  SignboxVpn client, {
  bool refresh = false,
}) async {
  final _CoreCapabilityMatrix capabilities =
      await _resolveCoreCapabilitiesInternal(client, refresh: refresh);
  return capabilities.toPublicModel();
}

Future<void> _assertCoreSupportsProfileInternal(
  SignboxVpn client,
  VpnProfile profile,
) async {
  final _CoreCapabilityMatrix capabilities =
      await _resolveCoreCapabilitiesInternal(client);
  if (capabilities.supportsProtocol(profile.protocol)) {
    return;
  }

  throw SignboxVpnException(
    code: 'UNSUPPORTED_PROTOCOL_FOR_CORE',
    message:
        '${profile.protocol.wireValue} is not supported by current sing-box core '
        '(${capabilities.displayVersion}). '
        'WireGuard outbound was removed in sing-box 1.13.0+. '
        'Use another protocol or ship a compatible core.',
  );
}

Future<List<VpnProfile>> _filterSupportedProfilesForCoreInternal(
  SignboxVpn client,
  List<VpnProfile> profiles,
) async {
  if (profiles.isEmpty) {
    return const <VpnProfile>[];
  }
  final _CoreCapabilityMatrix capabilities =
      await _resolveCoreCapabilitiesInternal(client);
  final List<VpnProfile> supported = profiles
      .where(
        (VpnProfile profile) => capabilities.supportsProtocol(profile.protocol),
      )
      .toList(growable: false);

  if (supported.isNotEmpty) {
    return supported;
  }

  throw SignboxVpnException(
    code: 'UNSUPPORTED_PROTOCOL_FOR_CORE',
    message:
        'None of the selected profiles are supported by current sing-box core '
        '(${capabilities.displayVersion}).',
  );
}

_CoreSemver? _tryParseCoreSemver(String? rawVersion) {
  final String value = rawVersion?.trim() ?? '';
  if (value.isEmpty) {
    return null;
  }

  final Match? match = RegExp(r'(\d+)\.(\d+)(?:\.(\d+))?').firstMatch(value);
  if (match == null) {
    return null;
  }
  final int? major = int.tryParse(match.group(1) ?? '');
  final int? minor = int.tryParse(match.group(2) ?? '');
  final int patch = int.tryParse(match.group(3) ?? '0') ?? 0;
  if (major == null || minor == null) {
    return null;
  }
  return _CoreSemver(major, minor, patch);
}

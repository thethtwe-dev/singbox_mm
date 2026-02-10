import '../config/vpn_subscription_parser.dart';
import 'vpn_ping_result.dart';
import 'vpn_profile.dart';

class SubscriptionImportResult {
  const SubscriptionImportResult({
    required this.subscription,
    required this.poolSize,
    required this.appliedProfile,
    required this.appliedConfig,
  });

  final ParsedVpnSubscription subscription;
  final int poolSize;
  final VpnProfile? appliedProfile;
  final Map<String, Object?>? appliedConfig;

  int get importedCount => subscription.profiles.length;
  int get invalidCount => subscription.failures.length;
}

class ManualConnectResult {
  const ManualConnectResult({
    required this.profile,
    required this.appliedConfig,
    this.warnings = const <String>[],
  });

  final VpnProfile profile;
  final Map<String, Object?> appliedConfig;
  final List<String> warnings;
}

class AutoConnectResult {
  const AutoConnectResult({
    required this.importResult,
    required this.selectedProfile,
    this.pingResults = const <VpnPingResult>[],
  });

  final SubscriptionImportResult importResult;
  final VpnProfile? selectedProfile;
  final List<VpnPingResult> pingResults;
}

import 'package:flutter_test/flutter_test.dart';
import 'package:singbox_mm/singbox_mm.dart';

void main() {
  test('parses detailed state payload map', () {
    final VpnConnectionSnapshot snapshot = VpnConnectionSnapshot.fromMap(
      <String, Object?>{
        'state': 'connected',
        'timestamp': 1700000000000,
        'lastError': null,
        'detailCode': 'PRIVATE_DNS_BROKEN',
        'detailMessage': 'Validation failed with strict private DNS',
        'networkValidated': false,
        'hasInternetCapability': true,
        'privateDnsActive': true,
        'privateDnsServerName': 'dns.adguard.com',
        'activeInterface': 'tun0',
        'underlyingTransports': <String>['wifi'],
      },
    );

    expect(snapshot.state, VpnConnectionState.connected);
    expect(snapshot.hasValidationIssue, isTrue);
    expect(snapshot.detailCode, 'PRIVATE_DNS_BROKEN');
    expect(snapshot.privateDnsActive, isTrue);
    expect(snapshot.privateDnsServerName, 'dns.adguard.com');
    expect(snapshot.underlyingTransports, <String>['wifi']);
  });
}

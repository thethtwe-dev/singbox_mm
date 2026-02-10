import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:singbox_mm/singbox_mm.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('basic runtime calls are reachable', (WidgetTester tester) async {
    final SignboxVpn plugin = SignboxVpn();

    await plugin.initialize(const SingboxRuntimeOptions());
    final VpnConnectionState state = await plugin.getState();
    final VpnRuntimeStats stats = await plugin.getStats();

    expect(state, isA<VpnConnectionState>());
    expect(stats, isA<VpnRuntimeStats>());
  });
}

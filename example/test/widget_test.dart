import 'package:flutter_test/flutter_test.dart';

import 'package:singbox_mm_example/main.dart';

void main() {
  testWidgets('renders VPN state panel', (WidgetTester tester) async {
    await tester.pumpWidget(const SignboxVpnDemoApp());

    expect(find.textContaining('State:'), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);
    expect(find.text('Hardened Connect'), findsOneWidget);
    expect(find.text('Disconnect'), findsOneWidget);
    expect(find.text('Hardened Preset'), findsOneWidget);
  });
}

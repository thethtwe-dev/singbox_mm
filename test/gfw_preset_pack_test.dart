import 'package:flutter_test/flutter_test.dart';
import 'package:singbox_mm/singbox_mm.dart';

void main() {
  test('gfw preset pack exposes stable preset list', () {
    final List<GfwPresetPack> presets = GfwPresetPack.all();

    expect(presets.length, 4);
    expect(presets.map((GfwPresetPack item) => item.mode), <GfwPresetMode>[
      GfwPresetMode.compatibility,
      GfwPresetMode.balanced,
      GfwPresetMode.aggressive,
      GfwPresetMode.extreme,
    ]);

    final GfwPresetPack balanced = GfwPresetPack.balanced();
    expect(balanced.throttlePolicy.enableMultiplex, isTrue);
    expect(balanced.throttlePolicy.enableTcpBrutal, isFalse);
    expect(
      balanced.endpointPoolOptions.healthCheck.connectivityProbeEnabled,
      isTrue,
    );
  });

  test('gfw preset from mode returns matching preset', () {
    final GfwPresetPack aggressive = GfwPresetPack.fromMode(
      GfwPresetMode.aggressive,
    );
    expect(aggressive.name, 'Aggressive');
    expect(aggressive.featureSettings.tlsTricks.enableTlsFragment, isTrue);
    expect(aggressive.featureSettings.tlsTricks.enableTlsPadding, isTrue);

    final GfwPresetPack extreme = GfwPresetPack.fromMode(GfwPresetMode.extreme);
    expect(extreme.endpointPoolOptions.healthCheck.maxConsecutiveFailures, 1);
  });
}

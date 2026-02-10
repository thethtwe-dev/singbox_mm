import 'package:flutter_test/flutter_test.dart';
import 'package:singbox_mm/singbox_mm.dart';

void main() {
  const String passphrase = 'demo-passphrase-2026';
  const String rawVless =
      'vless://11111111-2222-3333-4444-555555555555@203.0.113.10:29485?type=tcp&encryption=none&security=none#demo-node';

  test('wrap/unwrap roundtrip works for sbmm secure link', () {
    final String wrapped = SbmmSecureLinkCodec.wrapConfigLink(
      configLink: rawVless,
      passphrase: passphrase,
    );

    expect(SbmmSecureLinkCodec.isSbmmLink(wrapped), isTrue);

    final String unwrapped = SbmmSecureLinkCodec.unwrapConfigLink(
      sbmmLink: wrapped,
      passphrase: passphrase,
    );

    expect(unwrapped, rawVless);
  });

  test('unwrap fails with wrong passphrase', () {
    final String wrapped = SbmmSecureLinkCodec.wrapConfigLink(
      configLink: rawVless,
      passphrase: passphrase,
    );

    expect(
      () => SbmmSecureLinkCodec.unwrapConfigLink(
        sbmmLink: wrapped,
        passphrase: 'wrong-passphrase',
      ),
      throwsFormatException,
    );
  });

  test('unwrap fails when payload is tampered', () {
    final String wrapped = SbmmSecureLinkCodec.wrapConfigLink(
      configLink: rawVless,
      passphrase: passphrase,
    );
    final String tampered = '$wrapped-';

    expect(
      () => SbmmSecureLinkCodec.unwrapConfigLink(
        sbmmLink: tampered,
        passphrase: passphrase,
      ),
      throwsFormatException,
    );
  });
}

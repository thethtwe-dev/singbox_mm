import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:singbox_mm/singbox_mm.dart';

void main() {
  const VpnConfigParser parser = VpnConfigParser();
  const VpnSubscriptionParser subscriptionParser = VpnSubscriptionParser();

  test('supports eight protocol types in model', () {
    expect(VpnProtocol.values.length, 8);
    expect(VpnProtocol.values, contains(VpnProtocol.vless));
    expect(VpnProtocol.values, contains(VpnProtocol.vmess));
    expect(VpnProtocol.values, contains(VpnProtocol.shadowsocks));
    expect(VpnProtocol.values, contains(VpnProtocol.hysteria2));
    expect(VpnProtocol.values, contains(VpnProtocol.tuic));
    expect(VpnProtocol.values, contains(VpnProtocol.wireguard));
    expect(VpnProtocol.values, contains(VpnProtocol.ssh));
  });

  test('parse vless link', () {
    final ParsedVpnConfig parsed = parser.parse(
      'vless://11111111-2222-3333-4444-555555555555@203.0.113.10:29485?type=tcp&encryption=none&security=none#demo-node',
    );

    expect(parsed.profile.protocol, VpnProtocol.vless);
    expect(parsed.profile.server, '203.0.113.10');
    expect(parsed.profile.serverPort, 29485);
    expect(parsed.profile.uuid, '11111111-2222-3333-4444-555555555555');
    expect(parsed.profile.tag, 'demo-node');
    expect(parsed.profile.tls.enabled, isFalse);
  });

  test('parse sbmm wrapped link with passphrase', () {
    const String raw =
        'vless://11111111-2222-3333-4444-555555555555@203.0.113.10:29485?type=tcp&encryption=none&security=none#demo-node';
    final String wrapped = SbmmSecureLinkCodec.wrapConfigLink(
      configLink: raw,
      passphrase: 'sbmm-secret',
    );

    final ParsedVpnConfig parsed = parser.parse(
      wrapped,
      sbmmPassphrase: 'sbmm-secret',
    );

    expect(parsed.scheme, 'sbmm');
    expect(parsed.profile.protocol, VpnProtocol.vless);
    expect(parsed.profile.server, '203.0.113.10');
    expect(parsed.warnings.any((String w) => w.contains('sbmm')), isTrue);
  });

  test('throws on sbmm link when passphrase is missing', () {
    const String raw =
        'vless://11111111-2222-3333-4444-555555555555@203.0.113.10:29485?type=tcp&encryption=none&security=none#demo-node';
    final String wrapped = SbmmSecureLinkCodec.wrapConfigLink(
      configLink: raw,
      passphrase: 'sbmm-secret',
    );

    expect(() => parser.parse(wrapped), throwsFormatException);
  });

  test('parse vmess base64 link', () {
    final String vmessJson = jsonEncode(<String, String>{
      'v': '2',
      'ps': 'demo-vmess',
      'add': 'example.com',
      'port': '443',
      'id': '11111111-2222-3333-4444-555555555555',
      'net': 'ws',
      'path': '/ws',
      'host': 'cdn.example.com',
      'tls': 'tls',
      'sni': 'example.com',
    });
    final String vmessPayload = base64.encode(utf8.encode(vmessJson));
    final ParsedVpnConfig parsed = parser.parse('vmess://$vmessPayload');

    expect(parsed.profile.protocol, VpnProtocol.vmess);
    expect(parsed.profile.tag, 'demo-vmess');
    expect(parsed.profile.server, 'example.com');
    expect(parsed.profile.transport, VpnTransport.ws);
    expect(parsed.profile.websocketPath, '/ws');
    expect(parsed.profile.websocketHeaders['Host'], 'cdn.example.com');
    expect(parsed.profile.tls.enabled, isTrue);
    expect(parsed.profile.tls.serverName, 'example.com');
  });

  test('parse shadowsocks link', () {
    const String credentials = 'aes-256-gcm:secret-pass';
    final String ssAuth = base64.encode(utf8.encode(credentials));
    final ParsedVpnConfig parsed = parser.parse(
      'ss://$ssAuth@example.com:8388#my-ss',
    );

    expect(parsed.profile.protocol, VpnProtocol.shadowsocks);
    expect(parsed.profile.server, 'example.com');
    expect(parsed.profile.serverPort, 8388);
    expect(parsed.profile.method, 'aes-256-gcm');
    expect(parsed.profile.password, 'secret-pass');
    expect(parsed.profile.tag, 'my-ss');
    expect(parsed.profile.tls.enabled, isFalse);
  });

  test('parse hysteria2 and tuic links', () {
    final ParsedVpnConfig hy2 = parser.parse(
      'hysteria2://hy2pass@example.com:8443?sni=edge.example.com#node-hy2',
    );
    expect(hy2.profile.protocol, VpnProtocol.hysteria2);
    expect(hy2.profile.password, 'hy2pass');
    expect(hy2.profile.tls.enabled, isTrue);
    expect(hy2.profile.tls.serverName, 'edge.example.com');

    final ParsedVpnConfig tuic = parser.parse(
      'tuic://aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee:tuic-pass@example.com:443?sni=example.com#node-tuic',
    );
    expect(tuic.profile.protocol, VpnProtocol.tuic);
    expect(tuic.profile.uuid, 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee');
    expect(tuic.profile.password, 'tuic-pass');
    expect(tuic.profile.tls.enabled, isTrue);
  });

  test('parse hysteria alias link', () {
    final ParsedVpnConfig parsed = parser.parse(
      'hysteria://hy2pass@example.com:8443?sni=edge.example.com#node-hysteria',
    );

    expect(parsed.profile.protocol, VpnProtocol.hysteria2);
    expect(parsed.profile.password, 'hy2pass');
    expect(parsed.profile.server, 'example.com');
    expect(parsed.profile.serverPort, 8443);
    expect(parsed.profile.tag, 'node-hysteria');
  });

  test('parse wireguard link', () {
    final String privateKey = Uri.encodeComponent('QmFzZTY0UHJpdmF0ZUtleQ==');
    final ParsedVpnConfig parsed = parser.parse(
      'wireguard://$privateKey@203.0.113.1:51820'
      '?publickey=UGVlcg=='
      '&address=10.7.0.2/32,fd00::2/128'
      '&mtu=1408'
      '&reserved=0,0,0'
      '#node-wg',
    );

    expect(parsed.profile.protocol, VpnProtocol.wireguard);
    expect(parsed.profile.server, '203.0.113.1');
    expect(parsed.profile.serverPort, 51820);
    expect(parsed.profile.tag, 'node-wg');
    expect(parsed.profile.tls.enabled, isFalse);
    expect(parsed.profile.extra['private_key'], 'QmFzZTY0UHJpdmF0ZUtleQ==');
    expect(parsed.profile.extra['peer_public_key'], 'UGVlcg==');
    expect(parsed.profile.extra['local_address'], <String>[
      '10.7.0.2/32',
      'fd00::2/128',
    ]);
    expect(parsed.warnings, isNotEmpty);
  });

  test('parse wg-quick text config', () {
    const String wgQuick = '''
[Interface]
PrivateKey = +AnI1IohUg9n/BgJ/ipI3af82+pdWMJjmbS9KqvW1ko=
Address = 10.0.0.2/32
DNS = 1.1.1.1, 1.0.0.1
MTU = 1250

# wg-1
[Peer]
PublicKey = VzO+Q6Ruhrft60/LRQpy41mSWsbIq5hi36tcTd4XvxA=
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = 203.0.113.20:31543
''';

    expect(parser.canParse(wgQuick), isTrue);

    final ParsedVpnConfig parsed = parser.parse(wgQuick);
    expect(parsed.scheme, 'wireguard');
    expect(parsed.profile.protocol, VpnProtocol.wireguard);
    expect(parsed.profile.tag, 'wg-1');
    expect(parsed.profile.server, '203.0.113.20');
    expect(parsed.profile.serverPort, 31543);
    expect(
      parsed.profile.extra['private_key'],
      '+AnI1IohUg9n/BgJ/ipI3af82+pdWMJjmbS9KqvW1ko=',
    );
    expect(
      parsed.profile.extra['peer_public_key'],
      'VzO+Q6Ruhrft60/LRQpy41mSWsbIq5hi36tcTd4XvxA=',
    );
    expect(parsed.profile.extra['local_address'], <String>['10.0.0.2/32']);
    expect(parsed.profile.extra['mtu'], 1250);
    expect(
      parsed.warnings.any((String warning) => warning.contains('DNS')),
      isTrue,
    );
  });

  test('wg-quick parser uses first peer when multiple peers are provided', () {
    const String wgQuick = '''
[Interface]
PrivateKey = priv-key
Address = 10.0.0.2/32

[Peer]
PublicKey = peer-1
Endpoint = 198.51.100.1:51820

[Peer]
PublicKey = peer-2
Endpoint = 198.51.100.2:51820
''';

    final ParsedVpnConfig parsed = parser.parse(wgQuick);
    expect(parsed.profile.server, '198.51.100.1');
    expect(parsed.profile.extra['peer_public_key'], 'peer-1');
    expect(
      parsed.warnings.any((String warning) => warning.contains('multiple')),
      isTrue,
    );
  });

  test('parse ssh link', () {
    final ParsedVpnConfig parsed = parser.parse(
      'ssh://demo:secret@example.com:22'
      '?host_key=ssh-ed25519%20AAAAC3NzaC1lZDI1NTE5AAAA'
      '&host_key_algorithms=ssh-ed25519,rsa-sha2-512'
      '#node-ssh',
    );

    expect(parsed.profile.protocol, VpnProtocol.ssh);
    expect(parsed.profile.server, 'example.com');
    expect(parsed.profile.serverPort, 22);
    expect(parsed.profile.tag, 'node-ssh');
    expect(parsed.profile.password, 'secret');
    expect(parsed.profile.extra['user'], 'demo');
    expect(parsed.profile.extra['host_key_algorithms'], <String>[
      'ssh-ed25519',
      'rsa-sha2-512',
    ]);
    expect(parsed.warnings, isEmpty);
  });

  test('tuic outbound includes password', () {
    final VpnProfile profile = VpnProfile.tuic(
      tag: 'node-tuic',
      server: 'example.com',
      serverPort: 443,
      uuid: 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
      password: 'tuic-pass',
    );

    final Map<String, Object?> outbound = profile.toOutboundJson(
      throttle: const TrafficThrottlePolicy(
        enableMultiplex: true,
        enableTcpBrutal: true,
      ),
    );
    expect(outbound['uuid'], 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee');
    expect(outbound['password'], 'tuic-pass');
  });

  test('wireguard outbound includes required keys', () {
    final VpnProfile profile = VpnProfile.wireguard(
      tag: 'node-wg',
      server: '203.0.113.1',
      serverPort: 51820,
      privateKey: 'QmFzZTY0UHJpdmF0ZUtleQ==',
      peerPublicKey: 'UGVlcg==',
      localAddress: const <String>['10.7.0.2/32'],
      reserved: const <int>[0, 0, 0],
      mtu: 1408,
    );

    final Map<String, Object?> outbound = profile.toOutboundJson(
      throttle: const TrafficThrottlePolicy(),
    );

    expect(outbound['type'], 'wireguard');
    expect(outbound['private_key'], 'QmFzZTY0UHJpdmF0ZUtleQ==');
    expect(outbound['peer_public_key'], 'UGVlcg==');
    expect(outbound['local_address'], const <String>['10.7.0.2/32']);
    expect(outbound['reserved'], const <int>[0, 0, 0]);
    expect(outbound.containsKey('tls'), isFalse);
    expect(outbound.containsKey('multiplex'), isFalse);
    expect(outbound.containsKey('tcp_brutal'), isFalse);
  });

  test('ssh outbound includes user and auth', () {
    final VpnProfile profile = VpnProfile.ssh(
      tag: 'node-ssh',
      server: 'example.com',
      user: 'demo',
      password: 'secret',
    );

    final Map<String, Object?> outbound = profile.toOutboundJson(
      throttle: const TrafficThrottlePolicy(),
    );

    expect(outbound['type'], 'ssh');
    expect(outbound['user'], 'demo');
    expect(outbound['password'], 'secret');
    expect(outbound.containsKey('tls'), isFalse);
  });

  test('throws on unsupported scheme', () {
    expect(
      () => parser.parse('socks5://user:pass@127.0.0.1:1080'),
      throwsFormatException,
    );
  });

  test('parse base64 subscription list', () {
    const String rawList = '''
vless://11111111-2222-3333-4444-555555555555@example.com:443?security=tls#edge-a
invalid-entry
ss://YWVzLTI1Ni1nY206cGFzc3dvcmQ=@example.org:8388#edge-b
''';
    final String encoded = base64.encode(utf8.encode(rawList));
    final ParsedVpnSubscription parsed = subscriptionParser.parse(encoded);

    expect(parsed.decodedFromBase64, isTrue);
    expect(parsed.profiles.length, 2);
    expect(parsed.failures.length, 1);
    expect(parsed.profiles.first.tag, 'edge-a');
    expect(parsed.profiles.last.protocol, VpnProtocol.shadowsocks);
  });

  test('deduplicate subscription entries', () {
    const String repeated =
        'vless://11111111-2222-3333-4444-555555555555@example.com:443?security=none#edge-a\n'
        'vless://11111111-2222-3333-4444-555555555555@example.com:443?security=none#edge-a';
    final ParsedVpnSubscription parsed = subscriptionParser.parse(repeated);
    expect(parsed.profiles.length, 1);
    expect(parsed.failures, isEmpty);
  });

  test('parse sbmm entries in subscription with passphrase', () {
    const String raw =
        'vless://11111111-2222-3333-4444-555555555555@example.com:443?security=none#edge-a';
    final String wrapped = SbmmSecureLinkCodec.wrapConfigLink(
      configLink: raw,
      passphrase: 'sub-secret',
    );

    final ParsedVpnSubscription parsed = subscriptionParser.parse(
      wrapped,
      sbmmPassphrase: 'sub-secret',
    );

    expect(parsed.profiles.length, 1);
    expect(parsed.profiles.first.tag, 'edge-a');
    expect(parsed.entries.first.scheme, 'sbmm');
  });
}

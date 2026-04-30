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

  test('parse vless ws link defaults alpn to http/1.1 only', () {
    final ParsedVpnConfig parsed = parser.parse(
      'vless://11111111-2222-3333-4444-666666666666@ws-gateway.example.net:443?path=%2Fws%3Fed%3D2048&security=tls&encryption=none&host=ws-gateway.example.net&fp=randomized&type=ws&sni=ws-gateway.example.net#test-sg',
    );

    expect(parsed.profile.protocol, VpnProtocol.vless);
    expect(parsed.profile.transport, VpnTransport.ws);
    expect(parsed.profile.websocketPath, '/ws');
    expect(parsed.profile.tls.enabled, isTrue);
    expect(parsed.profile.tls.serverName, 'ws-gateway.example.net');
    expect(parsed.profile.tls.alpn, const <String>['http/1.1']);
    expect(parsed.profile.tls.utlsFingerprint, 'randomized');
  });

  test('parse ws host aliases and preserve special path query', () {
    final ParsedVpnConfig vlessParsed = parser.parse(
      'vless://11111111-2222-3333-4444-555555555555@example.com:443'
      '?type=ws'
      '&path=%2F%2Fws%3Fed%3D2048%26foo%3Dbar%2520baz'
      '&headers=%7B%22Host%22%3A%22vless-host.example.com%22%7D'
      '&security=tls'
      '&sni=example.com'
      '#vless-ws',
    );
    expect(vlessParsed.profile.websocketPath, '/ws?foo=bar%20baz');
    expect(
      vlessParsed.profile.websocketHeaders['Host'],
      'vless-host.example.com',
    );

    final ParsedVpnConfig vmessParsed = parser.parse(
      'vmess://11111111-2222-3333-4444-555555555555@example.com:443'
      '?type=ws'
      '&path=%2Fvm%3Fed%3D1024'
      '&authority=vmess-host.example.com'
      '&security=tls'
      '&sni=example.com'
      '#vmess-ws',
    );
    expect(vmessParsed.profile.websocketPath, '/vm');
    expect(
      vmessParsed.profile.websocketHeaders['Host'],
      'vmess-host.example.com',
    );

    final ParsedVpnConfig trojanParsed = parser.parse(
      'trojan://password@example.com:443'
      '?type=ws'
      '&path=%2Ftr%3Fed%3D512'
      '&ws_host=trojan-host.example.com'
      '&security=tls'
      '&sni=example.com'
      '#trojan-ws',
    );
    expect(trojanParsed.profile.websocketPath, '/tr');
    expect(
      trojanParsed.profile.websocketHeaders['Host'],
      'trojan-host.example.com',
    );

    final String ssAuth = base64.encode(utf8.encode('aes-256-gcm:ss-pass'));
    final ParsedVpnConfig ssParsed = parser.parse(
      'ss://$ssAuth@example.com:443'
      '?type=ws'
      '&path=%2Fss%3Fed%3D256'
      '&headers=%7B%22Host%22%3A%22ss-host.example.com%22%7D'
      '#ss-ws',
    );
    expect(ssParsed.profile.websocketPath, '/ss');
    expect(ssParsed.profile.websocketHeaders['Host'], 'ss-host.example.com');
  });

  test('parse ws link allows explicit empty alpn', () {
    final ParsedVpnConfig parsed = parser.parse(
      'vless://11111111-2222-3333-4444-555555555555@example.com:443'
      '?type=ws'
      '&path=%2Fws'
      '&security=tls'
      '&alpn=none'
      '&sni=example.com'
      '#vless-empty-alpn',
    );

    expect(parsed.profile.protocol, VpnProtocol.vless);
    expect(parsed.profile.transport, VpnTransport.ws);
    expect(parsed.profile.tls.enabled, isTrue);
    expect(parsed.profile.tls.alpn, isEmpty);
  });

  test('parse ws link falls back Host header from sni when host is absent', () {
    final ParsedVpnConfig parsed = parser.parse(
      'vless://11111111-2222-3333-4444-555555555555@198.51.100.10:443'
      '?type=ws'
      '&path=%2Fws'
      '&security=tls'
      '&sni=cdn.example.com'
      '#vless-sni-host-fallback',
    );

    expect(parsed.profile.websocketHeaders['Host'], 'cdn.example.com');
    expect(parsed.profile.tls.serverName, 'cdn.example.com');
  });

  test('parse grpc link maps authority and path alias service name', () {
    final ParsedVpnConfig parsed = parser.parse(
      'vless://11111111-2222-3333-4444-555555555555@edge.example.com:443'
      '?type=grpc'
      '&path=%2Fgrpc-service'
      '&authority=grpc.edge.example.com'
      '&security=tls'
      '&sni=edge.example.com'
      '#vless-grpc',
    );

    expect(parsed.profile.transport, VpnTransport.grpc);
    expect(parsed.profile.grpcServiceName, 'grpc-service');
    expect(parsed.profile.websocketHeaders['Host'], 'grpc.edge.example.com');
    expect(parsed.profile.tls.alpn, const <String>['h2']);
    expect(
      parsed.profile.extra['_sbmm_grpc_authority'],
      'grpc.edge.example.com',
    );
  });

  test('parse vless reality aliases including fingerprint and spx', () {
    final ParsedVpnConfig parsed = parser.parse(
      'vless://11111111-2222-3333-4444-555555555555@reality.example.com:443'
      '?type=tcp'
      '&security=reality'
      '&fingerprint=firefox'
      '&pbk=example-public-key'
      '&shortId=abcd1234'
      '&spx=%2Fspider'
      '#reality-node',
    );

    expect(parsed.profile.tls.enabled, isTrue);
    expect(parsed.profile.tls.utlsFingerprint, 'firefox');
    expect(parsed.profile.tls.realityPublicKey, 'example-public-key');
    expect(parsed.profile.tls.realityShortId, 'abcd1234');
    expect(parsed.profile.tls.realitySpiderX, '/spider');
  });

  test('parse ws explicit early-data params but default remains safe', () {
    final ParsedVpnConfig parsed = parser.parse(
      'vmess://11111111-2222-3333-4444-555555555555@example.com:443'
      '?type=ws'
      '&path=%2Fws%3Fed%3D2048'
      '&max_early_data=4096'
      '&early_data_header_name=Sec-WebSocket-Protocol'
      '&security=tls'
      '&sni=example.com'
      '#vmess-ws-ed',
    );

    expect(parsed.profile.websocketPath, '/ws');
    expect(parsed.profile.maxEarlyData, 4096);
    expect(parsed.profile.earlyDataHeaderName, 'Sec-WebSocket-Protocol');
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

  test('parse vmess xhttp base64 link normalizes to http on port 80', () {
    final String vmessJson = jsonEncode(<String, String>{
      'v': '2',
      'ps': 'vmess-xhttp',
      'add': 'app.example.com',
      'port': '80',
      'id': 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
      'net': 'xhttp',
      'path': '/QmCus87aYKFEQyuUX7rUfHXH4',
      'host': 'app.example.com',
      'tls': '',
      'security': 'none',
      'type': 'none',
    });
    final String vmessPayload = base64.encode(utf8.encode(vmessJson));
    final ParsedVpnConfig parsed = parser.parse('vmess://$vmessPayload');

    expect(parsed.profile.protocol, VpnProtocol.vmess);
    expect(parsed.profile.transport, VpnTransport.http);
    expect(parsed.warnings, contains(contains('xhttp')));
    expect(parsed.profile.server, 'app.example.com');
    expect(parsed.profile.serverPort, 80);
    expect(parsed.profile.websocketPath, '/QmCus87aYKFEQyuUX7rUfHXH4');
    expect(parsed.profile.websocketHeaders['Host'], 'app.example.com');
    expect(parsed.profile.tls.enabled, isFalse);
  });

  test('parse trojan xhttp link normalizes to http transport', () {
    final ParsedVpnConfig parsed = parser.parse(
      'trojan://secret-pass@app.example.com:80'
      '?type=xhttp'
      '&path=%2Fupgrade'
      '&host=app.example.com'
      '&security=none'
      '#trojan-xhttp',
    );

    expect(parsed.profile.protocol, VpnProtocol.trojan);
    expect(parsed.profile.transport, VpnTransport.http);
    expect(parsed.profile.serverPort, 80);
    expect(parsed.profile.websocketPath, '/upgrade');
    expect(parsed.profile.websocketHeaders['Host'], 'app.example.com');
    expect(parsed.profile.tls.enabled, isFalse);
    expect(parsed.warnings, contains(contains('xhttp')));
  });

  test('parse vmess xhttp with h3 alpn normalizes to http transport', () {
    final String vmessJson = jsonEncode(<String, String>{
      'v': '2',
      'ps': 'vmess-xhttp-h3',
      'add': 'app.example.com',
      'port': '443',
      'id': 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
      'net': 'xhttp',
      'path': '/QmCus87aYKFEQyuUX7rUfHXH4',
      'host': 'app.example.com',
      'tls': 'tls',
      'security': 'tls',
      'alpn': 'h3,h2',
    });
    final String vmessPayload = base64.encode(utf8.encode(vmessJson));
    final ParsedVpnConfig parsed = parser.parse('vmess://$vmessPayload');

    expect(parsed.profile.protocol, VpnProtocol.vmess);
    expect(parsed.profile.transport, VpnTransport.http);
    expect(parsed.profile.serverPort, 443);
    expect(parsed.profile.websocketPath, '/QmCus87aYKFEQyuUX7rUfHXH4');
    expect(parsed.profile.websocketHeaders['Host'], 'app.example.com');
    expect(parsed.profile.tls.enabled, isTrue);
    expect(parsed.profile.tls.alpn, <String>['h3', 'h2']);
    expect(parsed.warnings, contains(contains('xhttp')));
  });

  test('parse vmess xhttp with tls and no hints normalizes to http', () {
    final String vmessJson = jsonEncode(<String, String>{
      'v': '2',
      'ps': 'vmess-xhttp-tls-default',
      'add': 'app.example.com',
      'port': '443',
      'id': 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
      'net': 'xhttp',
      'path': '/QmCus87aYKFEQyuUX7rUfHXH4',
      'host': 'app.example.com',
      'tls': 'tls',
      'security': 'tls',
    });
    final String vmessPayload = base64.encode(utf8.encode(vmessJson));
    final ParsedVpnConfig parsed = parser.parse('vmess://$vmessPayload');

    expect(parsed.profile.protocol, VpnProtocol.vmess);
    expect(parsed.profile.transport, VpnTransport.http);
    expect(parsed.profile.serverPort, 443);
    expect(parsed.profile.websocketPath, '/QmCus87aYKFEQyuUX7rUfHXH4');
    expect(parsed.profile.websocketHeaders['Host'], 'app.example.com');
    expect(parsed.profile.tls.enabled, isTrue);
    expect(parsed.warnings, contains(contains('xhttp')));
  });

  test('parse vmess xhttp with tls field only normalizes to http', () {
    final String vmessJson = jsonEncode(<String, String>{
      'v': '2',
      'ps': 'vmess-xhttp-tls-field',
      'add': 'app.example.com',
      'port': '443',
      'id': 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
      'net': 'xhttp',
      'path': '/QmCus87aYKFEQyuUX7rUfHXH4',
      'host': 'app.example.com',
      'tls': 'tls',
    });
    final String vmessPayload = base64.encode(utf8.encode(vmessJson));
    final ParsedVpnConfig parsed = parser.parse('vmess://$vmessPayload');

    expect(parsed.profile.protocol, VpnProtocol.vmess);
    expect(parsed.profile.transport, VpnTransport.http);
    expect(parsed.profile.serverPort, 443);
    expect(parsed.profile.tls.enabled, isTrue);
    expect(parsed.warnings, contains(contains('xhttp')));
  });

  test('parse vmess xhttp normalizes to http when security is none', () {
    final String vmessJson = jsonEncode(<String, String>{
      'v': '2',
      'ps': 'vmess-xhttp-none-hints',
      'add': 'app.example.com',
      'port': '80',
      'id': 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
      'net': 'xhttp',
      'path': '/QmCus87aYKFEQyuUX7rUfHXH4',
      'host': 'app.example.com',
      'tls': '',
      'security': 'none',
      'alpn': 'h3,h2',
      'mode': 'h3',
    });
    final String vmessPayload = base64.encode(utf8.encode(vmessJson));
    final ParsedVpnConfig parsed = parser.parse('vmess://$vmessPayload');

    expect(parsed.profile.protocol, VpnProtocol.vmess);
    expect(parsed.profile.transport, VpnTransport.http);
    expect(parsed.profile.serverPort, 80);
    expect(parsed.profile.tls.enabled, isFalse);
    expect(parsed.warnings, contains(contains('xhttp')));
  });

  test(
    'parse vmess xhttp with explicit mode hint normalizes to http transport',
    () {
      final String vmessJson = jsonEncode(<String, String>{
        'v': '2',
        'ps': 'vmess-xhttp-mode-h3',
        'add': 'app.example.com',
        'port': '443',
        'id': 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
        'net': 'xhttp',
        'path': '/QmCus87aYKFEQyuUX7rUfHXH4',
        'host': 'app.example.com',
        'tls': 'tls',
        'security': 'tls',
        'alpn': 'h3,h2',
        'mode': 'h3',
      });
      final String vmessPayload = base64.encode(utf8.encode(vmessJson));
      final ParsedVpnConfig parsed = parser.parse('vmess://$vmessPayload');

      expect(parsed.profile.protocol, VpnProtocol.vmess);
      expect(parsed.profile.transport, VpnTransport.http);
      expect(parsed.profile.serverPort, 443);
      expect(parsed.profile.websocketPath, '/QmCus87aYKFEQyuUX7rUfHXH4');
      expect(parsed.profile.websocketHeaders['Host'], 'app.example.com');
      expect(parsed.profile.tls.enabled, isTrue);
      expect(parsed.profile.tls.alpn, <String>['h3', 'h2']);
      expect(parsed.warnings, contains(contains('xhttp')));
    },
  );

  test(
    'parse vless httpupgrade qyu profile promotes to http for xray core hint',
    () {
      final ParsedVpnConfig parsed = parser.parse(
        'vless://a956ef5e-e7a1-4e77-b77c-7d5aff9f79e0@54.251.185.72:443'
        '?type=httpupgrade'
        '&path=%2FWJ3Rr868sGO1irPQyuUX7rUfHXH4'
        '&host=54.251.185.72'
        '&security=tls'
        '&sni=54.251.185.72'
        '&allowinsecure=1'
        '&fp=chrome'
        '&alpn=http%2F1.1'
        '&hiddify=1'
        '&encryption=none'
        '&core=xray'
        '&extra=%7B%22headers%22%3A%7B%22User-Agent%22%3A%22UA-From-Extra%22%2C%22Pragma%22%3A%22no-cache%22%7D%7D'
        '#qyu-xhttp',
      );

      expect(parsed.profile.transport, VpnTransport.http);
      expect(parsed.profile.websocketPath, '/WJ3Rr868sGO1irPQyuUX7rUfHXH4');
      expect(parsed.profile.websocketHeaders['Host'], '54.251.185.72');
      expect(parsed.profile.websocketHeaders['User-Agent'], 'UA-From-Extra');
      expect(parsed.profile.websocketHeaders['Pragma'], 'no-cache');
      expect(parsed.profile.extra['_sbmm_transport_alias'], 'xhttp');
      expect(
        parsed.warnings.any(
          (String item) => item.contains('promoted httpupgrade'),
        ),
        isTrue,
      );
    },
  );

  test(
    'parse vless httpupgrade hmd profile keeps httpupgrade and preserves headers',
    () {
      final ParsedVpnConfig parsed = parser.parse(
        'vless://a956ef5e-e7a1-4e77-b77c-7d5aff9f79e0@54.251.185.72:443'
        '?type=httpupgrade'
        '&path=%2FWJ3Rr868sGO1irPhmdH6Ksn4SHe'
        '&host=54.251.185.72'
        '&headers=%7B%27User-Agent%27%3A%27UA-From-Headers%27%2C%27Pragma%27%3A%27no-cache%27%7D'
        '&security=tls'
        '&sni=54.251.185.72'
        '&allowinsecure=1'
        '&fp=chrome'
        '&alpn=http%2F1.1'
        '&hiddify=1'
        '&encryption=none'
        '#hmd-httpupgrade',
      );

      expect(parsed.profile.transport, VpnTransport.httpUpgrade);
      expect(parsed.profile.websocketPath, '/WJ3Rr868sGO1irPhmdH6Ksn4SHe');
      expect(parsed.profile.websocketHeaders['Host'], '54.251.185.72');
      expect(parsed.profile.websocketHeaders['User-Agent'], 'UA-From-Headers');
      expect(parsed.profile.websocketHeaders['Pragma'], 'no-cache');
      expect(parsed.profile.extra['_sbmm_transport_alias'], 'httpupgrade');
      expect(
        parsed.warnings.any(
          (String item) => item.contains('promoted httpupgrade'),
        ),
        isFalse,
      );
    },
  );

  test(
    'parse vmess httpupgrade qyu profile keeps httpupgrade without explicit xhttp hints',
    () {
      final ParsedVpnConfig parsed = parser.parse(
        'vmess://a956ef5e-e7a1-4e77-b77c-7d5aff9f79e0@app.marketingagencymm.com:443'
        '?type=httpupgrade'
        '&path=%2FQmCus87aYKFEQyuUX7rUfHXH4'
        '&host=app.marketingagencymm.com'
        '&security=tls'
        '&sni=app.marketingagencymm.com'
        '&fp=chrome'
        '&alpn=http%2F1.1'
        '&aid=0'
        '&scy=auto'
        '#vmess-qyu-httpupgrade',
      );

      expect(parsed.profile.transport, VpnTransport.httpUpgrade);
      expect(parsed.profile.websocketPath, '/QmCus87aYKFEQyuUX7rUfHXH4');
      expect(
        parsed.profile.websocketHeaders['Host'],
        'app.marketingagencymm.com',
      );
      expect(parsed.profile.extra['_sbmm_transport_alias'], 'httpupgrade');
      expect(
        parsed.warnings.any(
          (String item) => item.contains('promoted httpupgrade'),
        ),
        isFalse,
      );
    },
  );

  test(
    'parse vless downloadSettings xhttp overrides top-level alpn and transport',
    () {
      const String raw =
          'vless://a956ef5e-e7a1-4e77-b77c-7d5aff9f79e0@app.marketingagencymm.com:443'
          '?type=httpupgrade'
          '&path=%2FWJ3Rr868sGO1irPQyuUX7rUfHXH4'
          '&host=app.marketingagencymm.com'
          '&security=tls'
          '&sni=app.marketingagencymm.com'
          '&allowinsecure=1'
          '&fp=chrome'
          '&alpn=h3'
          '&hiddify=1'
          '&encryption=none'
          '&core=xray'
          '&extra=%7B%22headers%22%3A%7B%22User-Agent%22%3A%22Mozilla%2F5.0+%28Linux%3B+Android+10%3B+K%29+AppleWebKit%2F537.36+%28KHTML%2C+like+Gecko%29+Chrome%2F144.0.0.0+Mobile+Safari%2F537.36%22%2C%22Pragma%22%3A%22no-cache%22%7D%2C%22downloadSettings%22%3A%7B%22address%22%3A%22app.marketingagencymm.com%22%2C%22port%22%3A443%2C%22network%22%3A%22xhttp%22%2C%22xhttpSettings%22%3A%7B%22path%22%3A%22%2FWJ3Rr868sGO1irPQyuUX7rUfHXH4%22%2C%22host%22%3A%22app.marketingagencymm.com%22%2C%22mode%22%3A%22auto%22%2C%22extra%22%3A%7B%22headers%22%3A%7B%22User-Agent%22%3A%22Mozilla%2F5.0+%28Linux%3B+Android+10%3B+K%29+AppleWebKit%2F537.36+%28KHTML%2C+like+Gecko%29+Chrome%2F144.0.0.0+Mobile+Safari%2F537.36%22%2C%22Pragma%22%3A%22no-cache%22%7D%7D%7D%2C%22security%22%3A%22tls%22%2C%22tlsSettings%22%3A%7B%22serverName%22%3A%22app.marketingagencymm.com%22%2C%22allowInsecure%22%3Atrue%2C%22fingerprint%22%3A%22chrome%22%2C%22alpn%22%3A%5B%22http%2F1.1%22%5D%7D%7D%7D'
          '#vless-downloadsettings-xhttp';

      final ParsedVpnConfig parsed = parser.parse(raw);

      expect(parsed.profile.transport, VpnTransport.http);
      expect(parsed.profile.websocketPath, '/WJ3Rr868sGO1irPQyuUX7rUfHXH4');
      expect(
        parsed.profile.websocketHeaders['Host'],
        'app.marketingagencymm.com',
      );
      expect(parsed.profile.tls.enabled, isTrue);
      expect(parsed.profile.tls.serverName, 'app.marketingagencymm.com');
      expect(parsed.profile.tls.allowInsecure, isTrue);
      expect(parsed.profile.tls.utlsFingerprint, 'chrome');
      expect(
        parsed.profile.tls.alpn,
        const <String>['http/1.1'],
        reason:
            'nested downloadSettings.tlsSettings.alpn must override top-level alpn=h3',
      );
    },
  );

  test(
    'parse trojan downloadSettings grpc overrides endpoint and authority',
    () {
      final String extra = Uri.encodeComponent(
        jsonEncode(<String, Object?>{
          'downloadSettings': <String, Object?>{
            'address': 'grpc-edge.example.com',
            'port': 443,
            'network': 'grpc',
            'grpcSettings': <String, Object?>{
              'serviceName': 'my-grpc-service',
              'authority': 'grpc-authority.example.com',
              'mode': 'multi',
            },
            'tlsSettings': <String, Object?>{
              'serverName': 'grpc-edge.example.com',
              'allowInsecure': true,
              'alpn': <String>['h2'],
            },
          },
        }),
      );

      final ParsedVpnConfig parsed = parser.parse(
        'trojan://secret@legacy.example.com:8443'
        '?type=tcp'
        '&security=tls'
        '&extra=$extra'
        '#trojan-ds-grpc',
      );

      expect(parsed.profile.server, 'grpc-edge.example.com');
      expect(parsed.profile.serverPort, 443);
      expect(parsed.profile.transport, VpnTransport.grpc);
      expect(parsed.profile.grpcServiceName, 'my-grpc-service');
      expect(
        parsed.profile.extra['_sbmm_grpc_authority'],
        'grpc-authority.example.com',
      );
      expect(parsed.profile.extra['_sbmm_grpc_mode'], 'multi');
      expect(parsed.profile.tls.enabled, isTrue);
      expect(parsed.profile.tls.serverName, 'grpc-edge.example.com');
      expect(parsed.profile.tls.allowInsecure, isTrue);
      expect(parsed.profile.tls.alpn, const <String>['h2']);
    },
  );

  test(
    'parse shadowsocks downloadSettings overrides endpoint and transport path',
    () {
      const String credentials = 'aes-256-gcm:secret-pass';
      final String ssAuth = base64.encode(utf8.encode(credentials));
      final String extra = Uri.encodeComponent(
        jsonEncode(<String, Object?>{
          'downloadSettings': <String, Object?>{
            'address': 'ss-edge.example.com',
            'port': 9443,
            'network': 'xhttp',
            'xhttpSettings': <String, Object?>{
              'path': '/xhttp-path',
              'host': 'ss-cdn.example.com',
            },
            'tlsSettings': <String, Object?>{
              'serverName': 'ss-edge.example.com',
              'alpn': <String>['http/1.1'],
            },
          },
        }),
      );

      final ParsedVpnConfig parsed = parser.parse(
        'ss://$ssAuth@legacy.example.com:8388'
        '?type=httpupgrade'
        '&path=%2Fold'
        '&host=legacy.example.com'
        '&security=tls'
        '&extra=$extra'
        '#ss-ds-xhttp',
      );

      expect(parsed.profile.server, 'ss-edge.example.com');
      expect(parsed.profile.serverPort, 9443);
      expect(parsed.profile.transport, VpnTransport.http);
      expect(parsed.profile.websocketPath, '/xhttp-path');
      expect(parsed.profile.websocketHeaders['Host'], 'ss-cdn.example.com');
      expect(parsed.profile.tls.enabled, isTrue);
      expect(parsed.profile.tls.serverName, 'ss-edge.example.com');
      expect(parsed.profile.tls.alpn, const <String>['http/1.1']);
    },
  );

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
      'hysteria2://hy2pass@example.com:8443?sni=edge.example.com&obfs=salamander&obfs-password=hy2-obfs-pass#node-hy2',
    );
    expect(hy2.profile.protocol, VpnProtocol.hysteria2);
    expect(hy2.profile.password, 'hy2pass');
    expect(hy2.profile.tls.enabled, isTrue);
    expect(hy2.profile.tls.serverName, 'edge.example.com');
    expect(hy2.profile.tls.alpn, isEmpty);
    expect(hy2.profile.extra['obfs'], <String, Object?>{
      'type': 'salamander',
      'password': 'hy2-obfs-pass',
    });
    expect(hy2.profile.extra.containsKey('obfs_password'), isFalse);

    final ParsedVpnConfig tuic = parser.parse(
      'tuic://aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee:tuic-pass@example.com:443?sni=example.com#node-tuic',
    );
    expect(tuic.profile.protocol, VpnProtocol.tuic);
    expect(tuic.profile.uuid, 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee');
    expect(tuic.profile.password, 'tuic-pass');
    expect(tuic.profile.tls.enabled, isTrue);
    expect(tuic.profile.tls.alpn, isEmpty);
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
    final Map<String, Object?> tls = (outbound['tls'] as Map<dynamic, dynamic>)
        .cast<String, Object?>();
    expect(tls.containsKey('utls'), isFalse);
  });

  test('hysteria2 outbound normalizes legacy obfs fields', () {
    final VpnProfile profile = VpnProfile.hysteria2(
      tag: 'node-hy2',
      server: 'hy2.example.com',
      serverPort: 8443,
      password: 'hy2-pass',
      extra: const <String, Object?>{
        'obfs': 'salamander',
        'obfs_password': 'hy2-obfs-pass',
      },
    );

    final Map<String, Object?> outbound = profile.toOutboundJson(
      throttle: const TrafficThrottlePolicy(),
    );

    expect(outbound['type'], 'hysteria2');
    expect(outbound['password'], 'hy2-pass');
    expect(outbound['obfs'], <String, Object?>{
      'type': 'salamander',
      'password': 'hy2-obfs-pass',
    });
    expect(outbound.containsKey('obfs_password'), isFalse);
    final Map<String, Object?> tls = (outbound['tls'] as Map<dynamic, dynamic>)
        .cast<String, Object?>();
    expect(tls.containsKey('utls'), isFalse);
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
  test(
    'config builder: xhttp is normalized to http transport (compat regression)',
    () {
      // Regression test: xray-style xhttp links must normalize to sing-box
      // `http` transport (not `httpupgrade`) so modern CDN/xhttp profiles work.
      final String vmessJson = jsonEncode(<String, String>{
        'v': '2',
        'ps': 'xhttp-h11-regression',
        'add': 'app.marketingagencymm.com',
        'port': '443',
        'id': 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
        'net': 'xhttp',
        'path': '/QmCus87aYKFEQyuUX7rUfHXH4',
        'host': 'app.marketingagencymm.com',
        'tls': 'tls',
        'security': 'tls',
        'alpn': 'http/1.1',
      });
      final String vmessPayload = base64.encode(utf8.encode(vmessJson));
      final ParsedVpnConfig parsed = parser.parse('vmess://$vmessPayload');

      // Parse-level: profile transport must normalize to http.
      expect(
        parsed.profile.transport,
        VpnTransport.http,
        reason: 'xhttp must be normalized to http by the parser',
      );
      // A warning must be emitted so developers know the remap happened.
      expect(
        parsed.warnings,
        contains(contains('xhttp')),
        reason: 'parser must warn that xhttp was remapped',
      );

      // Config-builder level: inspect the generated outbound.
      const SingboxConfigBuilder builder = SingboxConfigBuilder();
      final Map<String, Object?> config = builder.build(
        profile: parsed.profile,
      );

      final List<Object?> outbounds = config['outbounds']! as List<Object?>;
      final Map<String, Object?> vmessOut =
          (outbounds.firstWhere((Object? o) => o is Map && o['type'] == 'vmess')
                  as Map<Object?, Object?>)
              .map(
                (Object? key, Object? value) =>
                    MapEntry<String, Object?>(key as String, value),
              );

      final Map<String, Object?> transport =
          (vmessOut['transport'] as Map<Object?, Object?>).map(
            (Object? key, Object? value) =>
                MapEntry<String, Object?>(key as String, value),
          );

      // The generated transport type must be http, not httpupgrade.
      expect(
        transport['type'],
        equals('http'),
        reason: 'config builder must emit http transport for xhttp links',
      );
    },
  );
}

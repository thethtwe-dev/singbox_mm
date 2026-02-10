import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:singbox_mm/singbox_mm.dart';

void main() {
  test('extract endpoint summaries from sing-box config json', () {
    final Map<String, Object?> config = <String, Object?>{
      'log': <String, Object?>{'level': 'info'},
      'outbounds': <Object?>[
        <String, Object?>{
          'type': 'vless',
          'tag': 'HK-1',
          'server': '1.1.1.1',
          'server_port': 443,
          'transport': <String, Object?>{'type': 'ws'},
          'tls': <String, Object?>{'enabled': true},
        },
        <String, Object?>{
          'type': 'trojan',
          'name': 'JP-1',
          'server': '2.2.2.2',
          'server_port': 8443,
          'tls': <String, Object?>{'enabled': true},
        },
        <String, Object?>{'type': 'direct', 'tag': 'direct'},
      ],
    };

    final SingboxConfigDocument doc = SingboxConfigDocument.fromJson(
      jsonEncode(config),
    );
    final List<SingboxEndpointSummary> endpoints = doc.endpointSummaries();

    expect(endpoints.length, 3);
    expect(endpoints[0].remark, 'HK-1');
    expect(endpoints[0].server, '1.1.1.1');
    expect(endpoints[0].serverPort, 443);
    expect(endpoints[0].transportType, 'ws');
    expect(endpoints[0].tlsEnabled, isTrue);
    expect(endpoints[1].remark, 'JP-1');
    expect(endpoints[1].server, '2.2.2.2');
    expect(endpoints[1].serverPort, 8443);
    expect(endpoints[2].hasAddress, isFalse);
  });

  test('update endpoint and apply advanced overrides', () {
    final SingboxConfigDocument doc = SingboxConfigDocument.fromJson(
      jsonEncode(<String, Object?>{
        'log': <String, Object?>{'level': 'warning'},
        'outbounds': <Object?>[
          <String, Object?>{
            'type': 'vless',
            'tag': 'old-node',
            'server': '3.3.3.3',
            'server_port': 443,
          },
        ],
        'route': <String, Object?>{'final': 'old-node'},
      }),
    );

    doc.updateEndpoint(
      outboundIndex: 0,
      server: '8.8.8.8',
      serverPort: 10443,
      remark: 'new-node',
      advancedPatch: <String, Object?>{
        'transport': <String, Object?>{'type': 'grpc', 'service_name': 'vpn'},
      },
    );
    doc.setLogLevel('debug');
    doc.applyAdvancedOverride(<String, Object?>{
      'experimental': <String, Object?>{
        'clash_api': <String, Object?>{'external_controller': '127.0.0.1:9090'},
      },
      'route': <String, Object?>{'auto_detect_interface': true},
    });

    final Map<String, Object?> map = doc.toMap();
    final List<Object?> outbounds = map['outbounds']! as List<Object?>;
    final Map<String, Object?> first = outbounds.first as Map<String, Object?>;
    final Map<String, Object?> log = map['log']! as Map<String, Object?>;
    final Map<String, Object?> route = map['route']! as Map<String, Object?>;
    final Map<String, Object?> experimental =
        map['experimental']! as Map<String, Object?>;

    expect(first['server'], '8.8.8.8');
    expect(first['server_port'], 10443);
    expect(first['tag'], 'new-node');
    expect(first['remark'], 'new-node');
    expect((first['transport']! as Map<String, Object?>)['type'], 'grpc');
    expect(log['level'], 'debug');
    expect(route['final'], 'old-node');
    expect(route['auto_detect_interface'], isTrue);
    expect(
      (experimental['clash_api']!
          as Map<String, Object?>)['external_controller'],
      '127.0.0.1:9090',
    );
  });
}

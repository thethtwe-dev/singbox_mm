import 'package:flutter_test/flutter_test.dart';
import 'package:singbox_mm/singbox_mm.dart';

void main() {
  test('formats byte sizes across units', () {
    expect(VpnRuntimeStats.formatBytes(512), '512 B');
    expect(VpnRuntimeStats.formatBytes(1536), '1.50 KB');
    expect(VpnRuntimeStats.formatBytes(1024 * 1024), '1.00 MB');
    expect(VpnRuntimeStats.formatBytes(5 * 1024 * 1024 * 1024), '5.00 GB');
  });

  test('computes formatted totals and duration', () {
    final DateTime connectedAt = DateTime.fromMillisecondsSinceEpoch(
      1_700_000_000_000,
      isUtc: true,
    );
    final VpnRuntimeStats stats = VpnRuntimeStats(
      totalUploaded: 1_024,
      totalDownloaded: 2_048,
      uploadSpeed: 512,
      downloadSpeed: 1_536,
      activeConnections: 1,
      updatedAt: connectedAt.add(
        const Duration(hours: 2, minutes: 3, seconds: 4),
      ),
      connectedAt: connectedAt,
    );

    expect(stats.formattedTotalUploaded, '1.00 KB');
    expect(stats.formattedTotalDownloaded, '2.00 KB');
    expect(stats.formattedUploadSpeed, '512 B/s');
    expect(stats.formattedDownloadSpeed, '1.50 KB/s');
    expect(stats.formattedDuration, '02:03:04');
  });

  test('parses both new and legacy map keys', () {
    final VpnRuntimeStats newKeys = VpnRuntimeStats.fromMap(<Object?, Object?>{
      'totalUploaded': 5_000,
      'totalDownloaded': 9_000,
      'uploadSpeed': 200,
      'downloadSpeed': 400,
      'activeConnections': 1,
      'updatedAt': 1_700_000_000_000,
    });
    expect(newKeys.totalUploaded, 5_000);
    expect(newKeys.totalDownloaded, 9_000);
    expect(newKeys.uploadSpeed, 200);
    expect(newKeys.downloadSpeed, 400);

    final VpnRuntimeStats legacyKeys =
        VpnRuntimeStats.fromMap(<Object?, Object?>{
          'uplinkBytes': 7_000,
          'downlinkBytes': 11_000,
          'activeConnections': 1,
          'updatedAt': 1_700_000_000_000,
        });
    expect(legacyKeys.totalUploaded, 7_000);
    expect(legacyKeys.totalDownloaded, 11_000);
  });

  test('shows placeholder duration when disconnected', () {
    final VpnRuntimeStats stats = VpnRuntimeStats.empty();
    expect(stats.connectionDuration, isNull);
    expect(stats.formattedDuration, '--:--:--');
  });

  test('formats long duration with day prefix', () {
    final Duration duration = const Duration(
      days: 1,
      hours: 2,
      minutes: 3,
      seconds: 4,
    );
    expect(VpnRuntimeStats.formatDuration(duration), '1d 02:03:04');
  });
}

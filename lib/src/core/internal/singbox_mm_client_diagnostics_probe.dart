part of '../singbox_mm_client.dart';

Future<VpnConnectivityProbe> _probeConnectivityInternal(
  SignboxVpn client, {
  String? url,
  required Duration timeout,
  required Map<String, String> headers,
}) async {
  final String targetUrl = (url == null || url.trim().isEmpty)
      ? client._featureSettings.misc.connectionTestUrl
      : url.trim();

  final Uri? uri = Uri.tryParse(targetUrl);
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
    return VpnConnectivityProbe.failure(
      url: targetUrl,
      error: 'Invalid connectivity test URL.',
    );
  }

  final HttpClient httpClient = HttpClient()..connectionTimeout = timeout;
  final Stopwatch watch = Stopwatch()..start();

  try {
    final HttpClientRequest request = await httpClient
        .getUrl(uri)
        .timeout(timeout);
    request.headers.set(HttpHeaders.userAgentHeader, 'singbox_mm/0.1');
    headers.forEach((String key, String value) {
      request.headers.set(key, value);
    });

    final HttpClientResponse response = await request.close().timeout(timeout);
    await response.drain<void>().timeout(timeout);
    watch.stop();

    final int statusCode = response.statusCode;
    return VpnConnectivityProbe(
      url: uri.toString(),
      statusCode: statusCode,
      latency: watch.elapsed,
      error: statusCode >= 200 && statusCode < 400
          ? null
          : 'Unexpected HTTP status $statusCode',
      checkedAt: DateTime.now().toUtc(),
    );
  } on Object catch (error) {
    watch.stop();
    return VpnConnectivityProbe(
      url: uri.toString(),
      latency: watch.elapsed,
      error: error.toString(),
      checkedAt: DateTime.now().toUtc(),
    );
  } finally {
    httpClient.close(force: true);
  }
}

part of '../singbox_mm_client.dart';

Future<T> _guardInternal<T>(Future<T> Function() action) async {
  try {
    return await action();
  } on PlatformException catch (error) {
    throw SignboxVpnException(
      code: error.code,
      message: error.message ?? 'Platform call failed',
      details: error.details,
    );
  }
}

class _EndpointHealthState {
  const _EndpointHealthState({
    this.score = 100,
    this.consecutiveFailures = 0,
    this.lastSuccessAt,
    this.lastFailureAt,
    this.lastProgressAt,
  });

  final int score;
  final int consecutiveFailures;
  final DateTime? lastSuccessAt;
  final DateTime? lastFailureAt;
  final DateTime? lastProgressAt;

  _EndpointHealthState copyWith({
    int? score,
    int? consecutiveFailures,
    DateTime? lastSuccessAt,
    DateTime? lastFailureAt,
    DateTime? lastProgressAt,
  }) {
    return _EndpointHealthState(
      score: score ?? this.score,
      consecutiveFailures: consecutiveFailures ?? this.consecutiveFailures,
      lastSuccessAt: lastSuccessAt ?? this.lastSuccessAt,
      lastFailureAt: lastFailureAt ?? this.lastFailureAt,
      lastProgressAt: lastProgressAt ?? this.lastProgressAt,
    );
  }
}

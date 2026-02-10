class SignboxVpnException implements Exception {
  const SignboxVpnException({
    required this.code,
    required this.message,
    this.details,
  });

  final String code;
  final String message;
  final Object? details;

  @override
  String toString() =>
      'SignboxVpnException(code: $code, message: $message, details: $details)';
}

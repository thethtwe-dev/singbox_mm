class SingboxRuntimeOptions {
  const SingboxRuntimeOptions({
    this.workingDirectory,
    this.binaryPath,
    this.autoExtractAndroidBinaryFromAssets = true,
    this.androidBinaryAssetByAbi = const <String, String>{},
    this.androidFallbackBinaryAssetPath,
    this.logLevel = 'info',
    this.tunInterfaceName = 'sb-tun',
    this.tunInet4Address = '172.19.0.1/30',
    this.statsEmitIntervalMs = 1000,
    this.enableVerboseLogs = false,
  }) : assert(statsEmitIntervalMs >= 250 && statsEmitIntervalMs <= 10000);

  final String? workingDirectory;
  final String? binaryPath;
  final bool autoExtractAndroidBinaryFromAssets;
  final Map<String, String> androidBinaryAssetByAbi;
  final String? androidFallbackBinaryAssetPath;
  final String logLevel;
  final String tunInterfaceName;
  final String tunInet4Address;
  final int statsEmitIntervalMs;
  final bool enableVerboseLogs;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'workingDirectory': workingDirectory,
      'binaryPath': binaryPath,
      'autoExtractAndroidBinaryFromAssets': autoExtractAndroidBinaryFromAssets,
      'androidBinaryAssetByAbi': androidBinaryAssetByAbi,
      'androidFallbackBinaryAssetPath': androidFallbackBinaryAssetPath,
      'logLevel': logLevel,
      'tunInterfaceName': tunInterfaceName,
      'tunInet4Address': tunInet4Address,
      'statsEmitIntervalMs': statsEmitIntervalMs,
      'enableVerboseLogs': enableVerboseLogs,
    };
  }
}

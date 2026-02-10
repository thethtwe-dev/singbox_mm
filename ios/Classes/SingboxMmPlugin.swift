import Flutter
import Foundation
import Network
import UIKit

public class SingboxMmPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private struct RuntimeConfig {
    let workingDirectory: URL
    let binaryPath: String?
    let logLevel: String
    let enableVerboseLogs: Bool
  }

  private final class StatsStreamHandler: NSObject, FlutterStreamHandler {
    weak var plugin: SingboxMmPlugin?

    init(plugin: SingboxMmPlugin) {
      self.plugin = plugin
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
      -> FlutterError?
    {
      plugin?.statsSink = events
      plugin?.startStatsTimer()
      plugin?.emitStats()
      return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
      plugin?.statsSink = nil
      plugin?.stopStatsTimer()
      return nil
    }
  }

  private var runtimeConfig: RuntimeConfig?
  private var configURL: URL?

  private var connectionState: String = "disconnected"
  private var lastError: String?
  private var connectedAtMillis: Int64?
  private var uplinkBytes: Int64 = 0
  private var downlinkBytes: Int64 = 0

  private var stateSink: FlutterEventSink?
  private var statsSink: FlutterEventSink?
  private var statsTimer: Timer?
  private var statsStreamHandler: StatsStreamHandler?

  deinit {
    stopStatsTimer()
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = SingboxMmPlugin()

    let methodChannel = FlutterMethodChannel(
      name: "singbox_mm/methods",
      binaryMessenger: registrar.messenger())
    let stateChannel = FlutterEventChannel(
      name: "singbox_mm/state",
      binaryMessenger: registrar.messenger())
    let statsChannel = FlutterEventChannel(
      name: "singbox_mm/stats",
      binaryMessenger: registrar.messenger())

    registrar.addMethodCallDelegate(instance, channel: methodChannel)
    stateChannel.setStreamHandler(instance)
    let statsHandler = StatsStreamHandler(plugin: instance)
    instance.statsStreamHandler = statsHandler
    statsChannel.setStreamHandler(statsHandler)
  }

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    stateSink = events
    emitState()
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    stateSink = nil
    return nil
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "initialize":
      initialize(arguments: call.arguments, result: result)
    case "requestVpnPermission":
      // iOS VPN permission flow must be handled by the host app's Network Extension setup.
      result(true)
    case "setConfig":
      setConfig(arguments: call.arguments, result: result)
    case "startVpn":
      startVpn(result: result)
    case "stopVpn":
      stopVpn(result: result)
    case "restartVpn":
      restartVpn(result: result)
    case "getState":
      result(connectionState)
    case "getStats":
      result(buildStats())
    case "getLastError":
      result(lastError)
    case "getSingboxVersion":
      result(nil)
    case "pingServer":
      pingServer(arguments: call.arguments, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func pingServer(arguments: Any?, result: @escaping FlutterResult) {
    guard let args = arguments as? [String: Any?],
      let host = args["host"] as? String,
      !host.isEmpty,
      let port = args["port"] as? Int,
      port > 0,
      port <= 65535
    else {
      result([
        "ok": false,
        "error": "Invalid host or port",
      ])
      return
    }

    let timeoutMs = max((args["timeoutMs"] as? Int) ?? 3000, 1)
    guard let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) else {
      result([
        "ok": false,
        "error": "Invalid port",
      ])
      return
    }

    let queue = DispatchQueue(label: "singbox_mm.ping")
    let connection = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: .tcp)
    let semaphore = DispatchSemaphore(value: 0)
    let startedAt = DispatchTime.now().uptimeNanoseconds
    var payload: [String: Any] = [
      "ok": false,
      "error": "Ping failed",
    ]

    connection.stateUpdateHandler = { state in
      switch state {
      case .ready:
        let latencyMs = Int((DispatchTime.now().uptimeNanoseconds - startedAt) / 1_000_000)
        payload = [
          "ok": true,
          "latencyMs": latencyMs,
        ]
        connection.cancel()
        semaphore.signal()
      case .failed(let error):
        payload = [
          "ok": false,
          "error": error.localizedDescription,
        ]
        semaphore.signal()
      case .cancelled:
        semaphore.signal()
      default:
        break
      }
    }

    connection.start(queue: queue)

    DispatchQueue.global(qos: .utility).async {
      let waitResult = semaphore.wait(timeout: .now() + .milliseconds(timeoutMs))
      if waitResult == .timedOut {
        connection.cancel()
        payload = [
          "ok": false,
          "error": "Ping timed out",
        ]
      }
      DispatchQueue.main.async {
        result(payload)
      }
    }
  }

  private func initialize(arguments: Any?, result: @escaping FlutterResult) {
    guard let args = arguments as? [String: Any?] else {
      result(
        FlutterError(
          code: "INIT_FAILED",
          message: "Invalid initialize arguments",
          details: nil))
      return
    }

    let workingDirectoryPath = args["workingDirectory"] as? String
    let logLevel = (args["logLevel"] as? String) ?? "info"
    let enableVerboseLogs = (args["enableVerboseLogs"] as? Bool) ?? false

    do {
      let workingDirectory: URL
      if let path = workingDirectoryPath, !path.isEmpty {
        workingDirectory = URL(fileURLWithPath: path, isDirectory: true)
      } else {
        let base = try FileManager.default.url(
          for: .applicationSupportDirectory,
          in: .userDomainMask,
          appropriateFor: nil,
          create: true)
        workingDirectory = base.appendingPathComponent("signbox", isDirectory: true)
      }

      try FileManager.default.createDirectory(
        at: workingDirectory,
        withIntermediateDirectories: true)

      let binaryPath = args["binaryPath"] as? String

      runtimeConfig = RuntimeConfig(
        workingDirectory: workingDirectory,
        binaryPath: binaryPath,
        logLevel: logLevel,
        enableVerboseLogs: enableVerboseLogs)
      configURL = workingDirectory.appendingPathComponent("active-config.json")

      result(nil)
    } catch {
      result(
        FlutterError(
          code: "INIT_FAILED",
          message: "Unable to initialize runtime: \(error.localizedDescription)",
          details: nil))
    }
  }

  private func setConfig(arguments: Any?, result: @escaping FlutterResult) {
    guard let args = arguments as? [String: Any?],
      let config = args["config"] as? String,
      !config.isEmpty
    else {
      result(
        FlutterError(
          code: "INVALID_CONFIG",
          message: "Missing config payload",
          details: nil))
      return
    }

    do {
      let runtime = try ensureRuntime()
      let fileURL = configURL ?? runtime.workingDirectory.appendingPathComponent("active-config.json")
      configURL = fileURL

      try config.write(to: fileURL, atomically: true, encoding: .utf8)
      result(nil)
    } catch {
      result(
        FlutterError(
          code: "CONFIG_WRITE_FAILED",
          message: "Unable to save config: \(error.localizedDescription)",
          details: nil))
    }
  }

  private func startVpn(result: @escaping FlutterResult) {
    do {
      let runtime = try ensureRuntime()
      let fileURL = configURL ?? runtime.workingDirectory.appendingPathComponent("active-config.json")

      guard FileManager.default.fileExists(atPath: fileURL.path) else {
        result(
          FlutterError(
            code: "START_FAILED",
            message: "Config file is missing. Call setConfig() first.",
            details: nil))
        return
      }

      connectionState = "error"
      lastError =
        "iOS requires a Packet Tunnel Network Extension bound to sing-box core. This plugin cannot launch VPN processes directly on iOS."
      emitState()
      emitStats()

      result(
        FlutterError(
          code: "IOS_EXTENSION_REQUIRED",
          message: lastError,
          details: nil))
    } catch {
      result(
        FlutterError(
          code: "START_FAILED",
          message: error.localizedDescription,
          details: nil))
    }
  }

  private func stopVpn(result: @escaping FlutterResult) {
    connectionState = "disconnected"
    lastError = nil
    connectedAtMillis = nil
    uplinkBytes = 0
    downlinkBytes = 0
    emitState()
    emitStats()
    result(nil)
  }

  private func restartVpn(result: @escaping FlutterResult) {
    stopVpn { _ in
      self.startVpn(result: result)
    }
  }

  private func ensureRuntime() throws -> RuntimeConfig {
    if let runtimeConfig {
      return runtimeConfig
    }

    let base = try FileManager.default.url(
      for: .applicationSupportDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true)
    let workingDirectory = base.appendingPathComponent("signbox", isDirectory: true)
    try FileManager.default.createDirectory(at: workingDirectory, withIntermediateDirectories: true)

    let fallback = RuntimeConfig(
      workingDirectory: workingDirectory,
      binaryPath: nil,
      logLevel: "info",
      enableVerboseLogs: false)

    runtimeConfig = fallback
    configURL = workingDirectory.appendingPathComponent("active-config.json")

    return fallback
  }

  private func emitState() {
    let payload: [String: Any?] = [
      "state": connectionState,
      "timestamp": Int64(Date().timeIntervalSince1970 * 1000),
      "lastError": lastError,
    ]
    stateSink?(payload)
  }

  private func emitStats() {
    statsSink?(buildStats())
  }

  private func startStatsTimer() {
    stopStatsTimer()
    guard statsSink != nil else {
      return
    }
    statsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
      self?.emitStats()
    }
  }

  private func stopStatsTimer() {
    statsTimer?.invalidate()
    statsTimer = nil
  }

  private func buildStats() -> [String: Any?] {
    [
      "uplinkBytes": uplinkBytes,
      "downlinkBytes": downlinkBytes,
      "activeConnections": connectionState == "connected" ? 1 : 0,
      "connectedAt": connectedAtMillis,
      "updatedAt": Int64(Date().timeIntervalSince1970 * 1000),
    ]
  }
}

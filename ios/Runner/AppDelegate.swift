import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var printerBridge: BrotherPrinterBridge?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: "com.racetimer/printer",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    printerBridge = BrotherPrinterBridge(channel: channel)
  }
}

final class BrotherPrinterBridge: NSObject {
  private let channel: FlutterMethodChannel

  init(channel: FlutterMethodChannel) {
    self.channel = channel
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call: call, result: result)
    }
  }

  private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let arguments = call.arguments as? [String: Any] else {
      result(statusMap(health: "error", message: "Invalid printer payload.", host: nil))
      return
    }

    let host = (arguments["host"] as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let connectionType = (arguments["connectionType"] as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines) ?? "bluetooth"

    switch call.method {
    case "configure":
      result(configurationStatus(for: host, connectionType: connectionType))
    case "getStatus":
      result(configurationStatus(for: host, connectionType: connectionType))
    case "testPrint":
      result(
        unsupportedStatus(
          host: host,
          message: unsupportedMessage(connectionType: connectionType)
        )
      )
    case "printLabel":
      result(
        unsupportedStatus(
          host: host,
          message: unsupportedMessage(connectionType: connectionType)
        )
      )
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func configurationStatus(for host: String?, connectionType: String) -> [String: Any] {
    guard let host, !host.isEmpty else {
      return statusMap(
        health: "notConfigured",
        message: missingConfigurationMessage(connectionType: connectionType),
        host: nil
      )
    }

    return unsupportedStatus(
      host: host,
      message: unsupportedMessage(connectionType: connectionType)
    )
  }

  private func unsupportedStatus(host: String?, message: String) -> [String: Any] {
    return statusMap(
      health: "unsupported",
      message: message,
      host: host
    )
  }

  private func missingConfigurationMessage(connectionType: String) -> String {
    if connectionType == "network" {
      return "Set the Brother printer IP address or hostname in Setup first."
    }
    return "Set the Brother printer Bluetooth name or MAC address in Setup first."
  }

  private func unsupportedMessage(connectionType: String) -> String {
    #if targetEnvironment(simulator)
    if connectionType == "network" {
      return "Brother QL network printing requires a physical iPad and the Brother iOS SDK integration."
    }
    return "Brother QL Bluetooth printing requires a physical iPad and the Brother iOS SDK integration."
    #else
    if connectionType == "network" {
      return "The Flutter method channel is ready. Add Brother's iOS SDK and replace this bridge stub to enable direct QL-820NWB network printing."
    }
    return "The Flutter method channel is ready. Add Brother's iOS SDK and replace this bridge stub to enable direct QL-820NWB Bluetooth printing."
    #endif
  }

  private func statusMap(health: String, message: String, host: String?) -> [String: Any] {
    var payload: [String: Any] = [
      "health": health,
      "message": message
    ]
    if let host {
      payload["host"] = host
    }
    return payload
  }
}

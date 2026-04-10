import BRLMPrinterKit
import CoreImage
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

private enum PrinterConnectionKind: String {
  case bluetooth
  case network

  init(storageValue: String?) {
    self = PrinterConnectionKind(rawValue: storageValue ?? "") ?? .bluetooth
  }

  var setupMessage: String {
    switch self {
    case .network:
      return "Set the Brother printer IP address or hostname in Setup first, or leave it blank and let the app search the current Wi-Fi network."
    case .bluetooth:
      return "Set the Brother printer Bluetooth name, serial number, or MAC address in Setup first."
    }
  }

  var transportName: String {
    switch self {
    case .network:
      return "Wi-Fi"
    case .bluetooth:
      return "Bluetooth"
    }
  }
}

private struct PrinterRequest {
  init(arguments: [String: Any]) {
    host = (arguments["host"] as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines)
    media = (arguments["media"] as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines)
    connectionType = PrinterConnectionKind(storageValue: arguments["connectionType"] as? String)
    runnerName = (arguments["runnerName"] as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines)
    barcodeValue = (arguments["barcodeValue"] as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines)
    raceName = (arguments["raceName"] as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  let host: String?
  let media: String?
  let connectionType: PrinterConnectionKind
  let runnerName: String?
  let barcodeValue: String?
  let raceName: String?
}

private struct ResolvedPrinter {
  let channel: BRLMChannel
  let host: String
  let connectionType: PrinterConnectionKind
  let modelName: String?
  let automaticallyDiscovered: Bool
}

final class BrotherPrinterBridge: NSObject {
  private let channel: FlutterMethodChannel
  private let ciContext = CIContext()
  private let supportedPrinterNames = ["QL-820NWB", "QL-820NWBc"]

  init(channel: FlutterMethodChannel) {
    self.channel = channel
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call: call, result: result)
    }
  }

  private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let arguments = call.arguments as? [String: Any] else {
      result(statusMap(health: "error", message: "The printer request could not be completed.", host: nil))
      return
    }

    let request = PrinterRequest(arguments: arguments)

    switch call.method {
    case "configure", "getStatus":
      checkStatus(for: request, result: result)
    case "testPrint":
      printTestLabel(for: request, result: result)
    case "printLabel":
      printRunnerLabel(for: request, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func checkStatus(for request: PrinterRequest, result: @escaping FlutterResult) {
    resolvePrinter(for: request) { resolved, error in
      guard let resolved else {
        result(self.statusMap(health: error?.health ?? "error", message: error?.message ?? "The printer is unavailable.", host: request.host))
        return
      }

      let generateResult = BRLMPrinterDriverGenerator.open(resolved.channel)
      guard generateResult.error.code == .noError, let driver = generateResult.driver else {
        result(
          self.statusMap(
            health: "error",
            message: self.openChannelMessage(for: resolved, error: generateResult.error.code),
            host: resolved.host
          )
        )
        return
      }

      defer {
        driver.closeChannel()
      }

      let statusResult = driver.getPrinterStatus()
      guard statusResult.error.code == .noError, let status = statusResult.status else {
        result(
          self.statusMap(
            health: "error",
            message: self.statusErrorMessage(for: resolved, error: statusResult.error.code),
            host: resolved.host
          )
        )
        return
      }

      let statusPayload = self.statusPayload(for: status, resolved: resolved)
      result(statusPayload)
    }
  }

  private func printTestLabel(for request: PrinterRequest, result: @escaping FlutterResult) {
    let testRequest: PrinterRequest = {
      var values: [String: Any] = [
        "host": request.host as Any,
        "media": request.media as Any,
        "connectionType": request.connectionType.rawValue,
        "runnerName": "Printer Test",
        "barcodeValue": "TEST-PRINT",
        "raceName": "RoxburyRaces"
      ]
      return PrinterRequest(arguments: values)
    }()

    printLabel(for: testRequest, successMessage: "Brother printer test label sent.", result: result)
  }

  private func printRunnerLabel(for request: PrinterRequest, result: @escaping FlutterResult) {
    printLabel(for: request, successMessage: "Brother label sent successfully.", result: result)
  }

  private func printLabel(
    for request: PrinterRequest,
    successMessage: String,
    result: @escaping FlutterResult
  ) {
    #if targetEnvironment(simulator)
      result(
        statusMap(
          health: "unsupported",
          message: "Printing is only available on a physical iPad. The iOS simulator cannot print labels.",
          host: request.host
        )
      )
      return
    #endif

    guard
      let runnerName = request.runnerName, !runnerName.isEmpty,
      let barcodeValue = request.barcodeValue, !barcodeValue.isEmpty
    else {
      result(
        statusMap(
          health: "error",
          message: "The label request is missing the runner name or barcode value.",
          host: request.host
        )
      )
      return
    }

    resolvePrinter(for: request) { resolved, error in
      guard let resolved else {
        result(self.statusMap(health: error?.health ?? "error", message: error?.message ?? "The printer is unavailable.", host: request.host))
        return
      }

      let generateResult = BRLMPrinterDriverGenerator.open(resolved.channel)
      guard generateResult.error.code == .noError, let driver = generateResult.driver else {
        result(
          self.statusMap(
            health: "error",
            message: self.openChannelMessage(for: resolved, error: generateResult.error.code),
            host: resolved.host
          )
        )
        return
      }

      defer {
        driver.closeChannel()
      }

      guard let printSettings = self.makePrintSettings(media: request.media) else {
        result(
          self.statusMap(
            health: "error",
            message: "The saved label size is not supported for the Brother QL-820NWB.",
            host: resolved.host
          )
        )
        return
      }

      guard let image = self.renderLabelImage(
        runnerName: runnerName,
        barcodeValue: barcodeValue,
        raceName: request.raceName
      )?.cgImage else {
        result(
          self.statusMap(
            health: "error",
            message: "The label image could not be prepared for printing.",
            host: resolved.host
          )
        )
        return
      }

      let printError = driver.printImage(with: image, settings: printSettings)
      guard printError.code == .noError else {
        result(
          self.statusMap(
            health: "error",
            message: self.printErrorMessage(for: resolved, error: printError.code),
            host: resolved.host
          )
        )
        return
      }

      result(
        self.statusMap(
          health: "success",
          message: "\(successMessage) \(resolved.connectionType.transportName) target: \(resolved.host).",
          host: resolved.host
        )
      )
    }
  }

  private func resolvePrinter(
    for request: PrinterRequest,
    completion: @escaping (ResolvedPrinter?, (health: String, message: String)?) -> Void
  ) {
    DispatchQueue.global(qos: .userInitiated).async {
      let target = self.resolvePrinterSynchronously(for: request)
      DispatchQueue.main.async {
        completion(target.printer, target.error)
      }
    }
  }

  private func resolvePrinterSynchronously(
    for request: PrinterRequest
  ) -> (printer: ResolvedPrinter?, error: (health: String, message: String)?) {
    switch request.connectionType {
    case .network:
      if let host = request.host, !host.isEmpty {
        return (
          ResolvedPrinter(
            channel: BRLMChannel(wifiIPAddress: host),
            host: host,
            connectionType: .network,
            modelName: "QL-820NWB",
            automaticallyDiscovered: false
          ),
          nil
        )
      }

      let option = BRLMNetworkSearchOption()
      option.printerList = supportedPrinterNames
      option.searchDuration = 5
      let searchResult = BRLMPrinterSearcher.startNetworkSearch(option) { _ in }
      let matchingChannels = searchResult.channels.filter(isSupportedBrotherChannel)
      if let first = matchingChannels.first, matchingChannels.count == 1 {
        return (
          resolvedPrinter(from: first, connectionType: .network, automaticallyDiscovered: true),
          nil
        )
      }
      if matchingChannels.count > 1 {
        return (nil, ("error", "Multiple Brother QL-820NWB printers were found on Wi-Fi. Save the printer IP address or hostname in Setup so the app connects to the correct device."))
      }
      return (nil, ("notConfigured", request.connectionType.setupMessage))

    case .bluetooth:
      guard let host = request.host, !host.isEmpty else {
        return (nil, ("notConfigured", request.connectionType.setupMessage))
      }

      let searchResult = BRLMPrinterSearcher.startBluetoothSearch()
      let matches = searchResult.channels.filter { channel in
        isSupportedBrotherChannel(channel) && matchesBluetoothTarget(query: host, channel: channel)
      }
      if let first = matches.first, matches.count == 1 {
        return (
          resolvedPrinter(from: first, connectionType: .bluetooth, automaticallyDiscovered: false),
          nil
        )
      }
      if matches.count > 1 {
        return (nil, ("error", "Multiple Brother Bluetooth printers matched that identifier. Save the exact serial number or MAC address for the printer you want to use."))
      }

      return (
        ResolvedPrinter(
          channel: BRLMChannel(bluetoothSerialNumber: host),
          host: host,
          connectionType: .bluetooth,
          modelName: "QL-820NWB",
          automaticallyDiscovered: false
        ),
        nil
      )
    }
  }

  private func resolvedPrinter(
    from channel: BRLMChannel,
    connectionType: PrinterConnectionKind,
    automaticallyDiscovered: Bool
  ) -> ResolvedPrinter {
    let extraInfo = channel.extraInfo
    let resolvedHost: String
    switch connectionType {
    case .network:
      resolvedHost = extraInfoValue(extraInfo, key: BRLMChannelExtraInfoKeyIpAddress) ?? channel.channelInfo
    case .bluetooth:
      resolvedHost =
        extraInfoValue(extraInfo, key: BRLMChannelExtraInfoKeyMacAddress) ??
        extraInfoValue(extraInfo, key: BRLMChannelExtraInfoKeyAdvertiseLocalName) ??
        extraInfoValue(extraInfo, key: BRLMChannelExtraInfoKeySerialNumber) ??
        channel.channelInfo
    }

    return ResolvedPrinter(
      channel: channel,
      host: resolvedHost,
      connectionType: connectionType,
      modelName: extraInfoValue(extraInfo, key: BRLMChannelExtraInfoKeyModelName),
      automaticallyDiscovered: automaticallyDiscovered
    )
  }

  private func isSupportedBrotherChannel(_ channel: BRLMChannel) -> Bool {
    let modelName = extraInfoValue(channel.extraInfo, key: BRLMChannelExtraInfoKeyModelName) ?? ""
    return supportedPrinterNames.contains(modelName)
  }

  private func matchesBluetoothTarget(query: String, channel: BRLMChannel) -> Bool {
    let normalizedQuery = normalizedIdentifier(query)
    let candidates = [
      channel.channelInfo,
      extraInfoValue(channel.extraInfo, key: BRLMChannelExtraInfoKeySerialNumber),
      extraInfoValue(channel.extraInfo, key: BRLMChannelExtraInfoKeyMacAddress),
      extraInfoValue(channel.extraInfo, key: BRLMChannelExtraInfoKeyAdvertiseLocalName)
    ]
    return candidates.compactMap { $0 }.contains { normalizedIdentifier($0) == normalizedQuery }
  }

  private func extraInfoValue(
    _ extraInfo: NSMutableDictionary?,
    key: String
  ) -> String? {
    extraInfo?[key] as? String
  }

  private func normalizedIdentifier(_ value: String) -> String {
    value
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .replacingOccurrences(of: ":", with: "")
      .replacingOccurrences(of: "-", with: "")
      .uppercased()
  }

  private func statusPayload(for status: BRLMPrinterStatus, resolved: ResolvedPrinter) -> [String: Any] {
    guard status.errorCode == .noError else {
      return statusMap(
        health: "error",
        message: "Brother printer reported \(printerStatusErrorDescription(status.errorCode)).",
        host: resolved.host
      )
    }

    let mediaDescription = describeMedia(status.mediaInfo)
    let discoveryPrefix = resolved.automaticallyDiscovered ? "Detected " : ""
    let modelName = resolved.modelName ?? "Brother printer"

    return statusMap(
      health: "ready",
      message: "\(discoveryPrefix)\(modelName) is ready over \(resolved.connectionType.transportName).\(mediaDescription.map { " Loaded media: \($0)." } ?? "")",
      host: resolved.host
    )
  }

  private func describeMedia(_ mediaInfo: BRLMMediaInfo?) -> String? {
    guard let mediaInfo else {
      return nil
    }

    if mediaInfo.width_mm == 62 && mediaInfo.isHeightInfinite {
      return "62mm continuous"
    }

    if mediaInfo.width_mm > 0 && mediaInfo.height_mm > 0 && !mediaInfo.isHeightInfinite {
      return "\(mediaInfo.width_mm)mm x \(mediaInfo.height_mm)mm"
    }

    if mediaInfo.width_mm > 0 {
      return "\(mediaInfo.width_mm)mm"
    }

    return nil
  }

  private func makePrintSettings(media: String?) -> BRLMQLPrintSettings? {
    guard let printSettings = BRLMQLPrintSettings(defaultPrintSettingsWith: .QL_820NWB) else {
      return nil
    }

    let mediaValue = (media ?? "").lowercased()
    switch mediaValue {
    case "", "62mm continuous", "62 continuous", "62mm roll", "62 roll":
      printSettings.labelSize = .rollW62
    case "62mm red/black", "62mm red black", "62mm rb":
      printSettings.labelSize = .rollW62RB
    case "62x29", "62mm x 29mm", "62mm die-cut 29":
      printSettings.labelSize = .dieCutW62H29
    case "62x60", "62mm x 60mm":
      printSettings.labelSize = .dieCutW62H60
    case "62x75", "62mm x 75mm":
      printSettings.labelSize = .dieCutW62H75
    case "62x100", "62mm x 100mm":
      printSettings.labelSize = .dieCutW62H100
    default:
      return nil
    }

    printSettings.autoCut = true
    printSettings.cutAtEnd = true
    return printSettings
  }

  private func renderLabelImage(
    runnerName: String,
    barcodeValue: String,
    raceName: String?
  ) -> UIImage? {
    let size = CGSize(width: 696, height: 300)
    let renderer = UIGraphicsImageRenderer(size: size)
    let barcodeImage = makeBarcodeImage(from: barcodeValue)
    let raceTitle = (raceName?.isEmpty == false ? raceName : "RoxburyRaces") ?? "RoxburyRaces"

    return renderer.image { context in
      UIColor.white.setFill()
      context.fill(CGRect(origin: .zero, size: size))

      let headerStyle = NSMutableParagraphStyle()
      headerStyle.alignment = .left

      let centeredStyle = NSMutableParagraphStyle()
      centeredStyle.alignment = .center

      let headerAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: 24, weight: .bold),
        .foregroundColor: UIColor.black,
        .paragraphStyle: headerStyle
      ]
      let nameAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: 30, weight: .semibold),
        .foregroundColor: UIColor.black,
        .paragraphStyle: centeredStyle
      ]
      let footerAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.monospacedSystemFont(ofSize: 24, weight: .medium),
        .foregroundColor: UIColor.black,
        .paragraphStyle: centeredStyle
      ]

      raceTitle.draw(in: CGRect(x: 20, y: 14, width: size.width - 40, height: 28), withAttributes: headerAttributes)
      runnerName.draw(in: CGRect(x: 24, y: 46, width: size.width - 48, height: 72), withAttributes: nameAttributes)

      if let barcodeImage {
        barcodeImage.draw(in: CGRect(x: 84, y: 120, width: size.width - 168, height: 110))
      }

      barcodeValue.draw(in: CGRect(x: 24, y: 240, width: size.width - 48, height: 34), withAttributes: footerAttributes)
    }
  }

  private func makeBarcodeImage(from value: String) -> UIImage? {
    guard
      let data = value.data(using: .ascii),
      let filter = CIFilter(name: "CICode128BarcodeGenerator")
    else {
      return nil
    }

    filter.setValue(data, forKey: "inputMessage")
    filter.setValue(7, forKey: "inputQuietSpace")

    guard let outputImage = filter.outputImage else {
      return nil
    }

    let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: 3, y: 3))
    guard let cgImage = ciContext.createCGImage(scaledImage, from: scaledImage.extent) else {
      return nil
    }
    return UIImage(cgImage: cgImage)
  }

  private func openChannelMessage(for resolved: ResolvedPrinter, error: BRLMOpenChannelErrorCode) -> String {
    switch error {
    case .timeout:
      return "The Brother printer did not respond over \(resolved.connectionType.transportName). Check that the printer is powered on and reachable from this iPad."
    case .openStreamFailure:
      return "The Brother printer connection could not be opened over \(resolved.connectionType.transportName)."
    case .noError:
      return "The Brother printer connection could not be opened."
    @unknown default:
      return "The Brother printer connection failed with an unknown error."
    }
  }

  private func statusErrorMessage(for resolved: ResolvedPrinter, error: BRLMGetStatusErrorCode) -> String {
    switch error {
    case .printerNotFound:
      return "The Brother printer could not be found over \(resolved.connectionType.transportName)."
    case .timeout:
      return "The Brother printer did not answer the status request in time."
    case .noError:
      return "The Brother printer status could not be read."
    @unknown default:
      return "The Brother printer status failed with an unknown error."
    }
  }

  private func printErrorMessage(for resolved: ResolvedPrinter, error: BRLMPrintErrorCode) -> String {
    switch error {
    case .printerStatusErrorPaperEmpty:
      return "The Brother printer is out of labels."
    case .printerStatusErrorCoverOpen:
      return "The Brother printer cover is open."
    case .printerStatusErrorBusy:
      return "The Brother printer is busy. Try again in a moment."
    case .printerStatusErrorPrinterTurnedOff:
      return "The Brother printer appears to be turned off."
    case .printerStatusErrorPaperJam:
      return "The Brother printer reported a label jam."
    case .printerStatusErrorCommunicationError, .channelErrorStreamStatusError, .channelTimeout:
      return "The iPad lost communication with the Brother printer while printing."
    case .noError:
      return "The Brother printer failed to print for an unknown reason."
    default:
      return "The Brother printer returned \(error.rawValue) while printing."
    }
  }

  private func printerStatusErrorDescription(_ error: BRLMPrinterStatusErrorCode) -> String {
    switch error {
    case .noPaper:
      return "no paper"
    case .coverOpen:
      return "cover open"
    case .busy:
      return "busy"
    case .paperJam:
      return "paper jam"
    case .batteryEmpty:
      return "battery empty"
    case .batteryTrouble:
      return "battery trouble"
    case .highVoltageAdapter:
      return "high voltage adapter error"
    case .motorSlow:
      return "motor slow error"
    case .systemError:
      return "system error"
    case .tubeNotDetected:
      return "tube not detected"
    case .unsupportedCharger:
      return "unsupported charger"
    case .incompatibleOptionalEquipment:
      return "incompatible optional equipment"
    case .anotherError:
      return "another printer error"
    case .noError:
      return "ready"
    @unknown default:
      return "an unknown printer error"
    }
  }

  private func statusMap(health: String, message: String, host: String?) -> [String: Any] {
    var payload: [String: Any] = [
      "health": health,
      "message": message
    ]
    if let host, !host.isEmpty {
      payload["host"] = host
    }
    return payload
  }
}

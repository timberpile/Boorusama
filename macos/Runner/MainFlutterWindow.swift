import Cocoa
import CryptoKit
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var appPrivacyChannel: AppPrivacyChannel?
  private var receivedExportChannel: ReceivedExportChannel?
  private var exportClipboardChannel: ExportClipboardChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController.init()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    appPrivacyChannel = AppPrivacyChannel(
      window: self,
      messenger: flutterViewController.engine.binaryMessenger
    )
    appPrivacyChannel?.register()
    receivedExportChannel = ReceivedExportChannel(
      messenger: flutterViewController.engine.binaryMessenger
    )
    receivedExportChannel?.register()
    exportClipboardChannel = ExportClipboardChannel(
      messenger: flutterViewController.engine.binaryMessenger
    )
    exportClipboardChannel?.register()
    (NSApplication.shared.delegate as? AppDelegate)?.installExportURLHandler {
      [weak self] url in self?.receivedExportChannel?.receive(url)
    }

    super.awakeFromNib()
  }
}

private final class ExportClipboardChannel {
  private static let channelName = "com.timberpile.boorusama/export_clipboard"
  private static let exportUTI = "com.timberpile.boorusama.export"
  private let channel: FlutterMethodChannel

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
  }

  func register() {
    channel.setMethodCallHandler { call, result in
      let arguments = call.arguments as? [String: Any]
      guard arguments?["uti"] as? String == Self.exportUTI else {
        result(FlutterError(code: "invalid_export", message: nil, details: nil))
        return
      }
      let pasteboard = NSPasteboard.general
      let exportType = NSPasteboard.PasteboardType(Self.exportUTI)
      switch call.method {
      case "writeExport":
        guard let text = arguments?["text"] as? String else {
          result(FlutterError(code: "invalid_export", message: nil, details: nil))
          return
        }
        pasteboard.clearContents()
        pasteboard.declareTypes([exportType, .string], owner: nil)
        pasteboard.setString(text, forType: exportType)
        pasteboard.setString(text, forType: .string)
        result(nil)
      case "containsExport":
        result(pasteboard.availableType(from: [exportType]) != nil)
      case "readExport":
        result(pasteboard.string(forType: exportType))
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

private final class ReceivedExportChannel: NSObject, FlutterStreamHandler {
  private static let eventChannelName = "com.timberpile.boorusama/received_exports"
  private static let methodChannelName = "com.timberpile.boorusama/received_exports_methods"
  private static let maxExportBytes: Int64 = 512 * 1024 * 1024

  private let eventChannel: FlutterEventChannel
  private let methodChannel: FlutterMethodChannel
  private let queue = DispatchQueue(label: "com.timberpile.boorusama.received-exports")
  private var eventSink: FlutterEventSink?
  private var pending: [[String: String]] = []

  init(messenger: FlutterBinaryMessenger) {
    eventChannel = FlutterEventChannel(
      name: Self.eventChannelName,
      binaryMessenger: messenger
    )
    methodChannel = FlutterMethodChannel(
      name: Self.methodChannelName,
      binaryMessenger: messenger
    )
  }

  func register() {
    eventChannel.setStreamHandler(self)
    methodChannel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "takePendingExports", let self else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(self.pending)
      self.pending.removeAll()
    }
  }

  func receive(_ url: URL) {
    queue.async { [weak self] in
      guard let self, let event = self.stage(url) else { return }
      DispatchQueue.main.async { self.publish(event) }
    }
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    pending.forEach { events($0) }
    pending.removeAll()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  private func stage(_ source: URL) -> [String: String]? {
    let accessed = source.startAccessingSecurityScopedResource()
    defer { if accessed { source.stopAccessingSecurityScopedResource() } }
    let manager = FileManager.default
    guard let cache = manager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
      return nil
    }
    let directory = cache.appendingPathComponent("received_exports", isDirectory: true)
    try? manager.createDirectory(at: directory, withIntermediateDirectories: true)
    let pendingURL = directory.appendingPathComponent(UUID().uuidString).appendingPathExtension("part")
    guard let input = InputStream(url: source),
          let output = OutputStream(url: pendingURL, append: false) else { return nil }
    input.open()
    output.open()
    defer {
      input.close()
      output.close()
      try? manager.removeItem(at: pendingURL)
    }

    var hasher = SHA256()
    var total: Int64 = 0
    var buffer = [UInt8](repeating: 0, count: 64 * 1024)
    while input.hasBytesAvailable {
      let count = input.read(&buffer, maxLength: buffer.count)
      if count < 0 { return nil }
      if count == 0 { break }
      total += Int64(count)
      if total > Self.maxExportBytes { return nil }
      hasher.update(data: Data(buffer[0..<count]))
      if output.write(buffer, maxLength: count) != count { return nil }
    }
    let id = hasher.finalize().map { String(format: "%02x", $0) }.joined()
    let completed = directory.appendingPathComponent(id).appendingPathExtension("bsexport")
    if !manager.fileExists(atPath: completed.path) {
      do { try manager.moveItem(at: pendingURL, to: completed) } catch { return nil }
    }
    return [
      "id": id,
      "path": completed.path,
      "displayName": source.lastPathComponent.isEmpty ? "received.bsexport" : source.lastPathComponent,
    ]
  }

  private func publish(_ event: [String: String]) {
    if let eventSink {
      eventSink(event)
    } else {
      pending.append(event)
    }
  }
}

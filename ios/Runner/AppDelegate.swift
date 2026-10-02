import UIKit
import Flutter
import CryptoKit
import flutter_local_notifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var appPrivacyChannel: AppPrivacyChannel?
  private var receivedExportChannel: ReceivedExportChannel?
  private var exportClipboardChannel: ExportClipboardChannel?
  private var pendingExportURLs: [URL] = []

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }
    if let url = launchOptions?[.url] as? URL, isExportFileURL(url) {
      pendingExportURLs.append(url)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
        GeneratedPluginRegistrant.register(with: registry)
    }

    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "AppPrivacyChannel"
    ) else { return }
    appPrivacyChannel = AppPrivacyChannel(messenger: registrar.messenger())
    appPrivacyChannel?.register()
    receivedExportChannel = ReceivedExportChannel(messenger: registrar.messenger())
    receivedExportChannel?.register()
    exportClipboardChannel = ExportClipboardChannel(messenger: registrar.messenger())
    exportClipboardChannel?.register()
    pendingExportURLs.forEach { receivedExportChannel?.receive($0) }
    pendingExportURLs.removeAll()
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    guard isExportFileURL(url) else {
      return super.application(app, open: url, options: options)
    }
    if let channel = receivedExportChannel {
      channel.receive(url)
    } else {
      pendingExportURLs.append(url)
    }
    return true
  }

  private func isExportFileURL(_ url: URL) -> Bool {
    url.isFileURL && url.pathExtension.lowercased() == "bsexport"
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
      switch call.method {
      case "writeExport":
        guard let text = arguments?["text"] as? String else {
          result(FlutterError(code: "invalid_export", message: nil, details: nil))
          return
        }
        UIPasteboard.general.setItems([[
          Self.exportUTI: text,
          "public.utf8-plain-text": text,
        ]])
        result(nil)
      case "containsExport":
        result(UIPasteboard.general.contains(pasteboardTypes: [Self.exportUTI]))
      case "readExport":
        result(UIPasteboard.general.value(forPasteboardType: Self.exportUTI) as? String)
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

import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private var pendingExportURLs: [URL] = []
  private var exportURLHandler: ((URL) -> Void)?

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func application(_ sender: NSApplication, openFiles filenames: [String]) {
    let urls = filenames.map(URL.init(fileURLWithPath:))
    if let exportURLHandler {
      urls.forEach(exportURLHandler)
    } else {
      pendingExportURLs.append(contentsOf: urls)
    }
    sender.reply(toOpenOrPrint: .success)
  }

  func installExportURLHandler(_ handler: @escaping (URL) -> Void) {
    exportURLHandler = handler
    pendingExportURLs.forEach(handler)
    pendingExportURLs.removeAll()
  }
}

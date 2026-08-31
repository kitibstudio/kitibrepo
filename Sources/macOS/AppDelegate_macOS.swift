import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    static var state: AppState?

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        AppDelegate.state?.saveCurrentFile()
        AppDelegate.state?.terminal.stop()
        return .terminateNow
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.state?.applyAppearance()
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: url) {
            NSApp.applicationIconImage = icon
        }
        NSApp.activate(ignoringOtherApps: true)
    }
}

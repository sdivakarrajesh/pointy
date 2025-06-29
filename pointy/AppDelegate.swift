import SwiftUI
import Cocoa
import os
import ScreenCaptureKit

let logger = Logger(subsystem: "com.theblueorb.Pointy", category: "main")

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "app.badge", accessibilityDescription: "Pointy")
            button.action = #selector(didClickStatusBarItem(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        Task {
            await checkPermissionsAndShowWindows()
        }
    }

    @MainActor @objc private func didClickStatusBarItem(_ sender: AnyObject?) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
            menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
        } else {
            Task {
                await checkPermissionsAndShowWindows()
            }
        }
    }

    @MainActor private func checkPermissionsAndShowWindows() async {
        if await hasScreenRecordingPermission() {
            logger.log("Screen recording permission is granted.")
            showAnnotationWindows()
        } else {
            logger.log("Screen recording permission is not granted. Requesting...")
            await requestScreenRecordingPermission()
            
            if await hasScreenRecordingPermission() {
                logger.log("Screen recording permission was granted after request.")
                showAnnotationWindows()
            } else {
                logger.log("Screen recording permission was not granted after request.")
                showPermissionsAlert()
            }
        }
    }

    private func hasScreenRecordingPermission() async -> Bool {
        do {
            _ = try await SCShareableContent.current
            return true
        } catch {
            return false
        }
    }
    
    private func requestScreenRecordingPermission() async {
        // Calling SCShareableContent.current will trigger the system prompt if the user
        // hasn't denied it already.
        do {
            _ = try await SCShareableContent.current
        } catch {
            // The error is expected if permission is not yet granted.
        }
    }

    @MainActor private func showAnnotationWindows() {
        NSApp.activate(ignoringOtherApps: true)
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) {
            AnnotationManager.shared.showWindows(on: screen)
        } else {
            AnnotationManager.shared.showWindows(on: NSScreen.main)
        }
    }

    @MainActor private func showPermissionsAlert() {
        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission Needed"
        let bundleId = Bundle.main.bundleIdentifier ?? "the app"
        alert.informativeText = "This app (\(bundleId)) needs screen recording permission to take screenshots. Please grant the permission in System Settings, then quit and restart the app."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Quit")
        
        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        } else {
            NSApp.terminate(nil)
        }
    }

    @MainActor @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

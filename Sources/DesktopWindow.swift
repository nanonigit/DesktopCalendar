import SwiftUI
import AppKit

class DesktopWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    
    private(set) var isFrontmostMode: Bool = false
    
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        
        sendToDesktopLayer()
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        self.isMovableByWindowBackground = true
        self.minSize = NSSize(width: 300, height: 250)
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidMoveOrResize),
            name: NSWindow.didMoveNotification,
            object: self
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidMoveOrResize),
            name: NSWindow.didResizeNotification,
            object: self
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleResetFrame),
            name: Notification.Name("ResetWindowFrame"),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSetFrontmost(_:)),
            name: Notification.Name("SetWindowFrontmost"),
            object: nil
        )
    }
    
    @objc private func handleSetFrontmost(_ notif: Notification) {
        if let isFront = notif.object as? Bool {
            if isFront {
                bringToFrontForInteraction()
            } else {
                sendToDesktopLayer()
            }
        }
    }
    
    @objc private func windowDidMoveOrResize() {
        let frame = self.frame
        let settings = AppSettings.shared
        settings.windowX = frame.origin.x
        settings.windowY = frame.origin.y
        settings.windowWidth = frame.size.width
        settings.windowHeight = frame.size.height
    }
    
    @objc private func handleResetFrame() {
        let settings = AppSettings.shared
        if let screen = NSScreen.main {
            let visibleFrame = screen.visibleFrame
            let newFrame = NSRect(
                x: visibleFrame.origin.x + 30,
                y: visibleFrame.origin.y + 50,
                width: 920,
                height: 540
            )
            self.setFrame(newFrame, display: true, animate: true)
            settings.windowX = newFrame.origin.x
            settings.windowY = newFrame.origin.y
            settings.windowWidth = newFrame.size.width
            settings.windowHeight = newFrame.size.height
        }
    }
    
    func bringToFrontForInteraction() {
        self.level = .floating
        self.isFrontmostMode = true
        AppSettings.shared.isFrontmostMode = true
        self.makeKeyAndOrderFront(nil)
    }
    
    func sendToDesktopLayer() {
        self.level = .init(Int(CGWindowLevelForKey(.desktopWindow)))
        self.isFrontmostMode = false
        AppSettings.shared.isFrontmostMode = false
    }
    
    func toggleInteractionLevel() {
        if isFrontmostMode {
            sendToDesktopLayer()
        } else {
            bringToFrontForInteraction()
        }
    }
}

import AppKit
import SwiftUI

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
    }
    
    func bringToFrontForInteraction() {
        self.level = .floating
        self.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        isFrontmostMode = true
    }
    
    func sendToDesktopLayer() {
        self.level = .init(Int(CGWindowLevelForKey(.desktopWindow)))
        isFrontmostMode = false
    }
    
    func toggleInteractionLevel() {
        if isFrontmostMode {
            sendToDesktopLayer()
        } else {
            bringToFrontForInteraction()
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
        let frame = NSRect(
            x: settings.windowX,
            y: settings.windowY,
            width: settings.windowWidth,
            height: settings.windowHeight
        )
        self.setFrame(frame, display: true, animate: true)
    }
}

import SwiftUI
import AppKit

@main
struct DesktopCalendarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject private var settings = AppSettings.shared
    
    var body: some Scene {
        Settings {
            SettingsView(settings: settings)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var desktopWindow: DesktopWindow?
    var statusItem: NSStatusItem?
    var settingsWindow: NSWindow?
    let menu = NSMenu()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        let settings = AppSettings.shared
        let calendarManager = CalendarManager.shared
        
        let initialRect = NSRect(
            x: settings.windowX,
            y: settings.windowY,
            width: max(settings.windowWidth, 600),
            height: max(settings.windowHeight, 400)
        )
        
        let window = DesktopWindow(contentRect: initialRect)
        window.contentView = NSHostingView(
            rootView: MainDesktopView(settings: settings, calendarManager: calendarManager)
        )
        window.makeKeyAndOrderFront(nil)
        self.desktopWindow = window
        
        setupMenuBarItem()
    }
    
    // Allows Raycast, Spotlight, or Dock/Finder to reopen management screen even if menu bar icon is hidden!
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openPreferences()
        return true
    }
    
    func setupMenuBarItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "calendar", accessibilityDescription: "DesktopCalendar")
        }
        
        menu.delegate = self
        item.menu = menu
        self.statusItem = item
    }
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let settings = AppSettings.shared
        
        // 1. Interaction Toggle
        let isFront = desktopWindow?.isFrontmostMode ?? false
        let toggleItem = NSMenuItem(
            title: isFront ? "カレンダーをデスクトップ背面に戻す" : "カレンダーを最前面にする（操作・移動）",
            action: #selector(toggleWindowLevel),
            keyEquivalent: "t"
        )
        toggleItem.target = self
        if isFront {
            toggleItem.state = .on
        }
        menu.addItem(toggleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 2. Timeline Days Submenu
        let daysMenu = NSMenu()
        for count in [1, 2, 3] {
            let item = NSMenuItem(title: "\(count)日分表示", action: #selector(setTimelineDays(_:)), keyEquivalent: "")
            item.tag = count
            item.target = self
            if settings.timelineDaysCount == count {
                item.state = .on
            }
            daysMenu.addItem(item)
        }
        let daysParentItem = NSMenuItem(title: "タイムライン表示日数", action: nil, keyEquivalent: "")
        daysParentItem.submenu = daysMenu
        menu.addItem(daysParentItem)
        
        // 3. Reminders Range Submenu
        let reminderMenu = NSMenu()
        for range in ReminderDateRange.allCases {
            let item = NSMenuItem(title: range.label, action: #selector(setReminderRange(_:)), keyEquivalent: "")
            item.representedObject = range
            item.target = self
            if settings.reminderDateRange == range {
                item.state = .on
            }
            reminderMenu.addItem(item)
        }
        let reminderParentItem = NSMenuItem(title: "リマインダー表示期限", action: nil, keyEquivalent: "")
        reminderParentItem.submenu = reminderMenu
        menu.addItem(reminderParentItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 4. Actions
        let refreshItem = NSMenuItem(
            title: "予定を更新",
            action: #selector(refreshEvents),
            keyEquivalent: "r"
        )
        refreshItem.target = self
        menu.addItem(refreshItem)
        
        let resetPosItem = NSMenuItem(
            title: "位置とサイズをリセット",
            action: #selector(resetPosition),
            keyEquivalent: ""
        )
        resetPosItem.target = self
        menu.addItem(resetPosItem)
        
        let prefItem = NSMenuItem(
            title: "環境設定...",
            action: #selector(openPreferences),
            keyEquivalent: ","
        )
        prefItem.target = self
        menu.addItem(prefItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 5. Quit
        let quitItem = NSMenuItem(
            title: "DesktopCalendar を終了",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
    }
    
    @objc func setTimelineDays(_ sender: NSMenuItem) {
        AppSettings.shared.timelineDaysCount = sender.tag
    }
    
    @objc func setReminderRange(_ sender: NSMenuItem) {
        if let range = sender.representedObject as? ReminderDateRange {
            AppSettings.shared.reminderDateRange = range
        }
    }
    
    @objc func toggleWindowLevel() {
        desktopWindow?.toggleInteractionLevel()
    }
    
    @objc func resetPosition() {
        NotificationCenter.default.post(name: Notification.Name("ResetWindowFrame"), object: nil)
    }
    
    @objc func refreshEvents() {
        CalendarManager.shared.fetchData()
        WeatherManager.shared.fetchWeather()
    }
    
    @objc func openPreferences() {
        if settingsWindow == nil {
            let settingsView = SettingsView(settings: AppSettings.shared)
            let hosting = NSHostingController(rootView: settingsView)
            let window = NSWindow(contentViewController: hosting)
            window.title = "DesktopCalendar 設定"
            window.styleMask = [.titled, .closable, .resizable]
            window.setContentSize(NSSize(width: 500, height: 640))
            window.minSize = NSSize(width: 480, height: 420)
            window.center()
            window.isReleasedWhenClosed = false
            self.settingsWindow = window
        }
        // Keep desktop calendar strictly in the background; only bring settingsWindow to front
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}

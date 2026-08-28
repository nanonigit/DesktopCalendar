import SwiftUI
import EventKit

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var calendarManager: CalendarManager = CalendarManager.shared
    @ObservedObject var weatherManager: WeatherManager = WeatherManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    // Group calendars by source account
    private var groupedCalendars: [(source: String, calendars: [EKCalendar])] {
        let dict = Dictionary(grouping: calendarManager.availableCalendars, by: { $0.source.title })
        return dict.keys.sorted().map { key in
            (source: key, calendars: dict[key] ?? [])
        }
    }
    
    // Group reminder lists by source account
    private var groupedReminderLists: [(source: String, lists: [EKCalendar])] {
        let dict = Dictionary(grouping: calendarManager.availableReminderLists, by: { $0.source.title })
        return dict.keys.sorted().map { key in
            (source: key, lists: dict[key] ?? [])
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Text("DesktopCalendar 設定")
                    .font(.title2.bold())
                Spacer()
                Button("閉じる") {
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(.bottom, 2)
            
            Divider()
            
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 18) {
                    
                    // Section 1: Location & Weather
                    VStack(alignment: .leading, spacing: 10) {
                        Text("📍 現在地とお天気")
                            .font(.headline)
                        
                        VStack(spacing: 8) {
                            HStack {
                                Text("認識中の現在地:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text(weatherManager.fullLocationLabel.isEmpty ? "検出中..." : "📍 " + weatherManager.fullLocationLabel)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.accentColor)
                            }
                            
                            HStack {
                                Spacer()
                                
                                Button(action: {
                                    weatherManager.fetchWeather()
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: weatherManager.isRefreshing ? "arrow.triangle.2.circlepath" : "location.circle")
                                            .rotationEffect(.degrees(weatherManager.isRefreshing ? 360 : 0))
                                            .animation(weatherManager.isRefreshing ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: weatherManager.isRefreshing)
                                        Text(weatherManager.isRefreshing ? "現在地を取得中..." : "現在地と天気を今すぐ更新")
                                            .font(.system(size: 12, weight: .medium))
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                                .disabled(weatherManager.isRefreshing)
                            }
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(8)
                        
                        Toggle("タイムラインに天気予報を表示する", isOn: $settings.showWeather)
                    }
                    
                    Divider()
                    
                    // Section 2: Panels Layout & Display
                    VStack(alignment: .leading, spacing: 10) {
                        Text("📊 パネルレイアウトと表示")
                            .font(.headline)
                        
                        // Frontmost / Desktop Layer Toggle
                        VStack(alignment: .leading, spacing: 4) {
                            Text("表示レイヤー（操作モード）")
                                .font(.subheadline.bold())
                                .foregroundColor(.secondary)
                            
                            Picker("表示レイヤー", selection: Binding(
                                get: { settings.isFrontmostMode ? 1 : 0 },
                                set: { val in
                                    NotificationCenter.default.post(name: Notification.Name("SetWindowFrontmost"), object: val == 1)
                                }
                            )) {
                                Text("デスクトップ背面（通常）").tag(0)
                                Text("最前面（移動・操作可能）").tag(1)
                            }
                            .pickerStyle(.segmented)
                            
                            Text(settings.isFrontmostMode ? "※ 最前面モード中: ウィンドウを掴んでドラッグ移動したり、直接操作できます。" : "※ 通常モード: 壁紙の背面に配置され、作業の邪魔になりません。")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary.opacity(0.85))
                                .padding(.top, 1)
                        }
                        .padding(.vertical, 2)
                        
                        Toggle("月間カレンダーを表示", isOn: $settings.showMonthCalendar)
                        Toggle("右側のタイムラインを表示", isOn: $settings.showAgenda)
                        Toggle("リマインダー / ToDo を表示", isOn: $settings.showReminders)
                        
                        Picker("タイムラインの表示日数", selection: $settings.timelineDaysCount) {
                            Text("1日分").tag(1)
                            Text("2日分").tag(2)
                            Text("3日分").tag(3)
                        }
                        .pickerStyle(.segmented)
                        .padding(.vertical, 2)
                        
                        HStack {
                            Text("左パネル（カレンダー・ToDo）の幅")
                            Spacer()
                            Slider(value: $settings.leftPanelWidth, in: 140...450, step: 5)
                                .frame(width: 160)
                            Text("\(Int(settings.leftPanelWidth))px")
                                .frame(width: 44, alignment: .trailing)
                        }
                    }
                    
                    Divider()
                    
                    // Section 3: Reminders Settings
                    VStack(alignment: .leading, spacing: 10) {
                        Text("✅ リマインダー / ToDo 設定")
                            .font(.headline)
                        
                        Picker("表示する期限範囲", selection: $settings.reminderDateRange) {
                            ForEach(ReminderDateRange.allCases) { range in
                                Text(range.label).tag(range)
                            }
                        }
                        
                        Toggle("完了したリマインダーも表示する", isOn: $settings.showCompletedReminders)
                    }
                    
                    Divider()
                    
                    // Section 4: Appearance & Format
                    VStack(alignment: .leading, spacing: 10) {
                        Text("🎨 外観と日時表記")
                            .font(.headline)
                        
                        HStack {
                            Text("背景の不透明度")
                            Spacer()
                            Slider(value: $settings.backgroundOpacity, in: 0.1...1.0)
                                .frame(width: 160)
                            Text("\(Int(settings.backgroundOpacity * 100))%")
                                .frame(width: 36, alignment: .trailing)
                        }
                        
                        Picker("週の開始日", selection: $settings.firstDayOfWeek) {
                            Text("日曜日").tag(1)
                            Text("月曜日").tag(2)
                        }
                        .pickerStyle(.segmented)
                        
                        Toggle("24時間表記を使用する", isOn: $settings.is24HourFormat)
                    }
                    
                    Divider()
                    
                    // Section 5: Calendar & Reminder Lists Filtering (Grouped by Account Source)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("🗓 表示するカレンダー・リストの選択")
                            .font(.headline)
                        
                        // Calendars
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("カレンダーアカウント")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Button("すべて選択") {
                                    settings.disabledCalendarIDs = []
                                    calendarManager.fetchData(for: settings.currentMonthDate)
                                }
                                .font(.caption)
                                .buttonStyle(.plain)
                                .foregroundColor(.accentColor)
                                
                                Text("|").font(.caption).foregroundColor(.secondary.opacity(0.5))
                                
                                Button("すべて解除") {
                                    settings.disabledCalendarIDs = Set(calendarManager.availableCalendars.map { $0.calendarIdentifier })
                                    calendarManager.fetchData(for: settings.currentMonthDate)
                                }
                                .font(.caption)
                                .buttonStyle(.plain)
                                .foregroundColor(.secondary)
                            }
                            
                            if calendarManager.availableCalendars.isEmpty {
                                Text("利用可能なカレンダーがありません（システム設定でカレンダーのアクセスを許可してください）")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                ForEach(groupedCalendars, id: \.source) { group in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(group.source)
                                            .font(.caption.bold())
                                            .foregroundColor(.secondary.opacity(0.8))
                                            .padding(.top, 2)
                                        
                                        ForEach(group.calendars, id: \.calendarIdentifier) { cal in
                                            let isEnabled = settings.isCalendarEnabled(cal.calendarIdentifier)
                                            HStack(spacing: 8) {
                                                Circle()
                                                    .fill(Color(nsColor: NSColor(cgColor: cal.cgColor) ?? .systemBlue))
                                                    .frame(width: 9, height: 9)
                                                
                                                Text(cal.title)
                                                    .font(.system(size: 12.5))
                                                
                                                Spacer()
                                                
                                                Toggle("", isOn: Binding(
                                                    get: { isEnabled },
                                                    set: { _ in
                                                        settings.toggleCalendar(cal.calendarIdentifier)
                                                        calendarManager.fetchData(for: settings.currentMonthDate)
                                                    }
                                                ))
                                                .toggleStyle(.checkbox)
                                            }
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.white.opacity(0.04))
                                            .cornerRadius(5)
                                        }
                                    }
                                }
                            }
                        }
                        
                        Divider().padding(.vertical, 2)
                        
                        // Reminders Lists
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("リマインダーリスト")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Button("すべて選択") {
                                    settings.disabledReminderListIDs = []
                                    calendarManager.fetchData(for: settings.currentMonthDate)
                                }
                                .font(.caption)
                                .buttonStyle(.plain)
                                .foregroundColor(.accentColor)
                                
                                Text("|").font(.caption).foregroundColor(.secondary.opacity(0.5))
                                
                                Button("すべて解除") {
                                    settings.disabledReminderListIDs = Set(calendarManager.availableReminderLists.map { $0.calendarIdentifier })
                                    calendarManager.fetchData(for: settings.currentMonthDate)
                                }
                                .font(.caption)
                                .buttonStyle(.plain)
                                .foregroundColor(.secondary)
                            }
                            
                            if calendarManager.availableReminderLists.isEmpty {
                                Text("利用可能なリマインダーリストがありません（システム設定でリマインダーのアクセスを許可してください）")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                ForEach(groupedReminderLists, id: \.source) { group in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(group.source)
                                            .font(.caption.bold())
                                            .foregroundColor(.secondary.opacity(0.8))
                                            .padding(.top, 2)
                                        
                                        ForEach(group.lists, id: \.calendarIdentifier) { list in
                                            let isEnabled = settings.isReminderListEnabled(list.calendarIdentifier)
                                            HStack(spacing: 8) {
                                                Circle()
                                                    .fill(Color(nsColor: NSColor(cgColor: list.cgColor) ?? .systemBlue))
                                                    .frame(width: 9, height: 9)
                                                
                                                Text(list.title)
                                                    .font(.system(size: 12.5))
                                                
                                                Spacer()
                                                
                                                Toggle("", isOn: Binding(
                                                    get: { isEnabled },
                                                    set: { _ in
                                                        settings.toggleReminderList(list.calendarIdentifier)
                                                        calendarManager.fetchData(for: settings.currentMonthDate)
                                                    }
                                                ))
                                                .toggleStyle(.checkbox)
                                            }
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.white.opacity(0.04))
                                            .cornerRadius(5)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Section 6: System
                    VStack(alignment: .leading, spacing: 10) {
                        Text("⚙️ システム設定")
                            .font(.headline)
                        
                        Toggle("メニューバーにアイコンを表示する", isOn: $settings.showMenuBarExtra)
                        
                        if !settings.showMenuBarExtra {
                            Text("※ メニューバーアイコンを非表示にしても、RaycastやSpotlightから「DesktopCalendar」を開くことでいつでもこの設定画面を表示できます。")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary.opacity(0.85))
                                .padding(.vertical, 2)
                        }
                        
                        Toggle("Mac起動時に自動で起動する（ログイン項目）", isOn: Binding(
                            get: { settings.launchAtLogin },
                            set: { val in settings.setLaunchAtLogin(val) }
                        ))
                        
                        HStack {
                            Button("位置とサイズをリセット") {
                                resetWindowPosition()
                            }
                            
                            Spacer()
                            
                            Button("アプリを終了") {
                                NSApplication.shared.terminate(nil)
                            }
                            .foregroundColor(.red)
                        }
                    }
                }
                .padding(.trailing, 6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(20)
        .frame(width: 520, height: 700)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
        .onAppear {
            calendarManager.fetchCalendarsList()
            calendarManager.fetchData(for: settings.currentMonthDate)
        }
    }
    
    private func resetWindowPosition() {
        settings.windowX = 30
        settings.windowY = 50
        settings.windowWidth = 920
        settings.windowHeight = 540
        settings.leftPanelWidth = 220
        NotificationCenter.default.post(name: Notification.Name("ResetWindowFrame"), object: nil)
    }
}

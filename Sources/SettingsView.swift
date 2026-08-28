import SwiftUI
import EventKit

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var calendarManager: CalendarManager = CalendarManager.shared
    @ObservedObject var weatherManager: WeatherManager = WeatherManager.shared
    @Environment(\.presentationMode) var presentationMode
    
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
                    // Section 1: Calendars Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("表示するカレンダーの選択")
                            .font(.headline)
                        
                        if calendarManager.availableCalendars.isEmpty {
                            Text("利用可能なカレンダーがありません")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            VStack(spacing: 5) {
                                ForEach(calendarManager.availableCalendars, id: \.calendarIdentifier) { cal in
                                    let isEnabled = settings.isCalendarEnabled(cal.calendarIdentifier)
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(Color(nsColor: NSColor(cgColor: cal.cgColor) ?? .systemBlue))
                                            .frame(width: 10, height: 10)
                                        
                                        Text(cal.title)
                                            .font(.system(size: 13))
                                        
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
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.white.opacity(0.06))
                                    .cornerRadius(6)
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Section 2: Reminder Lists Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("表示するリマインダーリストの選択")
                            .font(.headline)
                        
                        if calendarManager.availableReminderLists.isEmpty {
                            Text("利用可能なリマインダーリストがありません")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            VStack(spacing: 5) {
                                ForEach(calendarManager.availableReminderLists, id: \.calendarIdentifier) { list in
                                    let isEnabled = settings.isReminderListEnabled(list.calendarIdentifier)
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(Color(nsColor: NSColor(cgColor: list.cgColor) ?? .systemBlue))
                                            .frame(width: 10, height: 10)
                                        
                                        Text(list.title)
                                            .font(.system(size: 13))
                                        
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
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.white.opacity(0.06))
                                    .cornerRadius(6)
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Section 3: Timeline, Weather & Location Settings
                    VStack(alignment: .leading, spacing: 8) {
                        Text("タイムラインと天気・現在地設定")
                            .font(.headline)
                        
                        if !weatherManager.fullLocationLabel.isEmpty {
                            HStack {
                                Text("認識中の都市/タイムゾーン:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("📍 " + weatherManager.fullLocationLabel)
                                    .font(.subheadline.bold())
                                    .foregroundColor(.accentColor)
                            }
                            .padding(.vertical, 2)
                        }
                        
                        Picker("タイムラインの表示日数", selection: $settings.timelineDaysCount) {
                            Text("1日分").tag(1)
                            Text("2日分").tag(2)
                            Text("3日分").tag(3)
                        }
                        .pickerStyle(.segmented)
                        
                        Toggle("タイムラインに天気予報を表示する", isOn: $settings.showWeather)
                        
                        Picker("リマインダーの表示期限", selection: $settings.reminderDateRange) {
                            ForEach(ReminderDateRange.allCases) { range in
                                Text(range.label).tag(range)
                            }
                        }
                        
                        Toggle("完了したリマインダーも表示する", isOn: $settings.showCompletedReminders)
                    }
                    
                    Divider()
                    
                    // Section 4: Layout & Panel Sizes
                    VStack(alignment: .leading, spacing: 8) {
                        Text("パネルレイアウトとサイズ")
                            .font(.headline)
                        
                        HStack {
                            Text("左パネル（カレンダー・ToDo）の幅")
                            Spacer()
                            Slider(value: $settings.leftPanelWidth, in: 140...450, step: 5)
                                .frame(width: 160)
                            Text("\(Int(settings.leftPanelWidth))px")
                                .frame(width: 44, alignment: .trailing)
                        }
                        
                        Toggle("月間カレンダーを表示", isOn: $settings.showMonthCalendar)
                        Toggle("右側のタイムラインを表示", isOn: $settings.showAgenda)
                        Toggle("リマインダー / ToDo を表示", isOn: $settings.showReminders)
                    }
                    
                    Divider()
                    
                    // Section 5: Calendar Format & Appearance
                    VStack(alignment: .leading, spacing: 8) {
                        Text("外観と表記")
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
                    
                    // Section 6: System
                    VStack(alignment: .leading, spacing: 8) {
                        Text("システム設定")
                            .font(.headline)
                        
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
        .frame(width: 500, height: 640)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
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

import SwiftUI
import EventKit

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

struct MainDesktopView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var calendarManager: CalendarManager
    
    @State private var dragInitialWidth: Double? = nil
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Widget Style Dark Background
            Color.black.opacity(settings.backgroundOpacity)
                .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            
            if !calendarManager.isAuthorized {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 32))
                        .foregroundColor(.accentColor)
                    
                    Text("カレンダーとリマインダーの許可が必要です")
                        .font(.headline)
                    
                    Button("アクセスを許可") {
                        calendarManager.requestAccess()
                    }
                    .buttonStyle(.borderedProminent)
                    Spacer()
                }
                .padding()
            } else {
                HStack(alignment: .top, spacing: 0) {
                    // Left Panel: Adjustable width down to 140px
                    if settings.showMonthCalendar || settings.showReminders {
                        VStack(spacing: 14) {
                            if settings.showMonthCalendar {
                                MonthCalendarView(settings: settings, calendarManager: calendarManager)
                            }
                            
                            if settings.showReminders {
                                RemindersListView(settings: settings, calendarManager: calendarManager)
                            }
                        }
                        .frame(width: max(140, min(settings.leftPanelWidth, 600)))
                        .padding(.trailing, 8)
                    }
                    
                    // Drag Split Handle between Left & Right panels
                    if (settings.showMonthCalendar || settings.showReminders) && settings.showAgenda {
                        Rectangle()
                            .fill(Color.white.opacity(settings.isFrontmostMode ? 0.15 : 0.001))
                            .frame(width: 10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.white.opacity(settings.isFrontmostMode ? 0.35 : 0))
                                    .frame(width: 3, height: 32)
                            )
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        if dragInitialWidth == nil {
                                            dragInitialWidth = settings.leftPanelWidth
                                        }
                                        let base = dragInitialWidth ?? settings.leftPanelWidth
                                        let newWidth = max(140, min(base + Double(value.translation.width), 600))
                                        settings.leftPanelWidth = newWidth
                                    }
                                    .onEnded { _ in
                                        dragInitialWidth = nil
                                    }
                            )
                    }
                    
                    // Right Panel: 24h Timeline
                    if settings.showAgenda {
                        AgendaListView(settings: settings, calendarManager: calendarManager)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.leading, 4)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            
            // Resize indicator in Frontmost Mode
            if settings.isFrontmostMode {
                Image(systemName: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(8)
            }
        }
    }
}

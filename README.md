# DesktopCalendar for macOS 📅

[English](#english) | [日本語](#japanese)

---

<a name="japanese"></a>
## 🇯🇵 日本語

macOSのデスクトップ壁紙上に美しく溶け込む、ネイティブ製カレンダー＆ToDoウィジェットです。  
**Apple カレンダー / Google カレンダー**、**リマインダー / ToDo**、**24時間タイムライン**、**天気予報** をデスクトップ上でいつでも確認できます。


### ✨ 主な機能

- **🖼 壁紙一体型ウィジェット**: 通常のウィンドウの最背面に配置され、作業の邪魔をしません。
- **🎨 Mac標準ウィジェットの質感**: 角丸22pt・すりガラスブラックの完全ボーダーレスなデザイン。
- **🗓 月間カレンダー**:
  - 土曜日は青色、日曜日は赤色で分かりやすく色分け。
  - カレンダーごとの予定ドットを表示。
  - 日付をクリックすると右側のタイムラインが瞬時に連動。
  - **現在地＆タイムゾーン常時表示**（例: `📍 Aomori, Japan (GMT+9)`）：海外渡航や移動生活でも認識中の都市・時間を一目で確認可能。
- **⏳ 24時間タイムライン表示**:
  - 1日分・2日分・3日分の表示日数を自由に切り替え可能。
  - 予定を開始・終了時刻通りの正確な位置と長さでブロック配置。
  - 終日予定バー ＆ 現在時刻の赤ライン（Now Line）表示。
  - 各日ヘッダーに **天気アイコン ＋ 最高気温**（例: ☀️ 27°）を表示。
- **✅ リマインダー / ToDo 一覧**:
  - 期限範囲の絞り込み（今日のみ、今日と明日、3日間、1週間、2週間、すべて）。
  - 完了済みタスクの表示／非表示設定（指定期間内に完了したタスクのみに自動絞り込み）。
  - 左詰めタイポグラフィで狭い幅でもタイトルがすっきり読めるデザイン。
- **⚙️ 充実したカスタマイズ**:
  - 表示するカレンダー／リマインダーリストの個別チェック選択（iCloud, Google, 仕事用, 祝日など）。
  - 左パネル（カレンダー・ToDo）の幅調整（設定スライダーまたは画面上のドラッグ操作）。
  - 背景の不透明度調整（10%〜100%）。
  - Mac起動時の自動起動（ログイン項目）対応。
  - メニューバーアイコン（📅）からワンクリックで設定や操作モードの切り替えが可能。

### 🚀 インストール & ビルド方法

#### 必須要件
- macOS 14.0 以上（Sonoma / Sequoia 以降）
- Apple Silicon (M1/M2/M3/M4) または Intel Mac

#### ビルドと起動
```bash
git clone https://github.com/nanonigit/DesktopCalendar.git
cd DesktopCalendar
./build.sh
open -a /Applications/DesktopCalendar.app
```

---

<a name="english"></a>
## 🇬🇧 English

A native, ultra-clean macOS wallpaper widget that elegantly displays your **Apple / Google Calendar**, **Apple Reminders / ToDo**, **24-hour Multi-Day Timeline**, and **Live Weather Forecasts** directly on your desktop wallpaper.


### ✨ Key Features

- **🖼 Desktop Wallpaper Widget**: Runs smoothly behind normal windows without obstructing daily work.
- **🎨 Native Apple Widget Styling**: Borderless frosted glass with 22pt corner radius matching macOS widgets.
- **🗓 Month Calendar**:
  - Sundays highlighted in Red, Saturdays in Blue.
  - Event colored dots per day.
  - Interactive date selection synced with the timeline.
  - **Location & Timezone Indicator** (`📍 City, Country (GMT+X)`) — designed for digital nomads and frequent travelers.
- **⏳ 24-Hour Multi-Day Timeline**:
  - 1-day, 2-day, or 3-day multi-column view.
  - Accurate time-block positioning with calendar colors and time ranges.
  - All-day events banner on top.
  - Real-time Red "Now" line indicator on today's column.
  - Daily Weather Forecast badge (Icon + Max Temperature).
- **✅ Reminders & ToDo List**:
  - Filter by due date: Today only, Today & Tomorrow, 3 Days, 1 Week, 2 Weeks, All.
  - Option to show completed tasks (filtered within the active period).
  - Left-aligned compact typography for maximum readability.
- **⚙️ Deep Customization**:
  - Selective calendar & reminder list filters (check/uncheck iCloud, Google, Work, Holidays...).
  - Adjustable left/right split width (slider or interactive drag).
  - Background opacity & blur radius.
  - Launch at login support.
  - Menu bar status item with instant pulldown controls.

### 🚀 Installation & Build

#### Requirements
- macOS 14.0+ (Sonoma, Sequoia or later)
- Apple Silicon or Intel Mac

#### Build & Run
```bash
git clone https://github.com/nanonigit/DesktopCalendar.git
cd DesktopCalendar
./build.sh
open -a /Applications/DesktopCalendar.app
```

---

## 🔒 Permissions / 権限
On first launch, macOS will ask for permission to access:
- **Calendars / カレンダー**: To display your events on the month grid & timeline.
- **Reminders / リマインダー**: To display your ToDo items.

---

## 📄 License
MIT License.

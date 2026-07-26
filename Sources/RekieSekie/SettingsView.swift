import AppKit
import KeyboardShortcuts
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    var onMaxItemsChanged: (Int) -> Void
    var onMenuBarIconChanged: () -> Void
    var onClose: () -> Void

    @State private var maxItems: Int = Preferences.maxHistoryItems
    @State private var launchAtLogin: Bool = LaunchAtLogin.isEnabled
    @State private var excludedApps: [String] = Preferences.excludedBundleIDs
    @State private var excludeConcealedType: Bool = Preferences.excludeConcealedType
    @State private var menuBarIcon: MenuBarIcon = MenuBarIcon(rawValue: Preferences.menuBarIconName) ?? .clipboard
    @ObservedObject private var localization = LocalizationManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button(action: onClose) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 12, height: 12)
                }
                .buttonStyle(.plain)

                Text("設定", bundle: localization.bundle)
                    .font(.headline)

                Spacer()
            }
            .padding(16)

            TabView {
                generalTab
                    .tabItem { Text("一般", bundle: localization.bundle) }
                historyTab
                    .tabItem { Text("履歴", bundle: localization.bundle) }
                snippetTab
                    .tabItem { Text("スニペット", bundle: localization.bundle) }
                privacyTab
                    .tabItem { Text("プライバシー", bundle: localization.bundle) }
            }
            .padding([.horizontal, .bottom], 16)
        }
        .frame(width: 400)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private var generalTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            KeyboardShortcuts.Recorder(for: .togglePopover) {
                Text("ポップオーバーを開く:", bundle: localization.bundle)
            }

            Toggle(isOn: $launchAtLogin) {
                Text("ログイン時に起動", bundle: localization.bundle)
            }
            .onChange(of: launchAtLogin) { newValue in
                LaunchAtLogin.isEnabled = newValue
            }

            Picker(selection: languageSelection) {
                Text("システム設定に従う", bundle: localization.bundle).tag("system")
                Text("日本語").tag("ja")
                Text("English").tag("en")
            } label: {
                Text("言語:", bundle: localization.bundle)
            }
            .pickerStyle(.menu)
            .frame(width: 220)

            Picker(selection: $menuBarIcon) {
                ForEach(MenuBarIcon.allCases) { icon in
                    Label {
                        Text(icon.rawValue)
                    } icon: {
                        Image(systemName: icon.rawValue)
                    }
                    .tag(icon)
                }
            } label: {
                Text("メニューバーアイコン:", bundle: localization.bundle)
            }
            .pickerStyle(.menu)
            .frame(width: 220)
            .onChange(of: menuBarIcon) { newValue in
                Preferences.menuBarIconName = newValue.rawValue
                onMenuBarIconChanged()
            }
        }
        .padding(16)
    }

    private var snippetTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            KeyboardShortcuts.Recorder(for: .toggleSnippets) {
                Text("スニペット一覧を開く:", bundle: localization.bundle)
            }
        }
        .padding(16)
    }

    private var languageSelection: Binding<String> {
        Binding(
            get: { Preferences.appLanguage ?? "system" },
            set: { newValue in
                localization.setLanguage(newValue == "system" ? nil : newValue)
            }
        )
    }

    private static let minHistoryItems = 10
    private static let maxHistoryItemsLimit = 2000
    private static let defaultHistoryItems = 200

    private var historyTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("履歴の最大件数:", bundle: localization.bundle)
                TextField("", value: $maxItems, formatter: NumberFormatter())
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                Stepper(value: $maxItems, in: Self.minHistoryItems...Self.maxHistoryItemsLimit, step: 10) {
                    EmptyView()
                }
                .labelsHidden()
            }
            .onChange(of: maxItems) { newValue in
                let clamped = min(max(newValue, Self.minHistoryItems), Self.maxHistoryItemsLimit)
                if clamped != newValue {
                    maxItems = clamped
                } else {
                    Preferences.maxHistoryItems = newValue
                    onMaxItemsChanged(newValue)
                }
            }

            Text(
                "既定: \(Self.defaultHistoryItems) / 最小: \(Self.minHistoryItems) / 最大: \(Self.maxHistoryItemsLimit)",
                bundle: localization.bundle
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(16)
    }

    private var privacyTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle(isOn: $excludeConcealedType) {
                Text("パスワードマネージャー等のコピーを除外 (ConcealedType)", bundle: localization.bundle)
            }
            .onChange(of: excludeConcealedType) { newValue in
                Preferences.excludeConcealedType = newValue
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("除外アプリ（このアプリからのコピーは記録しない）", bundle: localization.bundle)
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(excludedApps, id: \.self) { bundleID in
                        HStack {
                            Text(bundleID)
                            Spacer()
                            Button(action: { removeExcludedApp(bundleID) }) {
                                Text("削除", bundle: localization.bundle)
                            }
                        }
                    }
                }

                Button(action: addExcludedApp) {
                    Text("アプリを追加...", bundle: localization.bundle)
                }
            }
        }
        .padding(16)
    }

    private func addExcludedApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")

        guard panel.runModal() == .OK,
              let url = panel.url,
              let bundleID = Bundle(url: url)?.bundleIdentifier,
              !excludedApps.contains(bundleID) else { return }

        excludedApps.append(bundleID)
        Preferences.excludedBundleIDs = excludedApps
    }

    private func removeExcludedApp(_ bundleID: String) {
        excludedApps.removeAll { $0 == bundleID }
        Preferences.excludedBundleIDs = excludedApps
    }
}

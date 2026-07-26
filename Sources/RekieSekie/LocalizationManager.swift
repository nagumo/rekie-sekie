import Foundation

/// 設定画面の言語選択（システム設定に従う/日本語固定/英語固定）を反映するBundleを提供する。
/// SwiftUI側は @ObservedObject で購読し、言語変更時に再描画させる。
final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    @Published private(set) var bundle: Bundle

    private init() {
        bundle = Self.resolveBundle(for: Preferences.appLanguage)
    }

    func setLanguage(_ language: String?) {
        Preferences.appLanguage = language
        bundle = Self.resolveBundle(for: language)
    }

    private static func resolveBundle(for language: String?) -> Bundle {
        guard let language,
              let path = Bundle.module.path(forResource: language, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return .module
        }
        return bundle
    }
}

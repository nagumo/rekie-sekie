import Foundation

/// 設定画面の言語選択（システム設定に従う/日本語固定/英語固定）を反映するBundleを提供する。
/// SwiftUI側は @ObservedObject で購読し、言語変更時に再描画させる。
final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    @Published private(set) var bundle: Bundle

    /// SwiftPMがexecutableターゲット向けに生成する`Bundle.module`は
    /// 「Bundle.main.bundleURL直下」と「ビルドマシンの絶対パス」しか探さないため、
    /// .app配布時（リソースはContents/Resources配下）はfatalErrorで起動不能になる。
    /// そのため先にContents/Resourcesを自前で探し、見つからない場合のみ
    /// `Bundle.module`（swift run・swift test時に有効）へフォールバックする。
    static let resourceBundle: Bundle = {
        if let url = Bundle.main.resourceURL?.appendingPathComponent("RekieSekie_RekieSekie.bundle"),
           let bundle = Bundle(url: url) {
            return bundle
        }
        return .module
    }()

    private init() {
        bundle = Self.resolveBundle(for: Preferences.appLanguage)
    }

    func setLanguage(_ language: String?) {
        Preferences.appLanguage = language
        bundle = Self.resolveBundle(for: language)
    }

    private static func resolveBundle(for language: String?) -> Bundle {
        guard let language,
              let path = resourceBundle.path(forResource: language, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return resourceBundle
        }
        return bundle
    }
}

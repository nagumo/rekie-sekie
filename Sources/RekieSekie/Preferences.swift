import Foundation

enum Preferences {
    /// テストからUserDefaults(suiteName:)に差し替えられるようにvarにしている。
    static var defaults: UserDefaults = .standard

    private enum Key {
        static let maxHistoryItems = "maxHistoryItems"
        static let excludedBundleIDs = "excludedBundleIDs"
        static let excludeConcealedType = "excludeConcealedType"
        static let appLanguage = "appLanguage"
        static let menuBarIconName = "menuBarIconName"
    }

    static var maxHistoryItems: Int {
        get {
            let value = defaults.integer(forKey: Key.maxHistoryItems)
            return value > 0 ? value : 200
        }
        set { defaults.set(newValue, forKey: Key.maxHistoryItems) }
    }

    static var excludedBundleIDs: [String] {
        get { defaults.stringArray(forKey: Key.excludedBundleIDs) ?? [] }
        set { defaults.set(newValue, forKey: Key.excludedBundleIDs) }
    }

    /// パスワードマネージャー等が付与する org.nspasteboard.ConcealedType を検知したコピーを履歴から除外する。既定でON。
    static var excludeConcealedType: Bool {
        get { defaults.object(forKey: Key.excludeConcealedType) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.excludeConcealedType) }
    }

    /// "ja" / "en" で明示的に言語を固定する。nilならシステムの言語設定に従う。
    static var appLanguage: String? {
        get { defaults.string(forKey: Key.appLanguage) }
        set { defaults.set(newValue, forKey: Key.appLanguage) }
    }

    /// メニューバーアイコンのSF Symbol名。
    static var menuBarIconName: String {
        get { defaults.string(forKey: Key.menuBarIconName) ?? "doc.on.clipboard" }
        set { defaults.set(newValue, forKey: Key.menuBarIconName) }
    }
}

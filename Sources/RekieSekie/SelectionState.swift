import Foundation

/// ポップオーバー1つぶんのUI状態（選択位置・検索クエリ）を保持する。
/// AppDelegate側のキー操作とSwiftUI側の表示を同じ状態で同期させるために使う。
final class SelectionState: ObservableObject {
    @Published var selectedIndex: Int = 0
    @Published var searchText: String = ""
    /// 検索欄にフォーカスがある間は、数字キーを検索文字として使えるようクイック選択を無効にする。
    @Published var isSearchFieldFocused: Bool = false
}

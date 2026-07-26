import Foundation

/// 設定で選べるメニューバーアイコンの候補（SF Symbol名）。
enum MenuBarIcon: String, CaseIterable, Identifiable {
    case clipboard = "doc.on.clipboard"
    case listClipboard = "list.clipboard"
    case docOnDoc = "doc.on.doc"
    case trayFull = "tray.full"
    case squareOnSquare = "square.on.square"

    var id: String { rawValue }
}

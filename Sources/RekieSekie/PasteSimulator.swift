import ApplicationServices
import CoreGraphics

enum PasteSimulator {
    /// アクセシビリティ権限があるかを、プロンプトを出さずに確認する。
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// 権限付与ダイアログ（システム設定を開く）を明示的に出す。
    /// 起動ごとに呼ぶと未付与ユーザーには毎回システム設定が開いてしまうため、
    /// 実際に貼り付けが必要になった時点で未付与のときだけ呼ぶ。
    @discardableResult
    static func promptForAccessibilityPermission() -> Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        return AXIsProcessTrustedWithOptions(options)
    }

    /// ⌘Vを送出する。未付与の場合は一度だけ権限付与を促し、今回の貼り付けは行わない。
    static func sendCommandV() {
        guard isTrusted else {
            promptForAccessibilityPermission()
            return
        }

        let source = CGEventSource(stateID: .hidSystemState)
        let keyVDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
        let keyVUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        keyVDown?.flags = .maskCommand
        keyVUp?.flags = .maskCommand
        keyVDown?.post(tap: .cghidEventTap)
        keyVUp?.post(tap: .cghidEventTap)
    }
}

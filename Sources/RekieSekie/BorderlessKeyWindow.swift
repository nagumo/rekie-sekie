import AppKit

/// .borderless の NSWindow は既定で isKeyWindow になれず、内部のテキストフィールド等が
/// キー入力を受け取れなくなる（KeyboardShortcuts.Recorder等）ため上書きする。
final class BorderlessKeyWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

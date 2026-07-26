import ApplicationServices
import CoreGraphics

enum PasteSimulator {
    @discardableResult
    static func ensureAccessibilityPermission() -> Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        return AXIsProcessTrustedWithOptions(options)
    }

    static func sendCommandV() {
        guard AXIsProcessTrusted() else { return }

        let source = CGEventSource(stateID: .hidSystemState)
        let keyVDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
        let keyVUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        keyVDown?.flags = .maskCommand
        keyVUp?.flags = .maskCommand
        keyVDown?.post(tap: .cghidEventTap)
        keyVUp?.post(tap: .cghidEventTap)
    }
}

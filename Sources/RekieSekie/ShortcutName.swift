import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let togglePopover = Self("togglePopover", default: .init(.v, modifiers: [.command, .shift]))
    static let toggleSnippets = Self("toggleSnippets", default: .init(.v, modifiers: [.command, .shift, .control]))
}

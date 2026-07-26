import AppKit
@testable import RekieSekie

final class MockPasteboard: PasteboardControlling {
    private(set) var changeCount = 0
    private(set) var content: String?
    private(set) var imageData: Data?
    var types: [NSPasteboard.PasteboardType]?

    func string(forType type: NSPasteboard.PasteboardType) -> String? {
        content
    }

    func data(forType type: NSPasteboard.PasteboardType) -> Data? {
        imageData
    }

    func clearContents() -> Int {
        content = nil
        imageData = nil
        types = nil
        changeCount += 1
        return changeCount
    }

    func setString(_ string: String, forType type: NSPasteboard.PasteboardType) -> Bool {
        content = string
        changeCount += 1
        return true
    }

    func setData(_ data: Data?, forType type: NSPasteboard.PasteboardType) -> Bool {
        imageData = data
        changeCount += 1
        return true
    }

    func simulateCopy(_ string: String, types: [NSPasteboard.PasteboardType] = [.string]) {
        content = string
        imageData = nil
        self.types = types
        changeCount += 1
    }

    func simulateImageCopy(_ data: Data, types: [NSPasteboard.PasteboardType] = [.tiff]) {
        content = nil
        imageData = data
        self.types = types
        changeCount += 1
    }
}

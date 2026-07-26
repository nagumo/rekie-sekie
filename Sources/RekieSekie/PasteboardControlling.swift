import AppKit

protocol PasteboardControlling: AnyObject {
    var changeCount: Int { get }
    var types: [NSPasteboard.PasteboardType]? { get }
    func string(forType type: NSPasteboard.PasteboardType) -> String?
    func data(forType type: NSPasteboard.PasteboardType) -> Data?
    @discardableResult func clearContents() -> Int
    @discardableResult func setString(_ string: String, forType type: NSPasteboard.PasteboardType) -> Bool
    @discardableResult func setData(_ data: Data?, forType type: NSPasteboard.PasteboardType) -> Bool
}

extension NSPasteboard: PasteboardControlling {}

import AppKit

final class ClipboardMonitor: ObservableObject {
    @Published private(set) var items: [ClipItem] = []

    private let storage: Storage
    private let pasteboard: PasteboardControlling
    private var timer: Timer?
    private var lastChangeCount: Int
    private let pollInterval: TimeInterval = 0.5
    private var maxItems: Int
    private let frontmostBundleIdentifier: () -> String?
    private let excludedBundleIdentifiers: () -> [String]
    private let isConcealedTypeExclusionEnabled: () -> Bool
    private static let concealedType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
    private static let imageType = NSPasteboard.PasteboardType.tiff

    init(
        storage: Storage,
        pasteboard: PasteboardControlling = NSPasteboard.general,
        maxItems: Int = Preferences.maxHistoryItems,
        frontmostBundleIdentifier: @escaping () -> String? = { NSWorkspace.shared.frontmostApplication?.bundleIdentifier },
        excludedBundleIdentifiers: @escaping () -> [String] = { Preferences.excludedBundleIDs },
        isConcealedTypeExclusionEnabled: @escaping () -> Bool = { Preferences.excludeConcealedType }
    ) {
        self.storage = storage
        self.pasteboard = pasteboard
        self.maxItems = maxItems
        self.frontmostBundleIdentifier = frontmostBundleIdentifier
        self.excludedBundleIdentifiers = excludedBundleIdentifiers
        self.isConcealedTypeExclusionEnabled = isConcealedTypeExclusionEnabled
        lastChangeCount = pasteboard.changeCount
        items = (try? storage.fetchRecent(limit: maxItems)) ?? []
    }

    /// 検索クエリで絞り込んだ履歴。画像項目はテキストを持たないため、クエリが空でない場合は除外する。
    func filteredItems(matching query: String) -> [ClipItem] {
        guard !query.isEmpty else { return items }
        return items.filter { !$0.isImage && $0.content.localizedCaseInsensitiveContains(query) }
    }

    /// 設定画面から履歴の最大件数を変更したときに呼ぶ。既に超過している分はその場で切り詰める。
    func updateMaxItems(_ newValue: Int) {
        maxItems = max(1, newValue)
        if items.count > maxItems {
            items.removeLast(items.count - maxItems)
        }
    }

    func start() {
        let newTimer = Timer(timeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.checkPasteboard()
        }
        // .default モードのみだとポップオーバー操作中などトラッキングループ中にタイマーが止まるため .common で登録する
        RunLoop.current.add(newTimer, forMode: .common)
        timer = newTimer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// クリップボードに書き戻し、選択した項目を履歴の先頭に移動して永続化する。
    func selectItem(_ item: ClipItem) {
        pasteboard.clearContents()
        if let imageData = item.imageData {
            pasteboard.setData(imageData, forType: Self.imageType)
        } else {
            pasteboard.setString(item.content, forType: .string)
        }
        lastChangeCount = pasteboard.changeCount

        promoteToFront(item)
    }

    func checkPasteboard() {
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        if let bundleID = frontmostBundleIdentifier(), excludedBundleIdentifiers().contains(bundleID) {
            return
        }

        if isConcealedTypeExclusionEnabled(), pasteboard.types?.contains(Self.concealedType) == true {
            return
        }

        if pasteboard.types?.contains(Self.imageType) == true,
           let data = pasteboard.data(forType: Self.imageType) {
            handleNewCapture(content: "", imageData: data)
            return
        }

        guard let string = pasteboard.string(forType: .string), !string.isEmpty else { return }
        handleNewCapture(content: string, imageData: nil)
    }

    private func handleNewCapture(content: String, imageData: Data?) {
        guard !matches(items.first, content: content, imageData: imageData) else { return }

        if let existing = items.first(where: { matches($0, content: content, imageData: imageData) }) {
            promoteToFront(existing)
            return
        }

        var item = ClipItem(content: content, imageData: imageData, createdAt: Date())
        do {
            try storage.insert(&item)
        } catch {
            print("履歴の保存に失敗しました: \(error)")
            return
        }

        items.insert(item, at: 0)
        if items.count > maxItems {
            items.removeLast(items.count - maxItems)
        }
    }

    private func matches(_ item: ClipItem?, content: String, imageData: Data?) -> Bool {
        guard let item else { return false }
        if let imageData {
            return item.imageData == imageData
        }
        return item.imageData == nil && item.content == content
    }

    /// 既存の行を更新して先頭に移すことで、新規INSERT+DELETEより書き込みコストを抑える。
    private func promoteToFront(_ item: ClipItem) {
        var updated = item
        updated.createdAt = Date()
        do {
            try storage.touch(&updated)
        } catch {
            print("履歴の更新に失敗しました: \(error)")
            updated = item
        }

        items.removeAll { $0.id == item.id }
        items.insert(updated, at: 0)
    }
}

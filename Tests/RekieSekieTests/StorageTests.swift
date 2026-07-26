import XCTest
@testable import RekieSekie

final class StorageTests: XCTestCase {
    func testInsertAssignsRowID() throws {
        let storage = try Storage(path: ":memory:")
        var item = ClipItem(content: "hello", createdAt: Date())

        try storage.insert(&item)

        XCTAssertNotNil(item.rowID)
    }

    func testFetchRecentReturnsNewestFirst() throws {
        let storage = try Storage(path: ":memory:")
        var older = ClipItem(content: "older", createdAt: Date(timeIntervalSince1970: 100))
        var newer = ClipItem(content: "newer", createdAt: Date(timeIntervalSince1970: 200))
        try storage.insert(&older)
        try storage.insert(&newer)

        let fetched = try storage.fetchRecent(limit: 10)

        XCTAssertEqual(fetched.map(\.content), ["newer", "older"])
    }

    func testFetchRecentRespectsLimit() throws {
        let storage = try Storage(path: ":memory:")
        for i in 0..<5 {
            var item = ClipItem(content: "item-\(i)", createdAt: Date(timeIntervalSince1970: TimeInterval(i)))
            try storage.insert(&item)
        }

        let fetched = try storage.fetchRecent(limit: 3)

        XCTAssertEqual(fetched.count, 3)
    }

    func testImageDataRoundTrips() throws {
        let storage = try Storage(path: ":memory:")
        let imageData = Data([0xFF, 0x00, 0xAB])
        var item = ClipItem(content: "", imageData: imageData, createdAt: Date())

        try storage.insert(&item)
        let fetched = try storage.fetchRecent(limit: 10)

        XCTAssertEqual(fetched.first?.imageData, imageData)
        XCTAssertEqual(fetched.first?.isImage, true)
    }

    func testStartupDeduplicationKeepsDistinctImages() throws {
        // :memory: はプロセス内でも接続ごとに独立したDBになるため、再オープンを検証するには実ファイルが必要
        let path = NSTemporaryDirectory() + UUID().uuidString + ".sqlite"
        defer { try? FileManager.default.removeItem(atPath: path) }

        let storageA = try Storage(path: path)
        var imageA = ClipItem(content: "", imageData: Data([0x01]), createdAt: Date(timeIntervalSince1970: 100))
        var imageB = ClipItem(content: "", imageData: Data([0x02]), createdAt: Date(timeIntervalSince1970: 200))
        try storageA.insert(&imageA)
        try storageA.insert(&imageB)

        let storageB = try Storage(path: path)
        let fetched = try storageB.fetchRecent(limit: 10)

        XCTAssertEqual(fetched.count, 2)
    }

    func testStartupDeduplicatesKeepingNewest() throws {
        // :memory: はプロセス内でも接続ごとに独立したDBになるため、再オープンを検証するには実ファイルが必要
        let path = NSTemporaryDirectory() + UUID().uuidString + ".sqlite"
        defer { try? FileManager.default.removeItem(atPath: path) }

        let storageA = try Storage(path: path)
        var old = ClipItem(content: "dup", createdAt: Date(timeIntervalSince1970: 100))
        var new = ClipItem(content: "dup", createdAt: Date(timeIntervalSince1970: 200))
        var other = ClipItem(content: "unique", createdAt: Date(timeIntervalSince1970: 150))
        try storageA.insert(&old)
        try storageA.insert(&new)
        try storageA.insert(&other)

        // 再起動を模して同じパスでStorageを開き直すと、init内のクリーンアップが走る
        let storageB = try Storage(path: path)
        let fetched = try storageB.fetchRecent(limit: 10)

        XCTAssertEqual(fetched.map(\.content), ["dup", "unique"])
        XCTAssertEqual(fetched.first?.rowID, new.rowID)
    }
}

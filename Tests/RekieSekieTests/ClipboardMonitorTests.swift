import XCTest
@testable import RekieSekie

final class ClipboardMonitorTests: XCTestCase {
    func testDetectsNewCopy() throws {
        let storage = try Storage(path: ":memory:")
        let pasteboard = MockPasteboard()
        let monitor = ClipboardMonitor(storage: storage, pasteboard: pasteboard)

        pasteboard.simulateCopy("hello")
        monitor.checkPasteboard()

        XCTAssertEqual(monitor.items.map(\.content), ["hello"])
    }

    func testFilteredItemsReturnsAllWhenQueryIsEmpty() throws {
        let storage = try Storage(path: ":memory:")
        let pasteboard = MockPasteboard()
        let monitor = ClipboardMonitor(storage: storage, pasteboard: pasteboard)

        pasteboard.simulateCopy("apple")
        monitor.checkPasteboard()
        pasteboard.simulateCopy("banana")
        monitor.checkPasteboard()

        XCTAssertEqual(monitor.filteredItems(matching: "").count, 2)
    }

    func testFilteredItemsMatchesCaseInsensitiveSubstring() throws {
        let storage = try Storage(path: ":memory:")
        let pasteboard = MockPasteboard()
        let monitor = ClipboardMonitor(storage: storage, pasteboard: pasteboard)

        pasteboard.simulateCopy("Hello World")
        monitor.checkPasteboard()
        pasteboard.simulateCopy("Goodbye")
        monitor.checkPasteboard()

        XCTAssertEqual(monitor.filteredItems(matching: "world").map(\.content), ["Hello World"])
    }

    func testFilteredItemsExcludesImagesWhenQueryIsNotEmpty() throws {
        let storage = try Storage(path: ":memory:")
        let pasteboard = MockPasteboard()
        let monitor = ClipboardMonitor(storage: storage, pasteboard: pasteboard)

        pasteboard.simulateCopy("apple pie")
        monitor.checkPasteboard()
        pasteboard.simulateImageCopy(Data([0x01]))
        monitor.checkPasteboard()

        let results = monitor.filteredItems(matching: "a")
        XCTAssertTrue(results.allSatisfy { !$0.isImage })
    }

    func testIgnoresConsecutiveDuplicate() throws {
        let storage = try Storage(path: ":memory:")
        let pasteboard = MockPasteboard()
        let monitor = ClipboardMonitor(storage: storage, pasteboard: pasteboard)

        pasteboard.simulateCopy("hello")
        monitor.checkPasteboard()
        pasteboard.simulateCopy("hello")
        monitor.checkPasteboard()

        XCTAssertEqual(monitor.items.count, 1)
    }

    func testIgnoresWhenChangeCountUnchanged() throws {
        let storage = try Storage(path: ":memory:")
        let pasteboard = MockPasteboard()
        let monitor = ClipboardMonitor(storage: storage, pasteboard: pasteboard)

        monitor.checkPasteboard()

        XCTAssertTrue(monitor.items.isEmpty)
    }

    func testTrimsToMaxItems() throws {
        let storage = try Storage(path: ":memory:")
        let pasteboard = MockPasteboard()
        let monitor = ClipboardMonitor(storage: storage, pasteboard: pasteboard, maxItems: 3)

        for i in 0..<5 {
            pasteboard.simulateCopy("item-\(i)")
            monitor.checkPasteboard()
        }

        XCTAssertEqual(monitor.items.count, 3)
        XCTAssertEqual(monitor.items.first?.content, "item-4")
    }

    func testExternalCopyOfExistingContentMovesToFrontWithoutDuplicating() throws {
        let storage = try Storage(path: ":memory:")
        let pasteboard = MockPasteboard()
        let monitor = ClipboardMonitor(storage: storage, pasteboard: pasteboard)

        pasteboard.simulateCopy("older")
        monitor.checkPasteboard()
        pasteboard.simulateCopy("newer")
        monitor.checkPasteboard()
        XCTAssertEqual(monitor.items.map(\.content), ["newer", "older"])

        pasteboard.simulateCopy("older")
        monitor.checkPasteboard()

        XCTAssertEqual(monitor.items.map(\.content), ["older", "newer"])
        XCTAssertEqual(try storage.fetchRecent(limit: 10).count, 2)
    }

    func testSelectItemWritesToPasteboard() throws {
        let storage = try Storage(path: ":memory:")
        let pasteboard = MockPasteboard()
        let monitor = ClipboardMonitor(storage: storage, pasteboard: pasteboard)

        pasteboard.simulateCopy("restore-me")
        monitor.checkPasteboard()
        let item = try XCTUnwrap(monitor.items.first)

        pasteboard.simulateCopy("something-else")
        monitor.selectItem(item)

        XCTAssertEqual(pasteboard.content, "restore-me")
    }

    func testSelectItemMovesToFront() throws {
        let storage = try Storage(path: ":memory:")
        let pasteboard = MockPasteboard()
        let monitor = ClipboardMonitor(storage: storage, pasteboard: pasteboard)

        pasteboard.simulateCopy("older")
        monitor.checkPasteboard()
        pasteboard.simulateCopy("newer")
        monitor.checkPasteboard()
        XCTAssertEqual(monitor.items.map(\.content), ["newer", "older"])

        let olderItem = try XCTUnwrap(monitor.items.last)
        monitor.selectItem(olderItem)

        XCTAssertEqual(monitor.items.map(\.content), ["older", "newer"])
    }

    func testSelectItemPersistsNewOrderAcrossReload() throws {
        let storage = try Storage(path: ":memory:")
        let pasteboard = MockPasteboard()
        let monitor = ClipboardMonitor(storage: storage, pasteboard: pasteboard)

        pasteboard.simulateCopy("older")
        monitor.checkPasteboard()
        pasteboard.simulateCopy("newer")
        monitor.checkPasteboard()

        let olderItem = try XCTUnwrap(monitor.items.last)
        monitor.selectItem(olderItem)

        let reloaded = ClipboardMonitor(storage: storage, pasteboard: pasteboard)
        XCTAssertEqual(reloaded.items.map(\.content), ["older", "newer"])
    }

    func testIgnoresCopyFromExcludedApp() throws {
        let storage = try Storage(path: ":memory:")
        let pasteboard = MockPasteboard()
        let monitor = ClipboardMonitor(
            storage: storage,
            pasteboard: pasteboard,
            frontmostBundleIdentifier: { "com.example.PasswordManager" },
            excludedBundleIdentifiers: { ["com.example.PasswordManager"] }
        )

        pasteboard.simulateCopy("secret")
        monitor.checkPasteboard()

        XCTAssertTrue(monitor.items.isEmpty)
        XCTAssertEqual(try storage.fetchRecent(limit: 10).count, 0)
    }

    func testDoesNotIgnoreCopyFromNonExcludedApp() throws {
        let storage = try Storage(path: ":memory:")
        let pasteboard = MockPasteboard()
        let monitor = ClipboardMonitor(
            storage: storage,
            pasteboard: pasteboard,
            frontmostBundleIdentifier: { "com.example.TextEditor" },
            excludedBundleIdentifiers: { ["com.example.PasswordManager"] }
        )

        pasteboard.simulateCopy("normal text")
        monitor.checkPasteboard()

        XCTAssertEqual(monitor.items.map(\.content), ["normal text"])
    }

    func testIgnoresConcealedTypeCopyWhenExclusionEnabled() throws {
        let storage = try Storage(path: ":memory:")
        let pasteboard = MockPasteboard()
        let monitor = ClipboardMonitor(
            storage: storage,
            pasteboard: pasteboard,
            isConcealedTypeExclusionEnabled: { true }
        )

        pasteboard.simulateCopy(
            "master-password",
            types: [.string, NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")]
        )
        monitor.checkPasteboard()

        XCTAssertTrue(monitor.items.isEmpty)
    }

    func testKeepsConcealedTypeCopyWhenExclusionDisabled() throws {
        let storage = try Storage(path: ":memory:")
        let pasteboard = MockPasteboard()
        let monitor = ClipboardMonitor(
            storage: storage,
            pasteboard: pasteboard,
            isConcealedTypeExclusionEnabled: { false }
        )

        pasteboard.simulateCopy(
            "master-password",
            types: [.string, NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")]
        )
        monitor.checkPasteboard()

        XCTAssertEqual(monitor.items.map(\.content), ["master-password"])
    }

    func testDetectsNewImageCopy() throws {
        let storage = try Storage(path: ":memory:")
        let pasteboard = MockPasteboard()
        let monitor = ClipboardMonitor(storage: storage, pasteboard: pasteboard)

        let imageData = Data([0x01, 0x02, 0x03])
        pasteboard.simulateImageCopy(imageData)
        monitor.checkPasteboard()

        XCTAssertEqual(monitor.items.count, 1)
        XCTAssertTrue(monitor.items[0].isImage)
        XCTAssertEqual(monitor.items[0].imageData, imageData)
    }

    func testDistinctImagesAreNotTreatedAsDuplicates() throws {
        let storage = try Storage(path: ":memory:")
        let pasteboard = MockPasteboard()
        let monitor = ClipboardMonitor(storage: storage, pasteboard: pasteboard)

        pasteboard.simulateImageCopy(Data([0x01]))
        monitor.checkPasteboard()
        pasteboard.simulateImageCopy(Data([0x02]))
        monitor.checkPasteboard()

        XCTAssertEqual(monitor.items.count, 2)
    }

    func testDuplicateImageMovesToFrontWithoutDuplicating() throws {
        let storage = try Storage(path: ":memory:")
        let pasteboard = MockPasteboard()
        let monitor = ClipboardMonitor(storage: storage, pasteboard: pasteboard)

        let imageA = Data([0x01])
        let imageB = Data([0x02])
        pasteboard.simulateImageCopy(imageA)
        monitor.checkPasteboard()
        pasteboard.simulateImageCopy(imageB)
        monitor.checkPasteboard()
        XCTAssertEqual(monitor.items.map(\.imageData), [imageB, imageA])

        pasteboard.simulateImageCopy(imageA)
        monitor.checkPasteboard()

        XCTAssertEqual(monitor.items.map(\.imageData), [imageA, imageB])
        XCTAssertEqual(try storage.fetchRecent(limit: 10).count, 2)
    }

    func testSelectItemWritesImageDataToPasteboard() throws {
        let storage = try Storage(path: ":memory:")
        let pasteboard = MockPasteboard()
        let monitor = ClipboardMonitor(storage: storage, pasteboard: pasteboard)

        let imageData = Data([0x01, 0x02])
        pasteboard.simulateImageCopy(imageData)
        monitor.checkPasteboard()
        let item = try XCTUnwrap(monitor.items.first)

        pasteboard.simulateCopy("something-else")
        monitor.selectItem(item)

        XCTAssertEqual(pasteboard.imageData, imageData)
    }

    func testUpdateMaxItemsTrimsExistingItems() throws {
        let storage = try Storage(path: ":memory:")
        let pasteboard = MockPasteboard()
        let monitor = ClipboardMonitor(storage: storage, pasteboard: pasteboard, maxItems: 10)

        for i in 0..<5 {
            pasteboard.simulateCopy("item-\(i)")
            monitor.checkPasteboard()
        }
        XCTAssertEqual(monitor.items.count, 5)

        monitor.updateMaxItems(2)

        XCTAssertEqual(monitor.items.count, 2)
        XCTAssertEqual(monitor.items.map(\.content), ["item-4", "item-3"])
    }
}

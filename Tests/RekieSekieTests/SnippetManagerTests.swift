import XCTest
@testable import RekieSekie

final class SnippetManagerTests: XCTestCase {
    func testAddSnippetAssignsRowIDAndReloads() throws {
        let storage = try Storage(path: ":memory:")
        let manager = SnippetManager(storage: storage)

        let snippet = manager.addSnippet(title: "Greeting", content: "Hello", folderID: nil)

        XCTAssertNotNil(snippet?.rowID)
        XCTAssertEqual(manager.snippets.map(\.title), ["Greeting"])
    }

    func testUpdateSnippetPersistsChanges() throws {
        let storage = try Storage(path: ":memory:")
        let manager = SnippetManager(storage: storage)
        var snippet = try XCTUnwrap(manager.addSnippet(title: "Old", content: "old", folderID: nil))

        snippet.title = "New"
        snippet.content = "new"
        manager.updateSnippet(snippet)

        XCTAssertEqual(manager.snippets.first?.title, "New")
        XCTAssertEqual(manager.snippets.first?.content, "new")
    }

    func testDeleteSnippetRemovesIt() throws {
        let storage = try Storage(path: ":memory:")
        let manager = SnippetManager(storage: storage)
        let snippet = try XCTUnwrap(manager.addSnippet(title: "Temp", content: "temp", folderID: nil))

        manager.deleteSnippet(snippet)

        XCTAssertTrue(manager.snippets.isEmpty)
    }

    func testFolderScopesSnippets() throws {
        let storage = try Storage(path: ":memory:")
        let manager = SnippetManager(storage: storage)
        let folder = try XCTUnwrap(manager.addFolder(name: "Work"))

        manager.addSnippet(title: "Root", content: "root", folderID: nil)
        manager.addSnippet(title: "InFolder", content: "in-folder", folderID: folder.id)

        XCTAssertEqual(manager.snippets(in: nil).map(\.title), ["Root"])
        XCTAssertEqual(manager.snippets(in: folder.id).map(\.title), ["InFolder"])
    }

    func testDeletingFolderOrphansItsSnippetsInsteadOfDeletingThem() throws {
        let storage = try Storage(path: ":memory:")
        let manager = SnippetManager(storage: storage)
        let folder = try XCTUnwrap(manager.addFolder(name: "Work"))
        manager.addSnippet(title: "InFolder", content: "in-folder", folderID: folder.id)

        manager.deleteFolder(folder)

        XCTAssertEqual(manager.snippets.count, 1)
        XCTAssertNil(manager.snippets.first?.folderID)
    }

    func testExpandedContentSubstitutesVariables() throws {
        let storage = try Storage(path: ":memory:")
        let manager = SnippetManager(storage: storage)
        let snippet = try XCTUnwrap(manager.addSnippet(title: "Stamp", content: "date={date}", folderID: nil))

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        XCTAssertEqual(manager.expandedContent(for: snippet), "date=\(dateFormatter.string(from: Date()))")
    }
}

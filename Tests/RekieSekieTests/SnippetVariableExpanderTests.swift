import XCTest
@testable import RekieSekie

final class SnippetVariableExpanderTests: XCTestCase {
    func testExpandsDate() {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let result = SnippetVariableExpander.expand("today={date}", now: now)

        XCTAssertEqual(result, "today=\(formatter.string(from: now))")
    }

    func testExpandsTime() {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"

        let result = SnippetVariableExpander.expand("now={time}", now: now)

        XCTAssertEqual(result, "now=\(formatter.string(from: now))")
    }

    func testExpandsDatetime() {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        let result = SnippetVariableExpander.expand("stamp={datetime}", now: now)

        XCTAssertEqual(result, "stamp=\(formatter.string(from: now))")
    }

    func testExpandsMultipleOccurrences() {
        let now = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let result = SnippetVariableExpander.expand("{date} to {date}", now: now)

        let expectedDate = dateFormatter.string(from: now)
        XCTAssertEqual(result, "\(expectedDate) to \(expectedDate)")
    }

    func testLeavesPlainTextUnchanged() {
        let result = SnippetVariableExpander.expand("plain text without variables")

        XCTAssertEqual(result, "plain text without variables")
    }
}

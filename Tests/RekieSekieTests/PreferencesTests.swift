import XCTest
@testable import RekieSekie

final class PreferencesTests: XCTestCase {
    override func setUp() {
        super.setUp()
        Preferences.defaults = UserDefaults(suiteName: "rekie-sekie-tests-\(UUID())")!
    }

    override func tearDown() {
        Preferences.defaults = .standard
        super.tearDown()
    }

    func testMaxHistoryItemsDefaultsTo200() {
        XCTAssertEqual(Preferences.maxHistoryItems, 200)
    }

    func testMaxHistoryItemsRoundTrips() {
        Preferences.maxHistoryItems = 50
        XCTAssertEqual(Preferences.maxHistoryItems, 50)
    }

    func testExcludedBundleIDsDefaultsToEmpty() {
        XCTAssertEqual(Preferences.excludedBundleIDs, [])
    }

    func testExcludedBundleIDsRoundTrips() {
        Preferences.excludedBundleIDs = ["com.example.A", "com.example.B"]
        XCTAssertEqual(Preferences.excludedBundleIDs, ["com.example.A", "com.example.B"])
    }
}

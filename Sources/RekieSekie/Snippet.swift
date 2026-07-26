import Foundation
import GRDB

struct Snippet: Codable, Equatable {
    var rowID: Int64?
    var title: String
    var content: String
    var folderID: Int64?
    var sortOrder: Int
}

extension Snippet: FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "snippet"

    enum CodingKeys: String, CodingKey {
        case rowID = "id"
        case title
        case content
        case folderID
        case sortOrder
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        rowID = inserted.rowID
    }
}

extension Snippet: Identifiable {
    var id: Int64 { rowID ?? -1 }
}

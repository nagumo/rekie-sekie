import Foundation
import GRDB

struct SnippetFolder: Codable, Equatable {
    var rowID: Int64?
    var name: String
    var sortOrder: Int
}

extension SnippetFolder: FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "snippetFolder"

    enum CodingKeys: String, CodingKey {
        case rowID = "id"
        case name
        case sortOrder
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        rowID = inserted.rowID
    }
}

extension SnippetFolder: Identifiable {
    var id: Int64 { rowID ?? -1 }
}

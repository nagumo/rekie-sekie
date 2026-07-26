import Foundation
import GRDB

struct ClipItem: Codable, Equatable {
    var rowID: Int64?
    var content: String
    var imageData: Data?
    var createdAt: Date

    var isImage: Bool { imageData != nil }
}

extension ClipItem: FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "clipItem"

    enum CodingKeys: String, CodingKey {
        case rowID = "id"
        case content
        case imageData
        case createdAt
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        rowID = inserted.rowID
    }
}

extension ClipItem: Identifiable {
    var id: Int64 { rowID ?? -1 }
}
